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
"""

from __future__ import annotations

import collections
import datetime
import difflib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "agents"
OUTPUT = ROOT / "codex" / "agents"
MANIFEST = ROOT / "models.conf"
VERSION = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]

# models.conf grammar: blank lines, '#' comment lines, one 'reviewed
# YYYY-MM-DD' line before the first section, and the two sections below. A
# '[name]' line opens a section and names its columns; every row in it is a
# key plus exactly one field per column. Rungs are listed lowest first.
RUNGS = ("bottom", "mid", "top")
SECTION_COLUMNS = {
    "rung": ("claude", "codex"),
    "role": ("claude_rung", "codex_rung", "codex_effort"),
}
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
    ("squad-executor-haiku", None, "MECHANICAL execution", None,
     "Execution on MECHANICAL", "The same executor protocol, {rung} rung"),
    ("squad-executor-opus", None, "COMPLEX execution", None,
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
# its model and effort from one models.conf role. codex/update.sh reads it.
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
    ("compute-squad-mechanical", "squad-executor-haiku"),
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
    "02-recon.md": ("Read-only codebase mapping", (("", "squad-recon"),)),
    "03-pm-plan.md": ("Spec + task breakdown, no code", (("", "squad-pm"),)),
    "04-execute.md": (
        "Implementation, exactly per plan",
        (("STANDARD ", "squad-executor"), ("MECHANICAL ", "squad-executor-haiku"), ("COMPLEX ", "squad-executor-opus")),
    ),
    "05-pm-accept.md": ("Adversarial acceptance, PASS/FAIL", (("", "squad-pm"),)),
}

ROUTING_BEGIN = "<!-- routing:begin -->"
ROUTING_END = "<!-- routing:end -->"


class BuildError(ValueError):
    pass


class FrontmatterError(BuildError):
    pass


class ManifestError(BuildError):
    pass


def parse_manifest(text: str, source: str = "models.conf") -> dict:
    """Parse a manifest. Any line the grammar does not allow is an error,
    never a default."""
    reviewed = None
    sections: dict = {}
    current = None
    for number, raw in enumerate(text.splitlines(), 1):
        where = f"{source}:{number}"
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if fields[0].startswith("["):
            name = fields[0][1:-1] if fields[0].endswith("]") else ""
            if name not in SECTION_COLUMNS:
                known = ", ".join(f"[{section}]" for section in SECTION_COLUMNS)
                raise ManifestError(f"{where}: unknown section {fields[0]!r}; the sections are {known}")
            if name in sections:
                raise ManifestError(f"{where}: section [{name}] appears twice")
            if tuple(fields[1:]) != SECTION_COLUMNS[name]:
                raise ManifestError(
                    f"{where}: [{name}] must name the columns {' '.join(SECTION_COLUMNS[name])}; "
                    f"found {' '.join(fields[1:]) or 'none'}"
                )
            current = name
            sections[name] = {}
            continue
        if current is None:
            if fields[0] != "reviewed":
                raise ManifestError(f"{where}: {line!r} is outside a section")
            if reviewed is not None:
                raise ManifestError(f"{where}: a second 'reviewed' line")
            if len(fields) != 2 or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", fields[1]):
                raise ManifestError(f"{where}: expected 'reviewed YYYY-MM-DD'; found {line!r}")
            try:
                datetime.date.fromisoformat(fields[1])
            except ValueError:
                raise ManifestError(f"{where}: {fields[1]!r} is not a calendar date") from None
            reviewed = fields[1]
            continue
        columns = SECTION_COLUMNS[current]
        if len(fields) != len(columns) + 1:
            raise ManifestError(
                f"{where}: a [{current}] row has {len(columns) + 1} fields ({current} {' '.join(columns)}); "
                f"found {len(fields)} in {line!r}"
            )
        key = fields[0]
        if key in sections[current]:
            raise ManifestError(f"{where}: [{current}] row {key!r} appears twice")
        row = dict(zip(columns, fields[1:]))
        if current == "rung" and key not in RUNGS:
            raise ManifestError(f"{where}: unknown rung {key!r}; the rungs are {', '.join(RUNGS)}")
        if current == "role":
            for column in ("claude_rung", "codex_rung"):
                if row[column] not in RUNGS:
                    raise ManifestError(
                        f"{where}: {key} has unknown {column} {row[column]!r}; the rungs are {', '.join(RUNGS)}"
                    )
        sections[current][key] = row
    if reviewed is None:
        raise ManifestError(f"{source}: no 'reviewed YYYY-MM-DD' line")
    for name in SECTION_COLUMNS:
        if name not in sections:
            raise ManifestError(f"{source}: no [{name}] section")
        if not sections[name]:
            raise ManifestError(f"{source}: the [{name}] section has no rows")
    for rung in RUNGS:
        if rung not in sections["rung"]:
            raise ManifestError(f"{source}: [rung] has no {rung!r} row")
    return {
        "reviewed": reviewed,
        "rungs": {rung: sections["rung"][rung] for rung in RUNGS},
        "roles": sections["role"],
    }


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
    lines = [
        f"Generated from `models.conf` (reviewed {manifest['reviewed']}); edit that file, never this block.",
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


def build() -> dict[str, tuple[str, str]]:
    """Return {path relative to the repo root: (content, label)} for every generated file."""
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


USAGE = "usage: build-agents.py [--check | --parse-manifest PATH]"


def main(args: list) -> int:
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
