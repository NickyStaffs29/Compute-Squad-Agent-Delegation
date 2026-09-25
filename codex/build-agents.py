#!/usr/bin/env python3
"""Generate every file that names a model or restates an agent body.

models.conf is the only file that names models. From it and the canonical
Claude agent markdown in agents/, this script writes:
- the model: line of each agents/*.md frontmatter, and nothing else there;
- the Codex agent TOMLs in codex/agents/;
- codex/profiles.toml;
- the block between the routing markers in skills/compute-squad/SKILL.md,
  codex/SKILL.md, README.md, and codex/README.md;
- the manual Codex prompts codex/01-archive.md to codex/05-pm-accept.md.

--check compares every one of them with what this script would write and
exits 1 on any difference. --parse-manifest PATH parses a manifest, prints it
as JSON, and exits 1 on the first line the grammar does not allow.

--validate-catalog PATH [--strict] [--choices CHOICES] reads a Codex model
catalog (the JSON that `codex debug models` prints) and checks every model and
reasoning effort that codex/agents/*.toml and codex/profiles.toml pin against
it; with --choices it checks the pins the effective build would carry instead.
It exits 1 when a model is missing or retired or lacks the pinned effort, and
warns when a model is superseded or retires within 30 days (a failure with
--strict). A catalog it cannot read as that format is reported as not
validated, never as a pass, and exits 0 (1 with --strict).

The account's Codex model choices live outside the repository, in
$CODEX_HOME/compute-squad/choices.conf, which codex/update.sh passes as
CHOICES. models.conf stays the release default; a choice replaces each Codex
rung's model and effort, never which rung a role sits on.
--choose CATALOG CHOICES asks, on a terminal, which listed model and effort
fills each tier, shows the result, and saves it only on a literal `yes`.
--catalog-status CATALOG CHOICES prints current, changed, or unsaved.
--render-codex OUTDIR CHOICES writes the effective Codex build into a new
directory: a local marketplace holding the plugin payload, the agents, and the
profile files. None of the three writes the repository.
"""

from __future__ import annotations

import collections
import datetime
import difflib
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "agents"
OUTPUT = ROOT / "codex" / "agents"
MANIFEST = ROOT / "models.conf"
VERSION = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]

# The grammar models.conf and choices.conf share: blank lines, '#' comment
# lines, then each header line once, before the first section. A '[name]' line
# opens a section and names its columns; every row in it is a key plus exactly
# one field per column. Each grammar names its header lines (with the form of
# their value), its sections, and which sections have the rungs as their keys.
# Rungs are listed lowest first.
RUNGS = ("bottom", "mid", "top")
HEADER_FORMS = {
    "date": ("YYYY-MM-DD", r"[0-9]{4}-[0-9]{2}-[0-9]{2}"),
    "sha256": ("<64 lowercase hex digits>", r"[0-9a-f]{64}"),
    "effort": ("<effort>", r"[a-z][a-z0-9_-]*"),
}
MANIFEST_GRAMMAR = {
    "headers": {"reviewed": "date"},
    "sections": {"rung": ("claude", "codex"), "role": ("claude_rung", "codex_rung", "codex_effort")},
    "rung_keyed": ("rung",),
}
CHOICES_GRAMMAR = {
    "headers": {"chosen": "date", "catalog": "sha256", "main_effort": "effort"},
    "sections": {"tier": ("codex", "codex_effort")},
    "rung_keyed": ("tier",),
}
SECTION_COLUMNS = MANIFEST_GRAMMAR["sections"]
# Columns whose value must be a rung.
RUNG_COLUMNS = ("claude_rung", "codex_rung")
# Roles with no agent file: the main session and the audit fan-out.
EXTRA_ROLES = ("strategy", "finder", "skeptic")
# Agent text names rungs; a model name there would go stale on a re-point.
MODEL_NAME = re.compile(r"\b(Opus|Sonnet|Haiku|Fable)\b|gpt-[0-9]")

# Labels for the generated routing blocks, in the order the blocks list roles.
# They name roles and rungs, never models. Each row: role; its name in the
# shared skill's rung lines; its Role and Agent cells in codex/SKILL.md's
# table; its Role and Owns cells in README.md's table (no Role cell leaves it
# out of that table). None stands for the role's name in backticks.
ROLE_LABELS = (
    ("strategy", "main session", "Strategy and final judgment", "main session",
     "Strategy", "Goal, gaps, acceptance criteria, final judgment"),
    ("squad-pm", None, "Plan and acceptance", None, "PM", "The plan and the acceptance decision"),
    ("squad-recon", None, "Recon", None, "Recon", "Mapping the codebase"),
    ("squad-executor", None, "STANDARD execution", None, "Execution", "Implementing the plan"),
    ("squad-executor-mechanical", None, "MECHANICAL execution", None,
     "Execution on MECHANICAL", "The same executor protocol, {rung} rung"),
    ("squad-executor-complex", None, "COMPLEX execution", None,
     "Execution on COMPLEX", "The same executor protocol, {rung} rung"),
    ("squad-helper", None, "Delegated execution", None, "Delegated execution", "Tightly-specced subtasks"),
    ("squad-mech", None, "Intern work", None, "Intern", "Busywork. Nothing that requires judgment"),
    ("finder", "audit finders", "Audit finders", "none", None, None),
    ("skeptic", "audit skeptic", "Audit skeptic", "none", None, None),
)
Label = collections.namedtuple("Label", "role name table_role agent readme_role owns")
LABELS = tuple(
    Label(role, name or f"`{role}`", table_role, agent or f"`{role}`", readme_role, owns)
    for role, name, table_role, agent, readme_role, owns in ROLE_LABELS
)

# codex/profiles.toml: a fixed header, then one table per profile, each taking
# its model and effort from one models.conf role. It records the release
# defaults; codex/update.sh writes each Codex home's profiles from its choices.
PROFILE_HEADER = (
    "# Codex profile reference for Compute Squad.\n"
    "#\n"
    "# Codex CLI 0.134+ uses V2 profile files: copy the key/value pairs from one\n"
    "# table into ~/.codex/<profile-name>.config.toml, then launch with\n"
    "# `codex --profile <profile-name>`. Older CLI versions accepted the tables\n"
    "# appended to config.toml; do not append this whole file on current CLI.\n"
)
PROFILES = (
    ("compute-squad", "strategy"),
    ("compute-squad-pm", "squad-pm"),
    ("compute-squad-execution", "squad-executor"),
    ("compute-squad-mechanical", "squad-executor-mechanical"),
)

# The manual Codex prompts, one per stage: (file, stage number, stage name,
# source agent, part of its body, closing line). "plan" and "accept" are the
# squad-pm body up to its "## PLAN mode" heading plus that mode's section.
PROMPTS = (
    ("01-archive.md", 1, "Archive", "squad-mech", "body", "Run the primary procedure (log archival)."),
    ("02-recon.md", 2, "Recon", "squad-recon", "body", None),
    ("03-pm-plan.md", 3, "PM Plan", "squad-pm", "plan", "Your mode is PLAN."),
    ("04-execute.md", 4, "Execute", "squad-executor", "body", None),
    ("05-pm-accept.md", 5, "PM Accept", "squad-pm", "accept", "Your mode is ACCEPT."),
)
PROMPT_NOTE = (
    "You are running this stage by hand in a fresh Codex session. Wherever the instructions below say "
    "the orchestrating session or the main session, that means the human operator, who runs any "
    "`DELEGATE:` subtask, appends its results to the log, pastes the next stage's prompt, and re-pastes "
    "this prompt where the instructions say re-spawn."
)
PLAN_HEADING = "## PLAN mode"
ACCEPT_HEADING = "## ACCEPT mode"
# codex/README.md's table for the manual path: per prompt, its stage and the
# roles whose models the operator picks from, each with a label prefix.
MANUAL_STAGES = {
    "01-archive.md": ("Archive the prior log", (("", "squad-mech"),)),
    "02-recon.md": ("Codebase mapping and baseline check", (("", "squad-recon"),)),
    "03-pm-plan.md": ("Spec + task breakdown, no code", (("", "squad-pm"),)),
    "04-execute.md": (
        "Implementation, exactly per plan",
        (
            ("STANDARD ", "squad-executor"),
            ("MECHANICAL ", "squad-executor-mechanical"),
            ("COMPLEX ", "squad-executor-complex"),
        ),
    ),
    "05-pm-accept.md": ("Adversarial acceptance, PASS/FAIL", (("", "squad-pm"),)),
}

ROUTING_BEGIN = "<!-- routing:begin -->"
ROUTING_END = "<!-- routing:end -->"

# --validate-catalog: the pinned (model, effort) pairs come from the release's
# codex/agents/*.toml and codex/profiles.toml, or with --choices from the
# effective build. A key = "value" line before an agent TOML's
# developer_instructions, or inside a [profiles.<name>] table.
PINNED_KEY = re.compile(r'^(model|model_reasoning_effort)\s*=\s*"([^"\\]*)"\s*$')
RETIREMENT_WARNING_DAYS = 30
SUPERSEDED = (
    "{model} is superseded by {target}; see Changing models in CONTRIBUTING.md. "
    "Do not apply the upgrade target as is: it can put two rungs on one model."
)
SUPERSEDED_CHOICE = (
    "{model} is superseded by {target}; to choose again, run codex/update.sh --review-models. "
    "Do not apply the upgrade target as is: it can put two tiers on one model."
)


class BuildError(ValueError):
    pass


class FrontmatterError(BuildError):
    pass


class ManifestError(BuildError):
    pass


def parse_grammar(text: str, source: str, grammar: dict) -> tuple[dict, dict]:
    """Parse text in one grammar and return (headers, sections). Any line the
    grammar does not allow is an error, never a default."""
    headers: dict = {}
    sections: dict = {}
    columns_of = grammar["sections"]
    current = None
    for number, raw in enumerate(text.splitlines(), 1):
        where = f"{source}:{number}"
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if fields[0].startswith("["):
            name = fields[0][1:-1] if fields[0].endswith("]") else ""
            if name not in columns_of:
                known = ", ".join(f"[{section}]" for section in columns_of)
                raise ManifestError(f"{where}: unknown section {fields[0]!r}; the sections are {known}")
            if name in sections:
                raise ManifestError(f"{where}: section [{name}] appears twice")
            if tuple(fields[1:]) != columns_of[name]:
                raise ManifestError(
                    f"{where}: [{name}] must name the columns {' '.join(columns_of[name])}; "
                    f"found {' '.join(fields[1:]) or 'none'}"
                )
            current = name
            sections[name] = {}
            continue
        if current is None:
            key = fields[0]
            if key not in grammar["headers"]:
                raise ManifestError(f"{where}: {line!r} is outside a section")
            if key in headers:
                raise ManifestError(f"{where}: a second '{key}' line")
            shown, pattern = HEADER_FORMS[grammar["headers"][key]]
            if len(fields) != 2 or not re.fullmatch(pattern, fields[1]):
                raise ManifestError(f"{where}: expected '{key} {shown}'; found {line!r}")
            if grammar["headers"][key] == "date":
                try:
                    datetime.date.fromisoformat(fields[1])
                except ValueError:
                    raise ManifestError(f"{where}: {fields[1]!r} is not a calendar date") from None
            headers[key] = fields[1]
            continue
        columns = columns_of[current]
        if len(fields) != len(columns) + 1:
            raise ManifestError(
                f"{where}: a [{current}] row has {len(columns) + 1} fields ({current} {' '.join(columns)}); "
                f"found {len(fields)} in {line!r}"
            )
        key = fields[0]
        if key in sections[current]:
            raise ManifestError(f"{where}: [{current}] row {key!r} appears twice")
        row = dict(zip(columns, fields[1:]))
        if current in grammar["rung_keyed"] and key not in RUNGS:
            raise ManifestError(f"{where}: unknown rung {key!r}; the rungs are {', '.join(RUNGS)}")
        for column in RUNG_COLUMNS:
            if column in row and row[column] not in RUNGS:
                raise ManifestError(
                    f"{where}: {key} has unknown {column} {row[column]!r}; the rungs are {', '.join(RUNGS)}"
                )
        sections[current][key] = row
    for key, form in grammar["headers"].items():
        if key not in headers:
            raise ManifestError(f"{source}: no '{key} {HEADER_FORMS[form][0]}' line")
    for name in columns_of:
        if name not in sections:
            raise ManifestError(f"{source}: no [{name}] section")
        if not sections[name]:
            raise ManifestError(f"{source}: the [{name}] section has no rows")
    for name in grammar["rung_keyed"]:
        for rung in RUNGS:
            if rung not in sections[name]:
                raise ManifestError(f"{source}: [{name}] has no {rung!r} row")
    return headers, sections


def parse_manifest(text: str, source: str = "models.conf") -> dict:
    """Parse models.conf, the release routing."""
    headers, sections = parse_grammar(text, source, MANIFEST_GRAMMAR)
    return {
        "reviewed": headers["reviewed"],
        "rungs": {rung: sections["rung"][rung] for rung in RUNGS},
        "roles": sections["role"],
    }


def parse_choices(text: str, source: str) -> dict:
    """Parse choices.conf, one Codex home's model and effort per tier. Each
    tier needs its own model, so no two rungs collapse onto one."""
    headers, sections = parse_grammar(text, source, CHOICES_GRAMMAR)
    tiers = {rung: sections["tier"][rung] for rung in RUNGS}
    models = [tiers[rung]["codex"] for rung in RUNGS]
    if len(set(models)) != len(models):
        raise ManifestError(
            f"{source}: each tier needs its own model; bottom, mid, top are {', '.join(models)}"
        )
    return {**headers, "tiers": tiers}


def load_choices(path: str) -> dict:
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise ManifestError(f"cannot read the model choices {path}: {error}") from None
    return parse_choices(text, path)


def effective_manifest(release: dict, choices: dict) -> dict:
    """The release manifest with each Codex rung's model, and each role's Codex
    effort, taken from the choices: a role gets its Codex rung's tier effort,
    and the main session (strategy) gets main_effort. Rungs, roles, and every
    Claude column stay the release's."""
    rungs = {rung: dict(row) for rung, row in release["rungs"].items()}
    roles = {role: dict(row) for role, row in release["roles"].items()}
    for rung in RUNGS:
        rungs[rung]["codex"] = choices["tiers"][rung]["codex"]
    for role, row in roles.items():
        row["codex_effort"] = (
            choices["main_effort"] if role == "strategy" else choices["tiers"][row["codex_rung"]]["codex_effort"]
        )
    return {**release, "rungs": rungs, "roles": roles, "chosen": choices["chosen"]}


def load_manifest() -> dict:
    if not MANIFEST.is_file():
        raise ManifestError(f"{MANIFEST.name} is missing from the repo root")
    return parse_manifest(MANIFEST.read_text(encoding="utf-8"), MANIFEST.name)


def model_of(manifest: dict, role: str, host: str) -> str:
    return manifest["rungs"][manifest["roles"][role][f"{host}_rung"]][host]


def parse_frontmatter(path: pathlib.Path, text: str) -> tuple[str, str, str]:
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    if not match:
        raise FrontmatterError(f"{path}: missing YAML frontmatter")

    frontmatter, body = match.groups()
    name_match = re.search(r"^name:\s*(.+)$", frontmatter, re.MULTILINE)
    model_lines = re.findall(r"^model:", frontmatter, re.MULTILINE)
    if not name_match or len(model_lines) != 1:
        raise FrontmatterError(f"{path}: frontmatter needs a name line and exactly one model line")

    description_match = re.search(
        r"^description:\s*(.+?)(?=\n[a-z_]+:|\Z)",
        frontmatter,
        re.MULTILINE | re.DOTALL,
    )
    if not description_match:
        raise FrontmatterError(f"{path}: frontmatter needs description")

    name = name_match.group(1).strip()
    description = description_match.group(1).strip()
    description = re.sub(r"^[|>]\+?\-?\s*", "", description)
    description = " ".join(description.split())
    return name, description, body.strip()


def with_model_line(text: str, alias: str) -> str:
    """Return an agent file with its frontmatter's model: line set to alias.
    parse_frontmatter has already checked there is exactly one."""
    end = text.index("\n---\n", 3)
    head = text[:end].split("\n")
    at = next(i for i, line in enumerate(head) if line.startswith("model:"))
    head[at] = f"model: {alias}"
    return "\n".join(head) + text[end:]


def prompt_body(source: pathlib.Path, body: str, part: str) -> str:
    """Return the part of an agent body a manual prompt carries."""
    if part == "body":
        return body
    lines = body.split("\n")
    plan_at = [i for i, line in enumerate(lines) if line == PLAN_HEADING]
    accept_at = [i for i, line in enumerate(lines) if line == ACCEPT_HEADING]
    if len(plan_at) != 1 or len(accept_at) != 1 or plan_at[0] > accept_at[0]:
        raise FrontmatterError(
            f"{source}: needs one {PLAN_HEADING!r} line followed by one {ACCEPT_HEADING!r} line"
        )
    preamble = "\n".join(lines[:plan_at[0]]).strip()
    if part == "plan":
        section = "\n".join(lines[plan_at[0]:accept_at[0]]).strip()
    else:
        section = "\n".join(lines[accept_at[0]:]).strip()
    return preamble + "\n\n" + section


def check_roles(manifest: dict, agent_names: list) -> None:
    """The [role] rows must be exactly the agents plus EXTRA_ROLES, and each
    role needs a row in ROLE_LABELS."""
    roles = manifest["roles"]
    for role in list(agent_names) + list(EXTRA_ROLES):
        if role not in roles:
            raise ManifestError(f"models.conf: no [role] row for {role!r}")
    for role in roles:
        if role not in agent_names and role not in EXTRA_ROLES:
            raise ManifestError(
                f"models.conf: role {role!r} is neither an agent in agents/ nor one of {', '.join(EXTRA_ROLES)}"
            )
    labelled = [label.role for label in LABELS]
    for role in roles:
        if role not in labelled:
            raise BuildError(f"codex/build-agents.py: ROLE_LABELS has no row for role {role!r}")
    for role in labelled:
        if role not in roles:
            raise BuildError(f"codex/build-agents.py: ROLE_LABELS names {role!r}, which models.conf has no row for")


def render_profiles(manifest: dict) -> str:
    tables = []
    for profile, role in PROFILES:
        tables.append(
            f"[profiles.{profile}]\n"
            f"model = {toml_string(model_of(manifest, role, 'codex'))}\n"
            f"model_reasoning_effort = {toml_string(manifest['roles'][role]['codex_effort'])}\n"
        )
    return PROFILE_HEADER + "\n" + "\n".join(tables)


def render_skill_block(manifest: dict) -> str:
    """The shared skill's routing block, which both hosts load at run time."""
    roles, rungs = manifest["roles"], manifest["rungs"]
    top_down = RUNGS[::-1]
    if "chosen" in manifest:
        source = (
            f"Generated from `models.conf` (reviewed {manifest['reviewed']}), with the Codex IDs and efforts this "
            f"Codex home chose on {manifest['chosen']}; change them with `codex/update.sh --review-models`, never here."
        )
    else:
        source = f"Generated from `models.conf` (reviewed {manifest['reviewed']}); edit that file, never this block."
    lines = [
        source,
        "Rungs (Claude alias, Codex ID): "
        + "; ".join(f"{rung} `{rungs[rung]['claude']}`, `{rungs[rung]['codex']}`" for rung in top_down)
        + ".",
    ]
    for rung in top_down:
        on = {host: [label for label in LABELS if roles[label.role][f"{host}_rung"] == rung] for host in ("claude", "codex")}
        parts = []
        both = [label.name for label in on["claude"] if label in on["codex"]]
        codex_only = [label.name for label in on["codex"] if label not in on["claude"]]
        claude_only = [label.name for label in on["claude"] if label not in on["codex"]]
        if both:
            parts.append(", ".join(both))
        if codex_only:
            parts.append("in Codex also " + ", ".join(codex_only))
        if claude_only:
            parts.append("in Claude Code also " + ", ".join(claude_only))
        lines.append(f"- {rung.capitalize()}: {'; '.join(parts) or 'none'}.")

    main_effort = roles["strategy"]["codex_effort"]
    by_effort: dict = {}
    for label in LABELS:
        if label.role != "strategy":
            by_effort.setdefault(roles[label.role]["codex_effort"], []).append(label.name)
    if len(by_effort) == 1:
        efforts = f"Codex effort: `{main_effort}` for the main session, `{next(iter(by_effort))}` for every other role."
    else:
        efforts = f"Codex effort: `{main_effort}` for the main session; " + "; ".join(
            f"`{effort}` for {', '.join(names)}" for effort, names in by_effort.items()
        ) + "."
    lines.append(
        efforts
        + " Agent files already pin their models. To spawn on a rung (escalation, finders, skeptic), pass the"
        " rung's alias as the Agent tool's `model` in Claude Code; in Codex a named agent keeps its pinned model,"
        " so pass the rung's ID and effort only for finders and the skeptic."
    )
    return "\n".join(lines)


def render_codex_skill_table(manifest: dict) -> str:
    """codex/SKILL.md's table: every role, top rung first, with its Codex model."""
    roles, rungs = manifest["roles"], manifest["rungs"]
    lines = [
        f"Generated from `models.conf` (reviewed {manifest['reviewed']}); edit that file, never this table.",
        "",
        "| Role | Agent | Rung | Codex model | Effort |",
        "|---|---|---|---|---|",
    ]
    for rung in RUNGS[::-1]:
        for label in LABELS:
            row = roles[label.role]
            if row["codex_rung"] == rung:
                lines.append(
                    f"| {label.table_role} | {label.agent} | {rung} | `{rungs[rung]['codex']}` | `{row['codex_effort']}` |"
                )
    return "\n".join(lines)


def render_readme_table(manifest: dict) -> str:
    """README.md's table: each role that has an agent or is the main session."""
    roles, rungs = manifest["roles"], manifest["rungs"]
    lines = [
        f"Snapshot of `models.conf`, reviewed {manifest['reviewed']}. "
        "Routing reads `models.conf`; this table is generated from it.",
        "",
        "| Role | Agent | Claude Code | Codex | Owns |",
        "|---|---|---|---|---|",
    ]
    for label in LABELS:
        if label.readme_role is None:
            continue
        row = roles[label.role]
        claude_rung = row["claude_rung"]
        if label.role == "strategy":
            claude = f"your session model; {claude_rung} recommended"
        else:
            claude = f"`{rungs[claude_rung]['claude']}` ({claude_rung})"
        codex = f"`{rungs[row['codex_rung']]['codex']}` {row['codex_effort']}"
        owns = label.owns.format(rung=claude_rung)
        lines.append(f"| {label.readme_role} | {label.agent} | {claude} | {codex} | {owns} |")
    return "\n".join(lines)


def render_manual_table(manifest: dict) -> str:
    """codex/README.md's table: the model to run each manual prompt on."""
    roles, rungs = manifest["roles"], manifest["rungs"]
    lines = [
        "| Order | Prompt file | Stage | Model (rung) |",
        "|---|---|---|---|",
    ]
    for filename, number, *_ in PROMPTS:
        if filename not in MANUAL_STAGES:
            raise BuildError(f"codex/build-agents.py: MANUAL_STAGES has no row for {filename}")
        stage, choices = MANUAL_STAGES[filename]
        cells = []
        for prefix, role in choices:
            rung = roles[role]["codex_rung"]
            cells.append(f"{prefix}`{rungs[rung]['codex']}` {roles[role]['codex_effort']} ({rung})")
        lines.append(f"| {number} | `{filename}` | {stage} | {'; '.join(cells)} |")
    return "\n".join(lines)


ROUTING_BLOCKS = (
    ("skills/compute-squad/SKILL.md", render_skill_block),
    ("codex/SKILL.md", render_codex_skill_table),
    ("README.md", render_readme_table),
    ("codex/README.md", render_manual_table),
)


def with_routing_block(relpath: str, text: str, block: str) -> str:
    """Return text with the lines between its routing markers replaced."""
    lines = text.split("\n")
    begins = [i for i, line in enumerate(lines) if line == ROUTING_BEGIN]
    ends = [i for i, line in enumerate(lines) if line == ROUTING_END]
    if (
        text.count(ROUTING_BEGIN) != 1
        or text.count(ROUTING_END) != 1
        or len(begins) != 1
        or len(ends) != 1
        or ends[0] < begins[0]
    ):
        raise BuildError(
            f"{relpath}: needs one {ROUTING_BEGIN!r} line and, after it, one {ROUTING_END!r} line, "
            "each alone on its line"
        )
    return "\n".join(lines[:begins[0] + 1] + block.split("\n") + lines[ends[0]:])


def build(manifest: dict | None = None) -> dict[str, tuple[str, str]]:
    """Return {path relative to the repo root: (content, label)} for every
    generated file, from models.conf or from the manifest given."""
    if manifest is None:
        manifest = load_manifest()
    generated: dict[str, tuple[str, str]] = {}
    bodies: dict[str, tuple[str, str]] = {}
    for source in sorted(SOURCE.glob("*.md")):
        text = source.read_text(encoding="utf-8")
        name, description, body = parse_frontmatter(source, text)
        if name not in manifest["roles"]:
            raise ManifestError(f"models.conf: no [role] row for {name!r}, which agents/{source.name} defines")
        bodies[name] = (source.name, body)
        for part, what in ((description, "description"), (body, "body")):
            found = MODEL_NAME.search(part)
            if found:
                raise FrontmatterError(
                    f"{source}: the {what} names a model ({found.group(0)!r}); agent text names rungs "
                    "(top, mid, bottom), and models.conf names the models"
                )
        if '"""' in body:
            raise FrontmatterError(f"{source}: body contains a TOML triple-quote delimiter")
        if "\\" in body:
            raise FrontmatterError(f"{source}: body contains a backslash, which a TOML basic string reads as an escape")
        alias = model_of(manifest, name, "claude")
        generated[f"agents/{source.name}"] = (with_model_line(text, alias), f"model: {alias}")
        model = model_of(manifest, name, "codex")
        effort = manifest["roles"][name]["codex_effort"]
        generated[f"codex/agents/{name}.toml"] = (
            "\n".join(
                (
                    f"# compute-squad {VERSION}: generated by codex/build-agents.py from agents/{source.name}. Edit the source, not this file.",
                    f"name = {toml_string(name)}",
                    f"description = {toml_string(description)}",
                    f"model = {toml_string(model)}",
                    f"model_reasoning_effort = {toml_string(effort)}",
                    'developer_instructions = """',
                    body,
                    '"""',
                    "",
                )
            ),
            f"{model} @ {effort}",
        )
    check_roles(manifest, list(bodies))

    generated["codex/profiles.toml"] = (render_profiles(manifest), "from models.conf")
    for relpath, render in ROUTING_BLOCKS:
        text = (ROOT / relpath).read_text(encoding="utf-8")
        generated[relpath] = (with_routing_block(relpath, text, render(manifest)), "routing block from models.conf")

    for filename, number, stage, agent, part, closing in PROMPTS:
        if agent not in bodies:
            raise FrontmatterError(f"codex/{filename}: source agent {agent!r} has no file in agents/")
        source_name, body = bodies[agent]
        blocks = [
            f"# Compute Squad Stage {number}: {stage} (paste into a fresh Codex session)\n"
            f"<!-- generated by codex/build-agents.py from agents/{source_name}, compute-squad {VERSION}; do not edit -->",
            PROMPT_NOTE,
            prompt_body(SOURCE / source_name, body, part),
        ]
        if closing:
            blocks.append(closing)
        generated[f"codex/{filename}"] = ("\n\n".join(blocks) + "\n", f"from agents/{source_name}")
    return generated


def toml_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def check(generated: dict[str, tuple[str, str]]) -> bool:
    mismatches: list[tuple[str, str, str]] = []
    for relpath, (expected, _label) in generated.items():
        path = ROOT / relpath
        actual = path.read_text(encoding="utf-8") if path.exists() else ""
        if actual != expected:
            mismatches.append((relpath, actual, expected))
    if not mismatches:
        print(f"--check: {len(generated)} file(s) in sync")
        return True

    print(f"--check: {len(mismatches)} file(s) out of sync")
    for relpath, actual, expected in mismatches:
        print(f"\n--- {relpath} ---")
        sys.stdout.writelines(
            difflib.unified_diff(
                actual.splitlines(keepends=True),
                expected.splitlines(keepends=True),
                fromfile=f"committed/{relpath}",
                tofile=f"generated/{relpath}",
            )
        )
    return False


class CatalogFormatError(ValueError):
    """The catalog is not the JSON --validate-catalog knows how to read."""


def pinned_pairs(texts: dict | None = None) -> dict:
    """Return {(model, effort): [where]} for every model and reasoning effort
    pinned by codex/agents/*.toml and the tables of codex/profiles.toml: the
    committed files, or texts ({relpath: content}) when given."""
    if texts is None:
        sources = sorted(OUTPUT.glob("*.toml"))
        if not sources:
            raise BuildError("codex/agents/ holds no *.toml; run python3 codex/build-agents.py")
        sources.append(ROOT / "codex" / "profiles.toml")
        texts = {path.relative_to(ROOT).as_posix(): path.read_text(encoding="utf-8") for path in sources}
    pairs: dict = {}
    for relpath, text in texts.items():
        tables: dict = {}
        table = ""
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("developer_instructions"):
                break
            if line.startswith("["):
                table = line
                continue
            match = PINNED_KEY.match(line)
            if match:
                tables.setdefault(table, {})[match.group(1)] = match.group(2)
        if not tables:
            raise BuildError(f"{relpath}: pins no model")
        for table, keys in tables.items():
            where = f"{relpath} {table}" if table else relpath
            if set(keys) != {"model", "model_reasoning_effort"}:
                raise BuildError(f"{where}: needs both a model and a model_reasoning_effort line")
            pairs.setdefault((keys["model"], keys["model_reasoning_effort"]), []).append(where)
    return pairs


def parse_catalog_time(value: object) -> datetime.datetime:
    """Parse a catalog timestamp such as 2026-08-31T19:00:00Z as UTC."""
    if not isinstance(value, str):
        raise CatalogFormatError(f"retirement_at {value!r} is not a timestamp")
    text = value.strip()
    if text[-1:] in ("Z", "z"):
        text = text[:-1] + "+00:00"
    # Python 3.9's fromisoformat takes exactly 3 or 6 fractional digits.
    text = re.sub(r"\.([0-9]+)", lambda m: "." + (m.group(1) + "000000")[:6], text, count=1)
    try:
        moment = datetime.datetime.fromisoformat(text)
    except ValueError:
        raise CatalogFormatError(f"retirement_at {value!r} is not an ISO 8601 timestamp") from None
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=datetime.timezone.utc)
    return moment


def load_catalog(text: str, pinned: list) -> dict:
    """Return {slug: entry} from the JSON `codex debug models` prints. Every
    key the validation reads must be there; a missing one is a format error,
    never a default."""
    try:
        data = json.loads(text)
    except ValueError as error:
        raise CatalogFormatError(f"not JSON: {error}") from None
    models = data.get("models") if isinstance(data, dict) else None
    if not isinstance(models, list) or not models:
        raise CatalogFormatError("no 'models' list")
    catalog = {}
    for index, entry in enumerate(models):
        if not isinstance(entry, dict) or not isinstance(entry.get("slug"), str) or "visibility" not in entry:
            raise CatalogFormatError(f"models[{index}] has no 'slug' or no 'visibility'")
        catalog[entry["slug"]] = entry
    for model in pinned:
        entry = catalog.get(model)
        if entry is None:
            continue
        levels = entry.get("supported_reasoning_levels")
        if not isinstance(levels, list) or not all(
            isinstance(level, dict) and isinstance(level.get("effort"), str) for level in levels
        ):
            raise CatalogFormatError(f"{model} has no 'supported_reasoning_levels' list with an 'effort' in each")
        if "upgrade" not in entry:
            raise CatalogFormatError(f"{model} has no 'upgrade' key")
        upgrade = entry["upgrade"]
        if upgrade is None:
            continue
        # Codex 0.156.1 always writes upgrade.model and writes retirement_at
        # only when a retirement is scheduled.
        if not isinstance(upgrade, dict) or "model" not in upgrade:
            raise CatalogFormatError(f"{model}'s 'upgrade' is not an object with a 'model'")
        if upgrade["model"] is not None and not isinstance(upgrade["model"], str):
            raise CatalogFormatError(f"{model}'s upgrade model {upgrade['model']!r} is not a model ID")
        if upgrade.get("retirement_at") is not None:
            parse_catalog_time(upgrade["retirement_at"])
    return catalog


def effective_pin_texts(manifest: dict) -> dict:
    """The agent TOMLs and profiles the effective build would carry, keyed by
    what a message should name: the agent, or the profiles."""
    texts = {}
    for relpath, (content, _label) in build(manifest).items():
        if relpath.startswith("codex/agents/"):
            texts[f"your choices for {pathlib.PurePosixPath(relpath).stem}"] = content
        elif relpath == "codex/profiles.toml":
            texts["your choices for the profiles"] = content
    return texts


def validate_catalog(path: str, strict: bool, choices: str | None = None) -> int:
    """Check every pinned model and effort against a Codex model catalog: the
    committed pins, or with choices the pins the effective build would carry."""
    prefix = "--validate-catalog:"
    if choices:
        pairs = pinned_pairs(effective_pin_texts(effective_manifest(load_manifest(), load_choices(choices))))
    else:
        pairs = pinned_pairs()
    pinned = sorted({model for model, _effort in pairs})
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        print(f"{prefix} FAIL: cannot read the catalog {path}: {error}", file=sys.stderr)
        return 1
    try:
        catalog = load_catalog(text, pinned)
    except CatalogFormatError as error:
        level = "FAIL" if strict else "WARN"
        print(f"{prefix} {level}: catalog format not recognized; models were not validated ({error})", file=sys.stderr)
        return 1 if strict else 0

    failures, warnings = check_pins(catalog, pairs, strict, SUPERSEDED_CHOICE if choices else SUPERSEDED)
    for message in warnings:
        print(f"{prefix} WARN: {message}", file=sys.stderr)
    for message in failures:
        print(f"{prefix} FAIL: {message}", file=sys.stderr)
    if failures:
        listed = sorted(slug for slug, entry in catalog.items() if entry["visibility"] == "list")
        print(f"{prefix} the catalog lists: {', '.join(listed) or 'no models'}", file=sys.stderr)
        return 1
    pins = sum(len(ws) for ws in pairs.values())
    print(
        f"{prefix} {pins} pins name {len(pinned)} models; each is in the catalog, is not retired, and supports "
        f"its pinned reasoning effort ({len(warnings)} warnings)"
    )
    return 0


def check_pins(catalog: dict, pairs: dict, strict: bool, superseded: str = SUPERSEDED) -> tuple[list, list]:
    """Return (failures, warnings) for pinned (model, effort) pairs against a
    catalog load_catalog has checked for those models."""
    pinned = sorted({model for model, _effort in pairs})
    now = datetime.datetime.now(datetime.timezone.utc)
    failures, warnings = [], []
    for model in pinned:
        where = sorted({w for (m, _effort), ws in pairs.items() if m == model for w in ws})
        pinned_in = f"pinned in {', '.join(where)}"
        entry = catalog.get(model)
        if entry is None:
            failures.append(f"{model} is not in the model catalog; {pinned_in}")
            continue
        supported = [level["effort"] for level in entry["supported_reasoning_levels"]]
        for (m, effort), effort_where in sorted(pairs.items()):
            if m == model and effort not in supported:
                failures.append(
                    f"{model} does not support reasoning effort {effort!r} (it supports "
                    f"{', '.join(supported) or 'none'}); pinned in {', '.join(effort_where)}"
                )
        upgrade = entry["upgrade"]
        if upgrade is None:
            continue
        if upgrade.get("retirement_at") is not None:
            retires = parse_catalog_time(upgrade["retirement_at"])
            if retires <= now:
                failures.append(f"{model} was retired at {upgrade['retirement_at']}; {pinned_in}")
            elif retires - now <= datetime.timedelta(days=RETIREMENT_WARNING_DAYS):
                soon = f"{model} retires at {upgrade['retirement_at']}, within {RETIREMENT_WARNING_DAYS} days; {pinned_in}"
                (failures if strict else warnings).append(soon)
        if upgrade["model"]:
            warnings.append(superseded.format(model=model, target=upgrade["model"]))
    return failures, warnings


def read_catalog(path: str) -> tuple[str, dict]:
    """Return (text, {slug: entry}) from a catalog file. Only each entry's
    slug and visibility are required here; the chooser and the fingerprint
    read the rest through efforts_of and upgrade_of, so one odd entry never
    blocks a choice between the others."""
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise CatalogFormatError(f"cannot read the catalog {path}: {error}") from None
    return text, load_catalog(text, [])


def efforts_of(entry: dict) -> list:
    """The efforts a catalog entry supports; none when it lists none."""
    levels = entry.get("supported_reasoning_levels")
    if not isinstance(levels, list):
        return []
    return [level["effort"] for level in levels if isinstance(level, dict) and isinstance(level.get("effort"), str)]


def upgrade_of(entry: dict) -> dict:
    """A catalog entry's upgrade object; empty when it has none."""
    upgrade = entry.get("upgrade")
    return upgrade if isinstance(upgrade, dict) else {}


def catalog_fingerprint(catalog: dict) -> str:
    """SHA-256 over what a choice depends on: each listed model's slug, its
    efforts, its upgrade target, and its retirement, sorted by slug. Catalog
    order and other metadata do not change it; a newly listed model does."""
    reduced = []
    for slug in sorted(s for s, entry in catalog.items() if entry["visibility"] == "list"):
        upgrade = upgrade_of(catalog[slug])
        reduced.append({
            "slug": slug,
            "efforts": sorted(efforts_of(catalog[slug])),
            "upgrade": upgrade.get("model"),
            "retirement": upgrade.get("retirement_at"),
        })
    return hashlib.sha256(json.dumps(reduced, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def release_choices(release: dict) -> dict:
    """The release pins in choices form, shown as the defaults on first setup:
    each tier's Codex model and the effort of the first role on that Codex
    rung, and the main session's effort."""
    tiers = {}
    for rung in RUNGS:
        efforts = [
            row["codex_effort"] for role, row in release["roles"].items()
            if role != "strategy" and row["codex_rung"] == rung
        ]
        if not efforts:
            raise ManifestError(f"models.conf: no role besides strategy is on the Codex {rung} rung")
        tiers[rung] = {"codex": release["rungs"][rung]["codex"], "codex_effort": efforts[0]}
    return {"main_effort": release["roles"]["strategy"]["codex_effort"], "tiers": tiers}


def render_choices(choices: dict) -> str:
    width = max(len("codex"), *(len(choices["tiers"][rung]["codex"]) for rung in RUNGS)) + 2
    rows = [f"{'[tier]':<9}{'codex':<{width}}codex_effort"]
    rows += [
        f"{rung:<9}{choices['tiers'][rung]['codex']:<{width}}{choices['tiers'][rung]['codex_effort']}"
        for rung in RUNGS[::-1]
    ]
    return (
        "# Compute Squad: Codex model choices for this Codex home.\n"
        "# Written by `bash codex/update.sh --review-models`; rerun it to change them.\n"
        f"chosen {choices['chosen']}\n"
        f"catalog {choices['catalog']}\n"
        f"main_effort {choices['main_effort']}\n"
        "\n" + "\n".join(rows) + "\n"
    )


def write_choices(path: str, choices: dict) -> None:
    """Write the choices through a temp file in the same directory, so a
    reader never sees a partial file."""
    text = render_choices(choices)
    parse_choices(text, path)
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=".choices.", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    except BaseException:
        if os.path.exists(temp):
            os.unlink(temp)
        raise


class Cancelled(Exception):
    pass


def ask(prompt: str) -> str:
    print(prompt, end="", flush=True)
    line = sys.stdin.readline()
    if not line:
        raise Cancelled
    return line.strip()


def choose(catalog_path: str, choices_path: str) -> int:
    """Ask which listed model and effort fills each Codex tier, then the main
    session's effort; save only on a literal `yes`. It never picks, ranks, or
    substitutes a model."""
    prefix = "--choose:"
    if not os.isatty(0):
        print(f"{prefix} needs a terminal; run `bash codex/update.sh --review-models` in one", file=sys.stderr)
        return 2
    try:
        text, catalog = read_catalog(catalog_path)
        release = load_manifest()
        defaults = release_choices(release)
    except (CatalogFormatError, BuildError) as error:
        print(f"{prefix} FAIL: {error}; nothing changed", file=sys.stderr)
        return 1
    saved = None
    if os.path.exists(choices_path):
        try:
            saved = load_choices(choices_path)
        except ManifestError as error:
            print(f"Your saved choices cannot be read ({error}); showing the release defaults. "
                  f"Saving replaces {choices_path}.")
    current = saved or defaults
    source = "saved" if saved else "release default"
    now = datetime.datetime.now(datetime.timezone.utc)
    main_rung = release["roles"]["strategy"]["codex_rung"]

    def retired_at(entry: dict):
        at = upgrade_of(entry).get("retirement_at")
        try:
            return at if at is not None and parse_catalog_time(at) <= now else None
        except CatalogFormatError:
            return None

    print("Codex models your account's catalog lists (listing is availability, not a recommendation):")
    for slug in sorted(s for s, entry in catalog.items() if entry["visibility"] == "list"):
        entry = catalog[slug]
        upgrade = upgrade_of(entry)
        facts = [f"efforts {', '.join(efforts_of(entry)) or 'none'}"]
        if upgrade.get("model"):
            facts.append(f"superseded by {upgrade['model']}")
        if upgrade.get("retirement_at"):
            facts.append(f"{'retired' if retired_at(entry) else 'retires'} at {upgrade['retirement_at']}")
        print(f"  {slug}: {'; '.join(facts)}")
    print("Press Enter to keep the value in brackets.")

    def reject(reason: str) -> None:
        print(f"  rejected: {reason}; choose again")

    try:
        tiers: dict = {}
        for rung in RUNGS[::-1]:
            shown = current["tiers"][rung]
            while True:
                model = ask(f"{rung} tier model [{shown['codex']}, {source}]: ") or shown["codex"]
                entry = catalog.get(model)
                taken = [other for other, row in tiers.items() if row["codex"] == model]
                if entry is None:
                    reject(f"{model} is not in this account's model catalog")
                elif entry["visibility"] != "list":
                    reject(f"{model} is hidden in the catalog (visibility {entry['visibility']})")
                elif retired_at(entry):
                    reject(f"{model} was retired at {retired_at(entry)}")
                elif not efforts_of(entry):
                    reject(f"the catalog lists no reasoning efforts for {model}")
                elif taken:
                    reject(f"{model} is already the {taken[0]} tier's model; each tier needs its own model")
                else:
                    break
            supported = efforts_of(entry)
            while True:
                effort = ask(
                    f"{rung} tier reasoning effort for {model} (it supports {', '.join(supported)}) "
                    f"[{shown['codex_effort']}, {source}]: "
                ) or shown["codex_effort"]
                if effort in supported:
                    break
                reject(f"{model} does not support reasoning effort {effort!r}")
            tiers[rung] = {"codex": model, "codex_effort": effort}
        main_model = tiers[main_rung]["codex"]
        supported = efforts_of(catalog[main_model])
        while True:
            main_effort = ask(
                f"main session reasoning effort on {main_model} (it supports {', '.join(supported)}) "
                f"[{current['main_effort']}, {source}]: "
            ) or current["main_effort"]
            if main_effort in supported:
                break
            reject(f"{main_model} does not support reasoning effort {main_effort!r}")

        chosen = {
            "chosen": now.date().isoformat(),
            "catalog": catalog_fingerprint(catalog),
            "main_effort": main_effort,
            "tiers": tiers,
        }
        manifest = effective_manifest(release, chosen)
        print("\nResulting Codex routing (the release's rungs, your models and efforts):")
        for label in LABELS:
            rung = manifest["roles"][label.role]["codex_rung"]
            print(
                f"  {label.role:<27}{rung:<8}{manifest['rungs'][rung]['codex']:<24}"
                f"{manifest['roles'][label.role]['codex_effort']}"
            )
        print("Profiles:")
        for profile, role in PROFILES:
            print(
                f"  {profile:<27}{model_of(manifest, role, 'codex'):<24}{manifest['roles'][role]['codex_effort']}"
            )
        print(f"Changes against the {'saved choices' if saved else 'release defaults'}:")
        for rung in RUNGS[::-1]:
            before = f"{current['tiers'][rung]['codex']} {current['tiers'][rung]['codex_effort']}"
            after = f"{tiers[rung]['codex']} {tiers[rung]['codex_effort']}"
            print(f"  {rung}: {'unchanged (' + after + ')' if before == after else before + ' -> ' + after}")
        if current["main_effort"] == main_effort:
            print(f"  main session effort: unchanged ({main_effort})")
        else:
            print(f"  main session effort: {current['main_effort']} -> {main_effort}")
        if ask("Type yes to save these choices: ") != "yes":
            raise Cancelled
    except (Cancelled, KeyboardInterrupt):
        print("\ncancelled; nothing changed")
        return 1

    pairs = pinned_pairs(effective_pin_texts(manifest))
    try:
        load_catalog(text, sorted({model for model, _effort in pairs}))
    except CatalogFormatError as error:
        print(f"{prefix} FAIL: the catalog entry for a chosen model is not in a form this script reads ({error}); "
              "not saved; nothing changed", file=sys.stderr)
        return 1
    failures, warnings = check_pins(catalog, pairs, strict=False, superseded=SUPERSEDED_CHOICE)
    for message in warnings:
        print(f"{prefix} WARN: {message}", file=sys.stderr)
    if failures:
        for message in failures:
            print(f"{prefix} FAIL: {message}", file=sys.stderr)
        print(f"{prefix} not saved; nothing changed", file=sys.stderr)
        return 1
    write_choices(choices_path, chosen)
    print(f"saved {choices_path}")
    return 0


def catalog_status(catalog_path: str, choices_path: str) -> int:
    """Print unsaved, current, changed, or unknown (a catalog this script
    cannot read). Writes nothing."""
    if not os.path.exists(choices_path):
        print("unsaved")
        return 0
    choices = load_choices(choices_path)
    try:
        fingerprint = catalog_fingerprint(read_catalog(catalog_path)[1])
    except CatalogFormatError:
        print("unknown")
        return 0
    print("current" if fingerprint == choices["catalog"] else "changed")
    return 0


def render_codex(outdir: str, choices_path: str) -> int:
    """Write the effective Codex build into a new directory: a local
    marketplace (compute-squad-local) whose plugin is this checkout's tracked
    .codex-plugin/ and skills/ files, with the skill's routing block rendered
    from the effective models; the seven agent TOMLs; and the four profile
    files. Every file comes from one render of one manifest."""
    out = pathlib.Path(outdir)
    if out.exists():
        raise BuildError(f"{outdir} already exists; --render-codex writes a new directory")
    choices = load_choices(choices_path)
    manifest = effective_manifest(load_manifest(), choices)
    generated = build(manifest)
    git = os.environ.get("GIT_BIN") or "git"
    try:
        listing = subprocess.run(
            [git, "-C", str(ROOT), "ls-files", "-z", "--", ".codex-plugin", "skills"],
            capture_output=True, check=True,
        ).stdout.decode("utf-8")
    except (OSError, subprocess.CalledProcessError) as error:
        raise BuildError(f"cannot list the plugin's tracked files with {git}: {error}") from None
    payload = sorted(path for path in listing.split("\0") if path)
    if ".codex-plugin/plugin.json" not in payload or "skills/compute-squad/SKILL.md" not in payload:
        raise BuildError(f"{git} ls-files did not list .codex-plugin/plugin.json and skills/compute-squad/SKILL.md")

    plugin = out / "plugins" / "compute-squad"
    for relpath in payload:
        dest = plugin / relpath
        dest.parent.mkdir(parents=True, exist_ok=True)
        if relpath in generated:
            dest.write_text(generated[relpath][0], encoding="utf-8")
        else:
            shutil.copyfile(ROOT / relpath, dest)
        shutil.copymode(ROOT / relpath, dest)
    release_market = json.loads((ROOT / ".agents" / "plugins" / "marketplace.json").read_text(encoding="utf-8"))
    entry = release_market["plugins"][0]
    marketplace = {
        "name": "compute-squad-local",
        "interface": {"displayName": "Compute Squad (local build)"},
        "plugins": [{
            "name": entry["name"],
            "source": {"source": "local", "path": "./plugins/compute-squad"},
            "policy": entry["policy"],
            "category": entry["category"],
        }],
    }
    (out / ".agents" / "plugins").mkdir(parents=True)
    (out / ".agents" / "plugins" / "marketplace.json").write_text(json.dumps(marketplace, indent=2) + "\n", encoding="utf-8")
    (out / "agents").mkdir()
    for relpath, (content, _label) in generated.items():
        if relpath.startswith("codex/agents/"):
            (out / "agents" / pathlib.PurePosixPath(relpath).name).write_text(content, encoding="utf-8")
    (out / "profiles").mkdir()
    for profile, role in PROFILES:
        (out / "profiles" / f"{profile}.config.toml").write_text(
            f"model = {toml_string(model_of(manifest, role, 'codex'))}\n"
            f"model_reasoning_effort = {toml_string(manifest['roles'][role]['codex_effort'])}\n",
            encoding="utf-8",
        )
    tiers = "; ".join(
        f"{rung} {choices['tiers'][rung]['codex']} {choices['tiers'][rung]['codex_effort']}" for rung in RUNGS[::-1]
    )
    print(f"{tiers}; main session effort {choices['main_effort']}")
    return 0


USAGE = (
    "usage: build-agents.py [--check | --parse-manifest PATH | --validate-catalog PATH [--strict] [--choices CHOICES]"
    " | --choose CATALOG CHOICES | --catalog-status CATALOG CHOICES | --render-codex OUTDIR CHOICES]"
)


def main(args: list) -> int:
    if args[:1] == ["--validate-catalog"]:
        options = args[2:]
        strict = options[:1] == ["--strict"]
        if strict:
            options = options[1:]
        choices = None
        if len(options) == 2 and options[0] == "--choices":
            choices, options = options[1], []
        if len(args) < 2 or options:
            print(USAGE, file=sys.stderr)
            return 2
        try:
            return validate_catalog(args[1], strict=strict, choices=choices)
        except BuildError as error:
            print(f"FAIL: {error}", file=sys.stderr)
            return 1
    for flag, run in (("--choose", choose), ("--catalog-status", catalog_status), ("--render-codex", render_codex)):
        if args[:1] == [flag]:
            if len(args) != 3:
                print(USAGE, file=sys.stderr)
                return 2
            try:
                return run(args[1], args[2])
            except (BuildError, CatalogFormatError, OSError) as error:
                print(f"{flag}: FAIL: {error}", file=sys.stderr)
                return 1
    if args[:1] == ["--parse-manifest"]:
        if len(args) != 2:
            print(USAGE, file=sys.stderr)
            return 2
        try:
            text = pathlib.Path(args[1]).read_text(encoding="utf-8")
            manifest = parse_manifest(text, args[1])
        except (OSError, ManifestError) as error:
            print(f"FAIL: {error}", file=sys.stderr)
            return 1
        print(json.dumps(manifest, indent=2))
        return 0
    if args not in ([], ["--check"]):
        print(USAGE, file=sys.stderr)
        return 2

    try:
        generated = build()
    except BuildError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1

    if args == ["--check"]:
        return 0 if check(generated) else 1

    OUTPUT.mkdir(parents=True, exist_ok=True)
    for relpath, (content, label) in generated.items():
        (ROOT / relpath).write_text(content, encoding="utf-8")
        print(f"wrote {relpath} ({label})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
