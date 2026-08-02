#!/usr/bin/env python3
"""Generate Codex agent TOMLs from the canonical Claude agent markdown."""

from __future__ import annotations

import difflib
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
MODEL_DEFAULTS = {
    "gpt-5.6-sol": "low",
    "gpt-5.6-terra": "medium",
    "gpt-5.6-luna": "medium",
}


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


def build() -> dict[str, tuple[str, str, str]]:
    generated: dict[str, tuple[str, str, str]] = {}
    for source in sorted(SOURCE.glob("*.md")):
        name, tier, description, body = parse_frontmatter(source)
        if tier not in MODEL_BY_TIER:
            raise FrontmatterError(f"{source}: unsupported tier {tier!r}")
        model, effort = MODEL_BY_TIER[tier]
        description = translate_tiers(description)
        body = translate_tiers(body)
        header = (
            f"RUN THIS AGENT ON `{model}` AT `{effort}` REASONING EFFORT. "
            f"Codex defaults to {MODEL_DEFAULTS[model]} reasoning for this model; "
            "the matching profile in codex/profiles.toml is what pins the requested "
            "effort. This header states the requirement; it does not enforce it.\n\n"
        )
        instructions = header + body
        if '"""' in instructions:
            raise FrontmatterError(f"{source}: body contains a TOML triple-quote delimiter")
        generated[f"{name}.toml"] = (
            "\n".join(
                (
                    f"name = {toml_string(name)}",
                    f"description = {toml_string(description)}",
                    f"model = {toml_string(model)}",
                    'developer_instructions = """',
                    instructions,
                    '"""',
                    "",
                )
            ),
            model,
            effort,
        )
    return generated


def toml_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def check(generated: dict[str, tuple[str, str, str]]) -> bool:
    mismatches: list[tuple[str, str, str]] = []
    for filename, (expected, _model, _effort) in generated.items():
        path = OUTPUT / filename
        actual = path.read_text(encoding="utf-8") if path.exists() else ""
        if actual != expected:
            mismatches.append((filename, actual, expected))
    if not mismatches:
        print(f"--check: {len(generated)} file(s) in sync")
        return True

    print(f"--check: {len(mismatches)} file(s) out of sync")
    for filename, actual, expected in mismatches:
        print(f"\n--- {filename} ---")
        sys.stdout.writelines(
            difflib.unified_diff(
                actual.splitlines(keepends=True),
                expected.splitlines(keepends=True),
                fromfile=f"committed/{filename}",
                tofile=f"generated/{filename}",
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
    for filename, (content, model, effort) in generated.items():
        (OUTPUT / filename).write_text(content, encoding="utf-8")
        print(f"wrote {filename} ({model} @ {effort})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
