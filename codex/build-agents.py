#!/usr/bin/env python3
"""Generate the Codex agent TOMLs and the manual Codex prompts
(codex/01-archive.md to codex/05-pm-accept.md) from the canonical Claude
agent markdown."""

from __future__ import annotations

import difflib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "agents"
OUTPUT = ROOT / "codex" / "agents"

MODEL_BY_TIER = {
    "opus": ("gpt-5.6-sol", "max"),
    "sonnet": ("gpt-5.6-terra", "max"),
    "haiku": ("gpt-5.6-luna", "max"),
}
TIER_TERMS = (
    ("Opus-tier", "Sol-tier"),
    ("Sonnet-tier", "Terra-tier"),
    ("Haiku-tier", "Luna-tier"),
    ("Opus", "gpt-5.6-sol"),
    ("Sonnet", "gpt-5.6-terra"),
    ("Haiku", "gpt-5.6-luna"),
)
VERSION = json.loads((ROOT / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]

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


class FrontmatterError(ValueError):
    pass


def parse_frontmatter(path: pathlib.Path) -> tuple[str, str, str, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    if not match:
        raise FrontmatterError(f"{path}: missing YAML frontmatter")

    frontmatter, body = match.groups()
    name_match = re.search(r"^name:\s*(.+)$", frontmatter, re.MULTILINE)
    model_match = re.search(r"^model:\s*(.+)$", frontmatter, re.MULTILINE)
    if not name_match or not model_match:
        raise FrontmatterError(f"{path}: frontmatter needs name and model")

    description_match = re.search(
        r"^description:\s*(.+?)(?=\n[a-z_]+:|\Z)",
        frontmatter,
        re.MULTILINE | re.DOTALL,
    )
    if not description_match:
        raise FrontmatterError(f"{path}: frontmatter needs description")

    name = name_match.group(1).strip()
    tier = model_match.group(1).strip().lower()
    description = description_match.group(1).strip()
    description = re.sub(r"^[|>]\+?\-?\s*", "", description)
    description = " ".join(description.split())
    return name, tier, description, body.strip()


def translate_tiers(text: str) -> str:
    for source, target in TIER_TERMS:
        text = text.replace(source, target)
    return text


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


def build() -> dict[str, tuple[str, str]]:
    """Return {path relative to the repo root: (content, label)} for every generated file."""
    generated: dict[str, tuple[str, str]] = {}
    bodies: dict[str, tuple[str, str]] = {}
    for source in sorted(SOURCE.glob("*.md")):
        name, tier, description, body = parse_frontmatter(source)
        bodies[name] = (source.name, body)
        if tier not in MODEL_BY_TIER:
            raise FrontmatterError(f"{source}: unsupported tier {tier!r}")
        model, effort = MODEL_BY_TIER[tier]
        description = translate_tiers(description)
        body = translate_tiers(body)
        if '"""' in body:
            raise FrontmatterError(f"{source}: body contains a TOML triple-quote delimiter")
        if "\\" in body:
            raise FrontmatterError(f"{source}: body contains a backslash, which a TOML basic string reads as an escape")
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


def main() -> int:
    try:
        generated = build()
    except FrontmatterError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1

    if "--check" in sys.argv:
        return 0 if check(generated) else 1

    OUTPUT.mkdir(parents=True, exist_ok=True)
    for relpath, (content, label) in generated.items():
        (ROOT / relpath).write_text(content, encoding="utf-8")
        print(f"wrote {relpath} ({label})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
