#!/usr/bin/env bash
# Verification gate for the compute-squad plugin repo. Run from anywhere;
# paths resolve against the repo root. Requires python3 and unzip.
#
# Checks, in order:
#   1. .claude-plugin/plugin.json and .claude-plugin/marketplace.json parse as JSON.
#   2. Every agents/*.md has YAML frontmatter that parses, model in
#      {sonnet, opus, haiku}, and at least one <example> block in the description.
#   3. skills/compute-squad/SKILL.md frontmatter parses and its metadata.version
#      equals plugin.json's version.
#   4. CHANGELOG.md has a heading for that version.
#   5. dist/compute-squad.plugin matches skills/, agents/, README.md, and
#      .claude-plugin/plugin.json by content (unzip + diff -r, not a rebuild+byte-diff,
#      since zip embeds mtimes and a fresh rebuild would always differ).
#
# Frontmatter is parsed with a small stdlib-only parser (no PyYAML dependency),
# so failures are about the repo, not about whether a YAML library happens to
# be installed on the machine running this script.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 is required but not installed" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Checks 1-4: JSON validity, agent frontmatter, SKILL.md version, changelog.
# ---------------------------------------------------------------------------
python3 <<'PYEOF'
import glob
import json
import os
import re
import sys


def fail(check, msg):
    print(f"FAIL: check {check}: {msg}", file=sys.stderr)
    sys.exit(1)


def ok(check, msg):
    print(f"PASS: check {check}: {msg}")


# ---- Check 1: plugin.json and marketplace.json parse as JSON ----
plugin_path = ".claude-plugin/plugin.json"
marketplace_path = ".claude-plugin/marketplace.json"

for path in (plugin_path, marketplace_path):
    if not os.path.isfile(path):
        fail(1, f"{path} does not exist")
    try:
        with open(path, encoding="utf-8") as f:
            json.load(f)
    except Exception as e:
        fail(1, f"{path} is not valid JSON: {e}")

with open(plugin_path, encoding="utf-8") as f:
    plugin_json = json.load(f)

plugin_version = plugin_json.get("version")
if not plugin_version:
    fail(1, f"{plugin_path} has no top-level 'version' field")

ok(1, "plugin.json and marketplace.json parse as JSON")


# ---- Shared frontmatter parser (stdlib only, no PyYAML dependency) ----
class FrontmatterError(Exception):
    pass


KEY_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_-]*):[ \t]*(.*)$')
BLOCK_INDICATORS = {"|", ">", "|-", ">-", "|+", ">+"}


def split_frontmatter(text, path):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise FrontmatterError(f"{path}: missing opening '---' frontmatter delimiter")
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        raise FrontmatterError(f"{path}: missing closing '---' frontmatter delimiter")
    return lines[1:end]


def parse_block(lines, i, indent, path):
    """Parse mapping entries at a given indent level. Returns (dict, next_i)."""
    result = {}
    n = len(lines)
    while i < n:
        raw = lines[i]
        if raw.strip() == "":
            i += 1
            continue
        cur_indent = len(raw) - len(raw.lstrip(" "))
        if cur_indent < indent:
            break
        if cur_indent > indent:
            raise FrontmatterError(f"{path}: unexpected indentation at line {i + 1}: {raw!r}")
        m = KEY_RE.match(raw.strip())
        if not m:
            raise FrontmatterError(f"{path}: unparsable frontmatter line {i + 1}: {raw!r}")
        key, val = m.group(1), m.group(2).strip()
        i += 1
        if val in BLOCK_INDICATORS:
            block = []
            block_indent = None
            while i < n:
                bl = lines[i]
                if bl.strip() == "":
                    block.append("")
                    i += 1
                    continue
                bl_indent = len(bl) - len(bl.lstrip(" "))
                if bl_indent <= indent:
                    break
                if block_indent is None:
                    block_indent = bl_indent
                block.append(bl[block_indent:])
                i += 1
            result[key] = "\n".join(block).rstrip("\n")
        elif val == "":
            j = i
            while j < n and lines[j].strip() == "":
                j += 1
            if j < n:
                nxt_indent = len(lines[j]) - len(lines[j].lstrip(" "))
                if nxt_indent > indent:
                    sub, i = parse_block(lines, i, nxt_indent, path)
                    result[key] = sub
                    continue
            result[key] = ""
        else:
            if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
                val = val[1:-1]
            result[key] = val
    return result, i


def parse_frontmatter(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    fm_lines = split_frontmatter(text, path)
    data, _ = parse_block(fm_lines, 0, 0, path)
    return data


# ---- Check 2: every agents/*.md has frontmatter that parses, an allowed
# model, and at least one <example> block in the description ----
agent_paths = sorted(glob.glob("agents/*.md"))
if not agent_paths:
    fail(2, "no files matched agents/*.md")

ALLOWED_MODELS = {"sonnet", "opus", "haiku"}
EXAMPLE_RE = re.compile(r"<example>.*?</example>", re.DOTALL)

for path in agent_paths:
    try:
        data = parse_frontmatter(path)
    except FrontmatterError as e:
        fail(2, str(e))

    model = data.get("model")
    if model not in ALLOWED_MODELS:
        fail(2, f"{path}: model {model!r} not in {sorted(ALLOWED_MODELS)}")

    description = data.get("description", "")
    if not EXAMPLE_RE.search(description):
        fail(2, f"{path}: description has no <example>...</example> block")

ok(2, f"{len(agent_paths)} agent files have valid frontmatter, an allowed model, and an <example> block")


# ---- Check 3: SKILL.md frontmatter parses and metadata.version matches
# plugin.json's version ----
skill_path = "skills/compute-squad/SKILL.md"
if not os.path.isfile(skill_path):
    fail(3, f"{skill_path} does not exist")

try:
    skill_data = parse_frontmatter(skill_path)
except FrontmatterError as e:
    fail(3, str(e))

metadata = skill_data.get("metadata")
if not isinstance(metadata, dict):
    fail(3, f"{skill_path}: frontmatter has no 'metadata' mapping")

skill_version = metadata.get("version")
if skill_version != plugin_version:
    fail(3, f"{skill_path}: metadata.version {skill_version!r} != {plugin_path} version {plugin_version!r}")

ok(3, f"{skill_path} metadata.version matches {plugin_path} version ({plugin_version})")


# ---- Check 4: CHANGELOG.md has a heading for this version ----
changelog_path = "CHANGELOG.md"
if not os.path.isfile(changelog_path):
    fail(4, f"{changelog_path} does not exist")

with open(changelog_path, encoding="utf-8") as f:
    changelog = f.read()

heading_re = re.compile(r"^#{1,6}\s*" + re.escape(plugin_version) + r"(\s|$)", re.MULTILINE)
if not heading_re.search(changelog):
    fail(4, f"{changelog_path} has no heading for version {plugin_version}")

ok(4, f"{changelog_path} has a heading for version {plugin_version}")
PYEOF

# ---------------------------------------------------------------------------
# Check 5: dist/compute-squad.plugin matches source by content (not bytes).
#
# We do NOT rebuild the zip and byte-diff it: zip embeds file mtimes, so a
# rebuild from a fresh checkout always differs and the gate would be
# permanently red. Instead, unzip the shipped artifact and diff its content
# tree against the working tree.
# ---------------------------------------------------------------------------
plugin_zip="dist/compute-squad.plugin"

if [ ! -f "$plugin_zip" ]; then
  echo "FAIL: check 5: $plugin_zip does not exist" >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "FAIL: check 5: unzip is required but not installed" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

unzip -q "$plugin_zip" -d "$tmpdir"

check5_failed=0
for target in skills agents README.md .claude-plugin/plugin.json; do
  if [ ! -e "$tmpdir/$target" ]; then
    echo "FAIL: check 5: $plugin_zip has no $target" >&2
    check5_failed=1
    continue
  fi
  if [ ! -e "$target" ]; then
    echo "FAIL: check 5: working tree has no $target" >&2
    check5_failed=1
    continue
  fi
  if ! diff -r "$tmpdir/$target" "$target"; then
    echo "FAIL: check 5: $plugin_zip is out of sync with $target (see diff above)" >&2
    check5_failed=1
  fi
done

if [ "$check5_failed" -ne 0 ]; then
  echo "FAIL: check 5: $plugin_zip drifted from source; rebuild with scripts/build-plugin.sh and commit" >&2
  exit 1
fi

echo "PASS: check 5: $plugin_zip matches skills/, agents/, README.md, and plugin.json by content"

echo "verify.sh: all checks passed"
