#!/usr/bin/env bash
# Verification gate for the compute-squad plugin repo. Run from anywhere;
# paths resolve against the repo root. Requires python3 and unzip.
#
# Checks, in order:
#   1. Claude and Codex plugin/marketplace manifests parse as JSON.
#   2. Every agents/*.md has YAML frontmatter that parses, only the keys name,
#      description, model, color, tools, and omitClaudeMd (placed after model),
#      model in {sonnet, opus, haiku}, and at least one <example> block in the
#      description.
#   3. skills/compute-squad/SKILL.md frontmatter parses and its metadata.version
#      equals plugin.json's version. codex/SKILL.md, a reading copy no host
#      loads, opens with its reading-copy title and has a Version: line equal
#      to that version.
#   4. CHANGELOG.md has a heading for that version.
#   5. dist/compute-squad.plugin matches skills/, agents/, commands/, README.md,
#      and .claude-plugin/plugin.json by content (unzip + diff -r, not a rebuild+
#      byte-diff, since zip embeds mtimes and a fresh rebuild would always differ).
#   6. Codex generated files are valid: the agent TOMLs and their model routing,
#      the profiles, the five manual prompts codex/01-archive.md to
#      codex/05-pm-accept.md (each marked as generated on line 2), and
#      codex/build-agents.py --check over all of them.
#   7. Shared protocol blocks and facts read identically across files:
#      7a the Goal — Locked template; 7b the BLOCKER block in both SKILL.md
#      files; 7c the helper cap; 7d the routing block names every pinned
#      model; 7e the product description; 7i log headings stay on SKILL.md's
#      closed list; 7j the archive command; 7l protocol text names rungs, not
#      models, outside the routing block; 7o no file names the deleted routing
#      reference; 7p the shared-span table, whose rows include the blocker
#      grammar span (7k) and the command output forms (7n); 7q the agent
#      description budget; 7r no agent has a tool to spawn agents; 7s
#      codex/SKILL.md stays a reading copy and both SKILL.md files carry the
#      no-absorption rule.
#   8. Behavior without a model, on fixtures under tests/: log grammar (8a)
#      and codex/update.sh with stubs (8e).
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
import json
import os
import re
import subprocess
import sys


def fail(check, msg):
    print(f"FAIL: check {check}: {msg}", file=sys.stderr)
    sys.exit(1)


def ok(check, msg):
    print(f"PASS: check {check}: {msg}")


# ---- Check 1: plugin.json and marketplace.json parse as JSON ----
plugin_path = ".claude-plugin/plugin.json"
marketplace_path = ".claude-plugin/marketplace.json"
codex_plugin_path = ".codex-plugin/plugin.json"
codex_marketplace_path = ".agents/plugins/marketplace.json"

for path in (plugin_path, marketplace_path, codex_plugin_path, codex_marketplace_path):
    if not os.path.isfile(path):
        fail(1, f"{path} does not exist")
    try:
        with open(path, encoding="utf-8") as f:
            json.load(f)
    except Exception as e:
        fail(1, f"{path} is not valid JSON: {e}")

with open(plugin_path, encoding="utf-8") as f:
    plugin_json = json.load(f)

with open(codex_plugin_path, encoding="utf-8") as f:
    codex_plugin_json = json.load(f)

plugin_version = plugin_json.get("version")
if not plugin_version:
    fail(1, f"{plugin_path} has no top-level 'version' field")

if codex_plugin_json.get("version") != plugin_version:
    fail(1, f"{codex_plugin_path}: version {codex_plugin_json.get('version')!r} != {plugin_path} version {plugin_version!r}")

if codex_plugin_json.get("skills") != "./skills/":
    fail(1, f"{codex_plugin_path}: skills must be './skills/'")

if "hooks" in codex_plugin_json:
    fail(1, f"{codex_plugin_path}: hooks is not accepted by the Codex plugin contract")

if not codex_plugin_json.get("interface", {}).get("defaultPrompt"):
    fail(1, f"{codex_plugin_path}: interface.defaultPrompt is required")

ok(1, "Claude and Codex plugin/marketplace manifests parse as JSON")


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


# ---- Check 2: every git-tracked agents/*.md has frontmatter that parses,
# only allowed keys, an allowed model, and at least one <example> block in
# the description.
# Uses git ls-files, not a bare glob, so an untracked file sitting in
# agents/ (e.g. a stray editor or Finder copy) cannot silently pass as an
# 8th agent. ----
agent_paths = sorted(
    subprocess.run(
        ["git", "ls-files", "--", "agents/*.md"],
        check=True, capture_output=True, text=True,
    ).stdout.split()
)
if not agent_paths:
    fail(2, "git ls-files found no tracked agents/*.md")

ALLOWED_MODELS = {"sonnet", "opus", "haiku"}
EXAMPLE_RE = re.compile(r"<example>.*?</example>", re.DOTALL)
# Every other frontmatter field is a reviewed decision, not a default. The
# camelCase omitClaudeMd must come after model:, because codex/build-agents.py
# ends the description at the next lowercase key and would swallow it there.
ALLOWED_KEYS = ("name", "description", "model", "color", "tools", "omitClaudeMd")

for path in agent_paths:
    try:
        data = parse_frontmatter(path)
    except FrontmatterError as e:
        fail(2, str(e))

    keys = list(data)
    unknown = [key for key in keys if key not in ALLOWED_KEYS]
    if unknown:
        fail(2, f"{path}: frontmatter keys {unknown!r} are not in {list(ALLOWED_KEYS)!r}")
    if "omitClaudeMd" in keys and ("model" not in keys or keys.index("omitClaudeMd") < keys.index("model")):
        fail(2, f"{path}: omitClaudeMd must come after the model: line")

    model = data.get("model")
    if model not in ALLOWED_MODELS:
        fail(2, f"{path}: model {model!r} not in {sorted(ALLOWED_MODELS)}")

    description = data.get("description", "")
    if not EXAMPLE_RE.search(description):
        fail(2, f"{path}: description has no <example>...</example> block")

ok(2, f"{len(agent_paths)} agent files have valid frontmatter with only allowed keys, an allowed model, and an <example> block")


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

# codex/SKILL.md is a reading copy no host loads: Claude Code and the Codex
# plugin both load skills/compute-squad/SKILL.md. It carries no frontmatter,
# so it cannot pass for a second skill, and states its version on a
# Version: line instead.
codex_skill_path = "codex/SKILL.md"
CODEX_SKILL_TITLE = "# Compute Squad: Codex reading copy"
if not os.path.isfile(codex_skill_path):
    fail(3, f"{codex_skill_path} does not exist")

with open(codex_skill_path, encoding="utf-8") as f:
    codex_skill = f.read()

if codex_skill.splitlines()[:1] != [CODEX_SKILL_TITLE]:
    fail(3, f"{codex_skill_path}: line 1 must be {CODEX_SKILL_TITLE!r}")
codex_versions = re.findall(r"^Version:[ \t]*(\S+)[ \t]*$", codex_skill, re.MULTILINE)
if codex_versions != [plugin_version]:
    fail(3, f"{codex_skill_path}: needs one 'Version: {plugin_version}' line; found {codex_versions!r}")

ok(3, f"{codex_skill_path} is the reading copy and its Version: line matches {plugin_path} version ({plugin_version})")


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
# Check 5: dist/compute-squad.plugin matches the git-tracked source set by
# content (not bytes; zip embeds mtimes, so a byte-diff against a fresh
# rebuild would always fail). Compared against `git ls-files`, not the live
# working tree, so untracked files (e.g. a stray editor/Finder copy sitting
# in agents/ or commands/) are correctly excluded from the comparison
# instead of being reported as drift -- they were never supposed to be
# packaged in the first place. Two sub-checks: the zip's file list must
# equal the tracked set exactly (catches missing OR extra files), and each
# tracked file's content must match its packaged copy (catches a stale
# artifact that wasn't rebuilt after a source edit).
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

tracked_list="$tmpdir/.tracked-files.txt"
zipped_list="$tmpdir/.zipped-files.txt"
git ls-files -- .claude-plugin/plugin.json skills agents commands README.md | sort > "$tracked_list"
unzip -Z1 "$plugin_zip" | grep -v '/$' | sort > "$zipped_list"

check5_failed=0
if ! diff -u "$tracked_list" "$zipped_list"; then
  echo "FAIL: check 5: $plugin_zip file list does not match the git-tracked source set (see diff above)" >&2
  check5_failed=1
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ ! -e "$f" ]; then
    echo "FAIL: check 5: working tree has no $f (tracked but missing)" >&2
    check5_failed=1
    continue
  fi
  if [ ! -e "$tmpdir/$f" ]; then
    echo "FAIL: check 5: $plugin_zip has no $f" >&2
    check5_failed=1
    continue
  fi
  if ! diff -u "$tmpdir/$f" "$f"; then
    echo "FAIL: check 5: $plugin_zip is out of sync with $f (see diff above)" >&2
    check5_failed=1
  fi
done < "$tracked_list"

if [ "$check5_failed" -ne 0 ]; then
  echo "FAIL: check 5: $plugin_zip drifted from source; rebuild with scripts/build-plugin.sh and commit" >&2
  exit 1
fi

if unzip -Z1 "$plugin_zip" | grep -q '^codex/'; then
  echo "FAIL: check 5: $plugin_zip must not contain Codex-only files" >&2
  exit 1
fi

echo "PASS: check 5: $plugin_zip matches its Claude source set and excludes codex/"

# ---------------------------------------------------------------------------
# Check 6: Codex-native files are present, generated, and routed to the
# intended model IDs, and the five manual prompts are generated from the agent
# bodies. This uses only stdlib-compatible text checks so the gate also runs
# on Python 3.9, which predates tomllib.
# ---------------------------------------------------------------------------
python3 <<'PYEOF'
import json
import pathlib
import re
import subprocess
import sys


def fail(msg):
    print(f"FAIL: check 6: {msg}", file=sys.stderr)
    sys.exit(1)


agent_models = {
    "squad-pm.toml": "gpt-5.6-sol",
    "squad-recon.toml": "gpt-5.6-terra",
    "squad-executor.toml": "gpt-5.6-terra",
    "squad-executor-haiku.toml": "gpt-5.6-luna",
    "squad-executor-opus.toml": "gpt-5.6-sol",
    "squad-helper.toml": "gpt-5.6-terra",
    "squad-mech.toml": "gpt-5.6-luna",
}
agent_dir = pathlib.Path("codex/agents")
actual = {path.name for path in agent_dir.glob("*.toml")}
if actual != set(agent_models):
    fail(f"codex/agents files are {sorted(actual)!r}, expected {sorted(agent_models)!r}")

for filename, expected_model in agent_models.items():
    text = (agent_dir / filename).read_text(encoding="utf-8")
    if f'model = "{expected_model}"' not in text:
        fail(f"{filename}: expected model {expected_model}")
    if 'developer_instructions = """' not in text:
        fail(f"{filename}: missing developer_instructions")
    if not text.rstrip().endswith('"""'):
        fail(f"{filename}: developer_instructions is not closed")

profiles = pathlib.Path("codex/profiles.toml").read_text(encoding="utf-8")
for profile, model, effort in (
    ("compute-squad", "gpt-5.6-sol", "high"),
    ("compute-squad-pm", "gpt-5.6-sol", "max"),
    ("compute-squad-execution", "gpt-5.6-terra", "max"),
    ("compute-squad-mechanical", "gpt-5.6-luna", "max"),
):
    section = re.search(r"^\[profiles\." + re.escape(profile) + r"\](.*?)(?=^\[|\Z)", profiles, re.MULTILINE | re.DOTALL)
    if not section:
        fail(f"profiles.toml: missing {profile}")
    body = section.group(1)
    if f'model = "{model}"' not in body or f'model_reasoning_effort = "{effort}"' not in body:
        fail(f"profiles.toml: {profile} has wrong model or effort")

# The manual prompts: exactly these five, each generated from its agent body
# and marked as generated on line 2. build-agents.py --check below compares
# their full text with the bodies.
with open(".claude-plugin/plugin.json", encoding="utf-8") as handle:
    version = json.load(handle)["version"]
prompt_sources = {
    "codex/01-archive.md": "squad-mech",
    "codex/02-recon.md": "squad-recon",
    "codex/03-pm-plan.md": "squad-pm",
    "codex/04-execute.md": "squad-executor",
    "codex/05-pm-accept.md": "squad-pm",
}
tracked_prompts = subprocess.run(
    ["git", "ls-files", "--", "codex/0*.md"], check=True, capture_output=True, text=True,
).stdout.split()
if sorted(tracked_prompts) != sorted(prompt_sources):
    fail(f"tracked codex/0*.md are {sorted(tracked_prompts)!r}, expected {sorted(prompt_sources)!r}")
for path, agent in prompt_sources.items():
    marker = (
        f"<!-- generated by codex/build-agents.py from agents/{agent}.md, "
        f"compute-squad {version}; do not edit -->"
    )
    lines = pathlib.Path(path).read_text(encoding="utf-8").splitlines()
    if lines[1:2] != [marker]:
        fail(f"{path}: line 2 must be the generated-file marker {marker!r}")

if subprocess.run([sys.executable, "codex/build-agents.py", "--check"], stdout=subprocess.DEVNULL).returncode != 0:
    fail("codex/build-agents.py --check failed")

with open(".codex-plugin/plugin.json", encoding="utf-8") as handle:
    manifest = json.load(handle)
if manifest.get("skills") != "./skills/":
    fail(".codex-plugin/plugin.json does not point at ./skills/")

print("PASS: check 6: Codex agents, manual prompts, profiles, routing, and generator sync are valid")
PYEOF

# ---------------------------------------------------------------------------
# Check 7: cross-file verbatim-block and shared-fact diffs. Rank 7 of the
# 2026-08-17 documentation audit found the protocol restated as independent
# full prose in up to four files, and one of the smallest, simplest blocks
# (the BLOCKER grammar) had already silently drifted. Consolidation moved
# the full prose retellings into skills/compute-squad/SKILL.md, the one skill
# both hosts load (codex/SKILL.md is a reading copy for people); this check
# protects the blocks and facts that must still read identically in more
# than one file, so the next drift fails CI instead of shipping.
# It cannot catch prose that differs in wording while agreeing on the
# underlying fact. Text repeated across agent bodies is pinned by the
# shared-span table below, one row per span.
# ---------------------------------------------------------------------------
python3 <<'PYEOF'
import json
import re
import subprocess
import sys


def fail(msg):
    print(f"FAIL: check 7: {msg}", file=sys.stderr)
    sys.exit(1)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def extract_fenced_block(text, path, opening_line, next_line, closing_line="```"):
    """Return the lines from next_line (inclusive) up to the next
    closing_line, where next_line must immediately follow a line matching
    opening_line. Raises if no such delimiter pair is found."""
    lines = text.splitlines()
    start = None
    for i in range(len(lines) - 1):
        if lines[i] == opening_line and lines[i + 1] == next_line:
            start = i
            break
    if start is None:
        fail(f"{path}: no {opening_line!r} line immediately followed by {next_line!r}")
    end = None
    for i in range(start + 2, len(lines)):
        if lines[i] == closing_line:
            end = i
            break
    if end is None:
        fail(f"{path}: no closing {closing_line!r} found after line {start + 1}")
    return lines[start + 1:end]


def extract_section(text, path, heading):
    """Return the lines from a '## heading' line up to (not including) the
    next line starting with '## ', or end of file."""
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip() == heading:
            start = i
            break
    if start is None:
        fail(f"{path}: no heading {heading!r}")
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].startswith("## "):
            end = i
            break
    return lines[start:end]


def tracked_files(*pathspecs):
    out = subprocess.run(
        ["git", "ls-files", "-z", "--", *pathspecs],
        check=True, capture_output=True, text=True,
    ).stdout
    return [p for p in out.split("\0") if p]


# ---- 7a: the Goal — Locked template is byte-identical in all three files
# that carry it.
goal_locked_paths = [
    "skills/compute-squad/SKILL.md",
    "codex/SKILL.md",
    "codex/README.md",
]
goal_locked_blocks = {}
for path in goal_locked_paths:
    text = read(path)
    goal_locked_blocks[path] = extract_fenced_block(text, path, "```markdown", "## Goal — Locked")

ref_path, ref_block = next(iter(goal_locked_blocks.items()))
for path, block in goal_locked_blocks.items():
    if block != ref_block:
        fail(f"{path}: Goal — Locked template differs from {ref_path}")

print(f"PASS: check 7: Goal — Locked template is byte-identical across {', '.join(goal_locked_paths)}")

# ---- 7b: the BLOCKER grammar's fenced wire-format block is byte-identical
# in both SKILL.md files.
blocker_paths = ["skills/compute-squad/SKILL.md", "codex/SKILL.md"]
blocker_blocks = {}
for path in blocker_paths:
    text = read(path)
    blocker_blocks[path] = extract_fenced_block(text, path, "```", "BLOCKER:")

ref_path, ref_block = next(iter(blocker_blocks.items()))
for path, block in blocker_blocks.items():
    if block != ref_block:
        fail(f"{path}: BLOCKER grammar block differs from {ref_path}")

print(f"PASS: check 7: BLOCKER grammar block is byte-identical across {', '.join(blocker_paths)}")

# ---- 7c: the "5 helpers per stage per run" cap names the same digit
# everywhere it's restated: the shared skill, the reading copy, the README,
# and each stage body that can delegate.
cap_paths = [
    "skills/compute-squad/SKILL.md",
    "codex/SKILL.md",
    "README.md",
    "agents/squad-recon.md",
    "agents/squad-pm.md",
    "agents/squad-executor.md",
    "agents/squad-executor-haiku.md",
    "agents/squad-executor-opus.md",
]
cap_re = re.compile(r"5[^0-9]{0,20}per\s+stage\s+per\s+run")
for path in cap_paths:
    if not cap_re.search(read(path)):
        fail(f"{path}: no '5 ... per stage per run' helper-cap phrase found")

print(f"PASS: check 7: the 5-helper-per-stage-per-run cap reads '5' in {', '.join(cap_paths)}")

# ---- 7d: the routing block. skills/compute-squad/SKILL.md names models only
# between one "<!-- routing:begin -->" line and one "<!-- routing:end -->"
# line (7l bans model names everywhere else in protocol text). The block must
# name, in backticks, every model an agent file pins: each agents/*.md
# `model:` alias and each codex/agents/*.toml `model` ID. codex/SKILL.md, a
# reading copy with no markers yet, still names every pinned Codex ID in its
# Model routing section.
ROUTING_BEGIN = "<!-- routing:begin -->"
ROUTING_END = "<!-- routing:end -->"
routing_block_paths = ["skills/compute-squad/SKILL.md"]


def routing_block_span(path, lines):
    """Return the (begin, end) line indexes of the one routing block in lines."""
    begins = [i for i, line in enumerate(lines) if ROUTING_BEGIN in line]
    ends = [i for i, line in enumerate(lines) if ROUTING_END in line]
    if len(begins) != 1 or len(ends) != 1:
        fail(
            f"{path}: needs exactly one {ROUTING_BEGIN!r} line and one {ROUTING_END!r} line; "
            f"found {len(begins)} and {len(ends)}"
        )
    begin, end = begins[0], ends[0]
    if lines[begin] != ROUTING_BEGIN or lines[end] != ROUTING_END or end <= begin + 1:
        fail(f"{path}: each routing marker must stand alone on its line, with the block between begin and end")
    return begin, end


pinned_models = set()
for path in tracked_files("agents/*.md"):
    frontmatter = read(path).split("\n---\n", 1)[0]
    match = re.search(r"^model:[ \t]*(\S+)[ \t]*$", frontmatter, re.MULTILINE)
    if not match:
        fail(f"{path}: no model: line in the frontmatter")
    pinned_models.add(match.group(1))
pinned_codex_models = set()
for path in tracked_files("codex/agents/*.toml"):
    match = re.search(r'^model = "([^"]+)"$', read(path), re.MULTILINE)
    if not match:
        fail(f"{path}: no model line")
    pinned_codex_models.add(match.group(1))
if not pinned_models or not pinned_codex_models:
    fail("found no agent files to read pinned models from")
pinned_models |= pinned_codex_models

for path in routing_block_paths:
    lines = read(path).splitlines()
    begin, end = routing_block_span(path, lines)
    block = "\n".join(lines[begin + 1:end])
    for model in sorted(pinned_models):
        if f"`{model}`" not in block:
            fail(f"{path}: the routing block does not name `{model}`, which an agent file pins")

codex_routing_path = "codex/SKILL.md"
codex_routing = "\n".join(extract_section(read(codex_routing_path), codex_routing_path, "## Model routing"))
for model in sorted(pinned_codex_models):
    if f"`{model}`" not in codex_routing:
        fail(f"{codex_routing_path}: the Model routing section does not name `{model}`, which a Codex agent pins")

print(
    f"PASS: check 7: {', '.join(routing_block_paths)} has one routing block naming every pinned model "
    f"({', '.join(sorted(pinned_models))}), and {codex_routing_path} names every pinned Codex model"
)

# ---- 7e: the product description is one canonical string across every
# manifest that carries one, and short enough to also serve as the GitHub
# repository About text. GitHub rejects a description over 350 characters
# (HTTP 422), so a canonical string longer than that could not be used on
# every surface, and the surfaces would silently diverge again. The GitHub
# About text itself lives outside this repository and cannot be checked here.
description_fields = {
    ".claude-plugin/plugin.json": lambda d: d["description"],
    ".codex-plugin/plugin.json": lambda d: d["description"],
    ".claude-plugin/marketplace.json": lambda d: d["plugins"][0]["description"],
}
GITHUB_DESCRIPTION_MAX = 350
descriptions = {}
for path, pick in description_fields.items():
    try:
        descriptions[path] = pick(json.loads(read(path)))
    except (KeyError, IndexError):
        fail(f"{path}: no product description field found where one is required")

distinct = set(descriptions.values())
if len(distinct) != 1:
    detail = "; ".join(f"{p} = {d!r}" for p, d in descriptions.items())
    fail(f"product description differs across manifests: {detail}")

canonical = distinct.pop()
if len(canonical) > GITHUB_DESCRIPTION_MAX:
    fail(
        f"product description is {len(canonical)} characters; GitHub rejects an About "
        f"text over {GITHUB_DESCRIPTION_MAX}, so this string cannot be used on every surface"
    )

print(
    f"PASS: check 7: product description is identical across "
    f"{', '.join(description_fields)} and fits GitHub's About field "
    f"({len(canonical)}/{GITHUB_DESCRIPTION_MAX} chars)"
)


# ---- 7i: the closed heading list. SKILL.md's Hard rules carry the one list
# of log headings and name the headings that may add " (cont.)". Every
# heading the protocol writes or names must be on it: each "## " line inside
# a fenced block (the log templates) and each backticked "## " span, in every
# tracked Markdown file except the history files, tests/, and the example
# log's entries (the log linter reads those). A placeholder such as
# <your stage> matches the list's <stage>. Each listed heading, and each
# "(cont.)" form, must also be written or named verbatim in the agent bodies,
# the Codex prompts, or SKILL.md outside the list, so a typo in the list
# fails too.
HEADING_BULLET = "- Log entries use only these headings: "
HEADING_BAN = "Any other heading or suffix is a protocol violation."
CONT = " (cont.)"
skill_path = "skills/compute-squad/SKILL.md"
skill_lines = read(skill_path).splitlines()
bullet_at = [i for i, line in enumerate(skill_lines) if line.startswith(HEADING_BULLET)]
if len(bullet_at) != 1:
    fail(f"{skill_path}: needs exactly one Hard-rules bullet starting {HEADING_BULLET!r}; found {len(bullet_at)}")
bullet_at = bullet_at[0]
section_at = max((i for i in range(bullet_at) if skill_lines[i].startswith("## ")), default=None)
if section_at is None or skill_lines[section_at] != "## Hard rules":
    fail(f"{skill_path}: the heading-list bullet must sit under ## Hard rules")
rest = skill_lines[bullet_at][len(HEADING_BULLET):]
list_part, sep, after = rest.partition(". Only ")
cont_part, sep2, tail = after.partition(" may add `" + CONT + "`")
if not sep or not sep2 or tail != ". " + HEADING_BAN:
    fail(
        f"{skill_path}: the heading-list bullet must read {HEADING_BULLET!r}<headings>. Only <headings> "
        f"may add `{CONT}`. {HEADING_BAN}"
    )


def backticked_headings(part, what):
    items = re.findall(r"`(## [^`]+)`", part)
    shape = re.sub(r"`## [^`]+`", "H", part)
    if not items or not re.fullmatch(r"H(?:, H)*(?:,? and H)?", shape):
        fail(f"{skill_path}: the heading-list bullet's {what} must be backticked `## ` headings separated by commas")
    if len(set(items)) != len(items):
        fail(f"{skill_path}: the heading-list bullet repeats a heading in its {what}")
    return items


listed_headings = backticked_headings(list_part, "list")
cont_headings = backticked_headings(cont_part, "(cont.) list")
for heading in cont_headings:
    if heading not in listed_headings:
        fail(f"{skill_path}: {heading!r} may add (cont.) but is not on the heading list")


def placeholder_pattern(heading):
    return re.compile("".join(
        r"<[^<>]+>" if part.startswith("<") else re.escape(part)
        for part in re.split(r"(<[^<>]+>)", heading)
    ))


listed_patterns = [placeholder_pattern(h) for h in listed_headings]
GENERIC_CONT = re.compile(r"## <[^<>]+> \(cont\.\)")


def heading_on_list(heading):
    if any(p.fullmatch(heading) for p in listed_patterns):
        return True
    if heading.endswith(CONT) and heading[:-len(CONT)] in cont_headings:
        return True
    return bool(GENERIC_CONT.fullmatch(heading))


def heading_mentions(path, fenced):
    """Yield (line number, heading) for each '## ' line inside a fenced block
    (when fenced is true) and each backticked '## ' span."""
    inside = False
    for number, line in enumerate(read(path).splitlines(), 1):
        if path == skill_path and number == bullet_at + 1:
            continue
        if line.startswith("```"):
            if not inside:
                inside = True
            elif line.strip() == "```":
                inside = False
            continue
        if inside and fenced and line.startswith("## "):
            yield number, line
        for match in re.finditer(r"`(## [^`\n]+)`", line):
            yield number, match.group(1)


off_list = []
for path in tracked_files("*.md"):
    if path in ("CHANGELOG.md", "LEFTOVER_FINDINGS.md") or path.startswith("tests/"):
        continue
    for number, heading in heading_mentions(path, fenced=path != "docs/example-log.md"):
        if not heading_on_list(heading):
            off_list.append(f"{path}:{number}: {heading}")
if off_list:
    fail(f"headings not on the list in {skill_path}'s Hard rules: " + "; ".join(off_list))

runtime_mentions = set()
for path in [skill_path] + tracked_files("agents/*.md", "codex/0*.md"):
    runtime_mentions.update(heading for _, heading in heading_mentions(path, fenced=True))
for heading in listed_headings + [h + CONT for h in cont_headings]:
    if heading not in runtime_mentions:
        fail(f"{skill_path}: listed heading {heading!r} is written or named nowhere in agents/, codex/0*.md, or {skill_path}")

print(
    f"PASS: check 7: every log heading the protocol writes or names is on {skill_path}'s closed list "
    f"({len(listed_headings)} headings, {len(cont_headings)} with (cont.))"
)

# ---- 7j: the archive command. Every archive copy is written by the one
# command in SKILL.md's Hard rules: a noclobber copy named from date -u and
# the run ID, verified with cmp, with the clear chained after cmp. The block
# right after that rule is the canonical copy. In every file that runs it,
# the ```bash blocks that name compute-squad-archive must be exactly the
# expected forms: the plain command, or the PM's form (the prefix the rule
# names, then the second line), preceded on a high-stakes PASS by the PM's
# form that ends with the echo the rule names in place of the clear. The
# read-back and whole-file Write wording it replaced must not come back.
skill_path = "skills/compute-squad/SKILL.md"
skill_text = read(skill_path)
skill_lines = skill_text.splitlines()
archive_rule = "- Every archive copy is written by this command and nothing else"
idx = next((i for i, line in enumerate(skill_lines) if line.startswith(archive_rule)), None)
if idx is None:
    fail(f"{skill_path}: no Hard-rules bullet starting {archive_rule!r}")
j = idx + 1
while j < len(skill_lines) and skill_lines[j] == "":
    j += 1
if skill_lines[j:j + 1] != ["```bash"] or skill_lines[j + 3:j + 4] != ["```"]:
    fail(f"{skill_path}: the archive command must be a two-line ```bash block right after the archive rule")
archive_first, archive_second = skill_lines[j + 1], skill_lines[j + 2]
if not archive_first.startswith("run=$(") or not archive_second.startswith("mkdir -p "):
    fail(f"{skill_path}: the archive block must start with 'run=$(' and its second line with 'mkdir -p '")
prefix_match = re.search(r"The PM's form inserts `([^`]+)` at the start of the second line", skill_lines[idx])
if not prefix_match:
    fail(f"{skill_path}: the archive rule no longer names the PM's prefix")
plain_form = [archive_first, archive_second]
pm_form = [archive_first, prefix_match.group(1) + archive_second]
pm_forms = [pm_form]
kept_match = re.search(r"on a high-stakes PASS it also ends with `([^`]+)` in place of the clear", skill_lines[idx])
if kept_match:
    clear_at = archive_second.find(" && : > COMPUTE_SQUAD_LOG.md")
    if clear_at < 0:
        fail(f"{skill_path}: the archive command no longer clears the log with ': > COMPUTE_SQUAD_LOG.md'")
    kept_second = prefix_match.group(1) + archive_second[:clear_at] + " && " + kept_match.group(1)
    pm_forms = [[archive_first, kept_second], pm_form]


def archive_blocks(text):
    """Return every ```bash block that names compute-squad-archive, as lists of lines."""
    blocks, current = [], None
    for line in text.splitlines():
        if current is None:
            if line == "```bash":
                current = []
        elif line == "```":
            if any("compute-squad-archive" in l for l in current):
                blocks.append(current)
            current = None
        else:
            current.append(line)
    return blocks


archive_files = {
    skill_path: [plain_form],
    "agents/squad-mech.md": [plain_form],
    "codex/01-archive.md": [plain_form],
    "codex/agents/squad-mech.toml": [plain_form],
    "agents/squad-pm.md": pm_forms,
    "codex/05-pm-accept.md": pm_forms,
    "codex/agents/squad-pm.toml": pm_forms,
}
for path, expected in archive_files.items():
    found = archive_blocks(read(path))
    if found != expected:
        fail(
            f"{path}: archive command blocks differ from the forms {skill_path}'s Hard rules define; "
            f"expected {expected!r}, found {found!r}"
        )

# Matched in lowercased text across line breaks, with or without backticks.
retired_archive_phrases = (
    ("read the copy back", re.compile(r"read\s+the\s+copy\s+back")),
    ("cp COMPUTE_SQUAD_LOG.md", re.compile(r"cp\s+compute_squad_log\.md")),
    ("whole-file Write", re.compile(r"whole[-\s]file\s+`?write\b")),
)
for path in tracked_files("skills", "agents", "codex", "docs"):
    lowered = read(path).lower()
    for phrase, pattern in retired_archive_phrases:
        if pattern.search(lowered):
            fail(f"{path}: contains retired archive wording {phrase!r}; archive only with the command in {skill_path}")

print(
    f"PASS: check 7: the archive command matches {skill_path} in {', '.join(archive_files)}, "
    f"and no read-back or whole-file Write wording remains"
)

# ---- 7l: protocol text names rungs (top, mid, bottom), never models. The
# agent bodies, the shared skill and its references, commands/squad.md, the
# Codex prompts, and the example log must not contain a capitalized model
# family name, a gpt- model ID, a price pair such as $4/$20, or a price ratio
# such as 1.67x, except inside the routing block that 7d checks. Agent names
# such as squad-executor-haiku are lowercase, so they pass.
MODEL_NAME_PATTERNS = (
    ("a model name", re.compile(r"\b(?:Opus|Sonnet|Haiku|Fable|Astra|Sol|Terra|Luna)\b")),
    ("a model ID", re.compile(r"gpt-[0-9]")),
    ("a price", re.compile(r"\$[0-9][0-9.,]*/\$[0-9]")),
    ("a price ratio", re.compile(r"\b[0-9]+(?:\.[0-9]+)?x\b")),
)
protocol_paths = sorted(set(tracked_files(
    "agents/*.md",
    "skills/compute-squad/SKILL.md",
    "skills/compute-squad/references/*.md",
    "commands/squad.md",
    "codex/0*.md",
    "docs/example-log.md",
)))
for required in ("skills/compute-squad/SKILL.md", "commands/squad.md", "docs/example-log.md"):
    if required not in protocol_paths:
        fail(f"{required} is not tracked, so check 7l cannot read it")
if not any(p.startswith("agents/") for p in protocol_paths) or not any(p.startswith("codex/0") for p in protocol_paths):
    fail("check 7l found no tracked agents/*.md or codex/0*.md")

model_mentions = []
for path in protocol_paths:
    lines = read(path).splitlines()
    skip = range(0)
    if path in routing_block_paths:
        begin, end = routing_block_span(path, lines)
        skip = range(begin, end + 1)
    for index, line in enumerate(lines):
        if index in skip:
            continue
        if ROUTING_BEGIN in line or ROUTING_END in line:
            model_mentions.append(f"{path}:{index + 1}: routing marker outside {', '.join(routing_block_paths)}")
            continue
        for what, pattern in MODEL_NAME_PATTERNS:
            for match in pattern.finditer(line):
                model_mentions.append(f"{path}:{index + 1}: {what} {match.group(0)!r}")
if model_mentions:
    fail("protocol text names models outside the routing block; name the rung (top, mid, bottom) instead: " + "; ".join(model_mentions))

print(f"PASS: check 7: protocol text names rungs, not models, outside the routing block ({len(protocol_paths)} files)")

# ---- 7o: the routing-rules reference file under skills/compute-squad/
# references/ was deleted in 3.11.0, and its one unique rule moved into
# SKILL.md. No tracked file names it except the history files. The name is
# assembled so this script does not match itself.
deleted_reference = "routing-rules" + ".md"
for path in tracked_files():
    if path in ("CHANGELOG.md", "LEFTOVER_FINDINGS.md"):
        continue
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except (FileNotFoundError, IsADirectoryError):
        continue
    if deleted_reference.encode() in data:
        fail(f"{path}: names the deleted {deleted_reference}")

print(f"PASS: check 7: no tracked file outside CHANGELOG.md and LEFTOVER_FINDINGS.md names {deleted_reference}")

# ---- 7p: the shared-span table. A rule a stage must obey stays inline in
# that stage's own agent body on both hosts (a run-time include would not
# expand in Codex), so text that must read identically in several files is
# pinned here, one row per span. A row either cuts its span from a canonical
# copy, from a start anchor through an end anchor, or gives the span's exact
# text; every listed file must contain the span byte for byte. A mask stands
# for the text between its two strings, in the span and in every file, where
# each stage names its own heading. A canonical span must also contain the
# row's required strings. The self-test after the table changes one
# character at three places in each file's copy of each span and fails if
# the row does not catch it, so a loose row cannot pass drift.
BODIES = [
    "agents/squad-recon.md",
    "agents/squad-pm.md",
    "agents/squad-executor.md",
    "agents/squad-executor-haiku.md",
    "agents/squad-executor-opus.md",
]
EXECUTOR_BODIES = BODIES[2:]
PM_FILES = ["agents/squad-pm.md", "codex/05-pm-accept.md"]
CODEX_STAGE_PROMPTS = ["codex/02-recon.md", "codex/03-pm-plan.md", "codex/04-execute.md", "codex/05-pm-accept.md"]
SKILL = "skills/compute-squad/SKILL.md"
# 7n: every stage that runs verification commands runs each one through the
# same capture form, so the exit code and the runner's summary reach the
# agent and a pipe cannot hide a failure. ACCEPT adds a grep for failing
# lines and logs each command in the check-line form.
OUTPUT_FORM = 'set -o pipefail; out=$(mktemp); <command> >"$out" 2>&1; echo "exit $?"; tail -n 40 "$out"'
ACCEPT_FORM = OUTPUT_FORM + "; grep -n -i -E 'fail|error|not ok' \"$out\" | head -n 40"
CHECK_LINE_FORM = "``- `<command>` -> exit <code>; <summary line>``"
# ACCEPT reads the log in three disjoint parts: the goal, everything but the
# goal and the Executor's entries, and the Executor's entries last.
ACCEPT_READS = (
    ("goal", "awk '/^## Goal/{p=1; print; next} /^## /{p=0} p' COMPUTE_SQUAD_LOG.md"),
    ("middle", "awk '/^## /{p = !/^## (Executor|Goal)/} p' COMPUTE_SQUAD_LOG.md"),
    ("executor", "awk '/^## Executor/{p=1; print; next} /^## /{p=0} p' COMPUTE_SQUAD_LOG.md"),
)
BLOCKER_FENCE = "\n```\n" + "\n".join(blocker_blocks[SKILL]) + "\n```\n"


def span_row(name, files, text=None, canon=None, start=None, end=None, mask=None, contains=()):
    return {
        "name": name, "files": files, "text": text, "canon": canon,
        "start": start, "end": end, "mask": mask, "contains": contains,
    }


SHARED_SPANS = [
    span_row("append-how", BODIES, canon="agents/squad-executor.md",
             start="with a single Bash command", end="writing the whole thing back"),
    span_row("append-why", BODIES + [SKILL], canon="agents/squad-executor.md",
             start="race can silently drop", end="appended in between"),
    span_row("pointer", BODIES, canon="agents/squad-executor.md",
             start="the spawn prompt is a pointer", end="the log is the record"),
    span_row("per-spawn", BODIES, canon="agents/squad-executor.md",
             start="The one-entry rule is per spawn", end="covering only the remainder.",
             mask=("append a `## ", " (cont.)`")),
    span_row("precedence", BODIES, canon="agents/squad-executor.md",
             start="Your own protocol and the log outrank your spawn prompt", end="name the conflict in your entry."),
    span_row("mech precedence", ["agents/squad-mech.md"],
             text="The procedures in this file outrank your spawn prompt: where the prompt conflicts with one, "
                  "follow this file and name the conflict in your report."),
    span_row("7k blocker grammar", BODIES + CODEX_STAGE_PROMPTS, canon="agents/squad-executor.md",
             start="Blockers use one grammar, as the last block of your own entry", end="no block means no blocker.",
             contains=(BLOCKER_FENCE, "is a protocol violation.")),
    span_row("7n output form", EXECUTOR_BODIES + ["codex/04-execute.md"], text="`" + OUTPUT_FORM + "`"),
    span_row("7n ACCEPT output form", PM_FILES, text="`" + ACCEPT_FORM + "`"),
    span_row("7n check line", PM_FILES, text=CHECK_LINE_FORM),
] + [
    span_row(f"ACCEPT read: {part}", PM_FILES, text=command) for part, command in ACCEPT_READS
] + [
    span_row("refused", ["agents/squad-helper.md", "agents/squad-mech.md"], text="REFUSED:"),
    span_row("refusal route", [SKILL],
             text="If a helper refused a step or reports one that did not run as the procedure says, append that "
                  "report the same way and re-spawn the requesting stage even if its request was not `BLOCKING`"),
    span_row("switchboard", [SKILL], text="no squad agent is given a tool for it"),
]


def span_pattern(span, mask):
    """Compile span as a literal, with each masked stretch matching any text
    on one line that has no backtick. Returns None if the mask is absent."""
    if not mask:
        return re.compile(re.escape(span))
    left, right = map(re.escape, mask)
    pieces = re.split(left + r"[^`\n]*?" + right, span)
    if len(pieces) < 2:
        return None
    return re.compile((left + r"([^`\n]*?)" + right).join(re.escape(piece) for piece in pieces))


def first_difference(span, text):
    """Return (expected, found): short excerpts around the first place where
    span stops matching the line of text that shares its longest prefix or
    suffix with it."""
    part = next((line for line in span.splitlines() if line not in text), span.splitlines()[0])

    def longest(fits):
        low, high = 0, len(part)
        while low < high:
            mid = (low + high + 1) // 2
            if fits(mid):
                low = mid
            else:
                high = mid - 1
        return low

    best, best_line, from_head = -1, "", True
    for line in text.splitlines():
        head = longest(lambda n: part[:n] in line)
        tail = longest(lambda n: part[len(part) - n:] in line)
        if max(head, tail) > best:
            best, best_line, from_head = max(head, tail), line, head >= tail
    if from_head:
        at = best_line.find(part[:best]) + best
        return part[max(0, best - 30):best + 30], best_line[max(0, at - 30):at + 30]
    cut = len(part) - best
    at = best_line.find(part[cut:])
    return part[max(0, cut - 30):cut + 30], best_line[max(0, at - 30):at + 30]


def check_span_row(row, texts, diagnose=True):
    """Return (errors, compiled pattern or None) for one row against texts."""
    if row["canon"]:
        canon_text = texts[row["canon"]]
        begin = canon_text.find(row["start"])
        finish = canon_text.find(row["end"], begin + len(row["start"])) if begin >= 0 else -1
        if begin < 0 or finish < 0:
            return [f"{row['canon']}: no span from {row['start']!r} to {row['end']!r}"], None
        span = canon_text[begin:finish + len(row["end"])]
        for needed in row["contains"]:
            if needed not in span:
                return [f"{row['canon']}: the span no longer contains {needed!r}"], None
        source = row["canon"]
    else:
        span = row["text"]
        source = "the text pinned in scripts/verify.sh"
    pattern = span_pattern(span, row["mask"])
    if pattern is None:
        return [f"{row['canon']}: the span no longer contains the mask {row['mask']!r}"], None
    errors = []
    for path in row["files"]:
        if pattern.search(texts[path]):
            continue
        if not diagnose:
            errors.append(path)
            continue
        expected, found = first_difference(span, texts[path])
        errors.append(f"{path}: differs from {source}; expected ...{expected!r}..., closest here ...{found!r}...")
    return errors, pattern


def row_paths(row):
    return list(dict.fromkeys(([row["canon"]] if row["canon"] else []) + row["files"]))


span_texts = {path: read(path) for row in SHARED_SPANS for path in row_paths(row)}
for row in SHARED_SPANS:
    errors, _ = check_span_row(row, span_texts)
    if errors:
        fail(f"shared-span row {row['name']!r}: " + "; ".join(errors))

for row in SHARED_SPANS:
    _, pattern = check_span_row(row, span_texts)
    for path in row_paths(row):
        text = span_texts[path]
        match = pattern.search(text)
        masked = [range(match.start(g), match.end(g)) for g in range(1, pattern.groups + 1)]
        fixed = [i for i in range(match.start(), match.end()) if not any(i in hole for hole in masked)]
        for offset in (fixed[0], fixed[len(fixed) // 2], fixed[-1]):
            swapped = "#" if text[offset] != "#" else "@"
            mutated = dict(span_texts)
            mutated[path] = text[:offset] + swapped + text[offset + 1:]
            if not check_span_row(row, mutated, diagnose=False)[0]:
                fail(
                    f"shared-span row {row['name']!r} does not catch a one-character change in {path} "
                    f"at offset {offset}; tighten the row"
                )

print(
    f"PASS: check 7: the shared-span table's {len(SHARED_SPANS)} rows read identically in every listed file, "
    f"and each fails on a one-character change: "
    + ", ".join(
        f"{row['name']} ({len(row_paths(row))} file{'s' if len(row_paths(row)) > 1 else ''})" for row in SHARED_SPANS
    )
)

# ---- 7q: agent descriptions stay small. The main session carries every
# agent description on every call of every session the plugin is enabled
# in, squad or not. Each is at most 500 UTF-8 bytes, has no <commentary>
# block, and sends the reader to the compute-squad skill.
DESCRIPTION_MAX = 500
description_problems = []
for path in tracked_files("agents/*.md"):
    text = read(path)
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        fail(f"{path}: no frontmatter")
    frontmatter = text[4:text.index("\n---\n", 4)].split("\n")
    at = next((i for i, line in enumerate(frontmatter) if line.startswith("description:")), None)
    if at is None:
        fail(f"{path}: no description in the frontmatter")
    block = []
    for line in frontmatter[at + 1:]:
        if line.strip() and not line.startswith(" "):
            break
        block.append(line)
    indent = min((len(line) - len(line.lstrip(" ")) for line in block if line.strip()), default=0)
    inline = frontmatter[at][len("description:"):].strip()
    description = "\n".join(line[indent:] for line in block).rstrip("\n")
    if inline not in ("|", ">", "|-", ">-", "|+", ">+"):
        description = (inline + "\n" + description).strip("\n")
    size = len(description.encode("utf-8"))
    if size > DESCRIPTION_MAX:
        description_problems.append(f"{path}: description is {size} bytes, over {DESCRIPTION_MAX}")
    if "<commentary>" in description:
        description_problems.append(f"{path}: description has a <commentary> block")
    if "compute-squad skill" not in description:
        description_problems.append(f"{path}: description does not name the compute-squad skill")
if description_problems:
    fail("; ".join(description_problems))

print(f"PASS: check 7: every agent description is at most {DESCRIPTION_MAX} bytes, has no <commentary>, and names the compute-squad skill")

# ---- 7r: stages do not spawn agents. The orchestrating session is the
# switchboard, so no agent file lists a tool that spawns agents (Agent, or
# its older name Task). Each must list its tools on one tools: line, since an
# agent with no tools: line gets every tool. The SKILL.md sentence that says
# so is the "switchboard" row of 7p.
SPAWN_TOOLS = ("Agent", "Task")
for path in tracked_files("agents/*.md"):
    frontmatter = read(path).split("\n---\n", 1)[0]
    match = re.search(r"^tools:[ \t]*\[(.*)\][ \t]*$", frontmatter, re.MULTILINE)
    if not match:
        fail(f"{path}: needs a one-line tools: [...] list; an agent without one gets every tool")
    named = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", match.group(1))
    spawning = [tool for tool in named if tool in SPAWN_TOOLS]
    if spawning:
        fail(f"{path}: tools: lists {spawning!r}; stages never spawn agents, the orchestrating session does")

print(f"PASS: check 7: no agent file lists a tool that spawns agents ({', '.join(SPAWN_TOOLS)})")

# ---- 7s: codex/SKILL.md stays a reading copy. Codex loads skills only from
# the manifest's ./skills/ root, so frontmatter on a SKILL.md elsewhere would
# only make it look like a second, never-loaded skill. Both SKILL.md files
# carry the rule that the orchestrating session never does a stage's work.
NO_ABSORPTION = "never does a stage's work"
for path in tracked_files():
    if path.rsplit("/", 1)[-1] == "SKILL.md" and not path.startswith("skills/"):
        if read(path).startswith("---"):
            fail(f"{path}: a SKILL.md outside skills/ must not open with frontmatter; no host loads it")
for path in (SKILL, "codex/SKILL.md"):
    if NO_ABSORPTION not in " ".join(read(path).split()):
        fail(f"{path}: missing the no-absorption rule ({NO_ABSORPTION!r})")

print(f"PASS: check 7: no SKILL.md outside skills/ has frontmatter, and both SKILL.md files say the orchestrating session {NO_ABSORPTION}")
PYEOF

# ---------------------------------------------------------------------------
# Check 8: behavior without a model. Checks 1 to 7 compare text; this check
# runs the protocol's own grammar and scripts on fixtures, so a change that
# keeps every copy in sync but breaks behavior still fails CI. Everything
# runs in temp dirs; nothing here writes into the repo.
# ---------------------------------------------------------------------------
python3 <<'PYEOF'
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile


def fail(msg):
    print(f"FAIL: check 8: {msg}", file=sys.stderr)
    sys.exit(1)


def tracked_files(*pathspecs):
    out = subprocess.run(
        ["git", "ls-files", "-z", "--", *pathspecs],
        check=True, capture_output=True, text=True,
    ).stdout
    return [p for p in out.split("\0") if p]


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


# ---- 8a: log grammar. tests/check_logs.py reads the heading list, the
# opening entry, the timestamp form and the BLOCKER grammar from
# skills/compute-squad/SKILL.md and lints a log against them. The example
# log must lint clean. Each fixture tests/fixtures/logs/<name>.log.md has a
# <name>.expect.json that cites the protocol text it tests (each cited text
# must still be in the cited file) and says whether the linter passes it or
# which rules it fails. Every negative fixture must fail with exactly its
# rules, and every linter rule needs at least one negative fixture.
LINTER = "tests/check_logs.py"
FIXTURES = "tests/fixtures/logs/"
INVENTED = FIXTURES + "invented-heading.log.md"


def run_linter(*args):
    return subprocess.run([sys.executable, LINTER, *args], capture_output=True, text=True)


def fired_rules(output):
    return set(re.findall(r"^.+?:\d+: \[([a-z-]+)\] ", output, re.MULTILINE))


def collapse(text):
    return " ".join(text.split())


listed = run_linter("--rules")
if listed.returncode != 0:
    fail(f"{LINTER} --rules exited {listed.returncode}: {listed.stderr.strip()}")
linter_rules = [line.split("\t", 1)[0] for line in listed.stdout.splitlines() if line.strip()]

example = run_linter("--fenced", "docs/example-log.md")
if example.returncode != 0:
    fail(f"docs/example-log.md does not lint clean:\n{example.stdout}{example.stderr}")

tracked = tracked_files(FIXTURES)
tracked_set = set(tracked_files())
logs = sorted(p for p in tracked if p.endswith(".log.md"))
expects = sorted(p for p in tracked if p.endswith(".expect.json"))
strays = sorted(set(tracked) - set(logs) - set(expects))
if strays:
    fail(f"{FIXTURES} holds only <name>.log.md and <name>.expect.json files; found {strays!r}")
unpaired = sorted(
    {p[:-len(".log.md")] for p in logs} ^ {p[:-len(".expect.json")] for p in expects}
)
if unpaired:
    fail(f"each fixture log needs its .expect.json and each .expect.json its log; unpaired: {unpaired!r}")

passing, failing, covered = [], [], set()
for log in logs:
    expect_path = log[:-len(".log.md")] + ".expect.json"
    try:
        expect = json.loads(read(expect_path))
        cites = expect["cites"]
        result = expect["lint"]["result"]
        rules = expect["lint"]["rules"]
    except (ValueError, KeyError, TypeError) as e:
        fail(f"{expect_path}: needs 'cites' and 'lint': {{'result', 'rules'}}: {e}")
    if not cites or not isinstance(cites, list):
        fail(f"{expect_path}: cites no protocol line")
    for cite in cites:
        if not isinstance(cite, dict) or cite.get("file") not in tracked_set or not cite.get("text"):
            fail(f"{expect_path}: each cite needs a tracked 'file' and the 'text' it quotes; got {cite!r}")
        if collapse(cite["text"]) not in collapse(read(cite["file"])):
            fail(f"{expect_path}: {cite['file']} no longer contains the cited text {cite['text']!r}; update the fixture with the protocol")
    unknown = [r for r in rules if r not in linter_rules]
    if result not in ("pass", "fail") or unknown or (result == "fail") != bool(rules):
        fail(f"{expect_path}: lint.result must be pass with no rules, or fail with rules from {linter_rules!r}")
    run = run_linter(log)
    found = fired_rules(run.stdout)
    if result == "pass":
        if run.returncode != 0:
            fail(f"{log} should lint clean:\n{run.stdout}{run.stderr}")
        passing.append(log)
    else:
        if run.returncode != 1 or found != set(rules):
            fail(
                f"{log} should fail exactly {sorted(rules)!r}; exit {run.returncode}, fired {sorted(found)!r}:\n"
                f"{run.stdout}{run.stderr}"
            )
        failing.append(log)
        covered.update(rules)

if INVENTED not in failing:
    fail(f"{INVENTED} must be a tracked negative fixture")
uncovered = [r for r in linter_rules if r not in covered]
if uncovered:
    fail(f"linter rules with no negative fixture in {FIXTURES}: {uncovered!r}")

print(
    f"PASS: check 8: docs/example-log.md lints clean, {len(passing)} fixture logs pass, and {len(failing)} fail "
    f"with exactly their expected rules; every linter rule has a failing fixture ({', '.join(linter_rules)})"
)

# ---- 8e: codex/update.sh with stubs. The updater runs with stub git and
# codex (tests/stubs/ok, which records its calls) against a temp CODEX_HOME
# seeded with the three retired agents, a stale squad-pm.toml, a stale
# profile, and files that belong to the user. It must exit 0, call git pull
# and the two codex plugin commands, remove the retired agents, install the
# tracked codex/agents/*.toml byte for byte, write each profile in
# codex/profiles.toml, and leave the user's files untouched.
RETIRED = ("squad-design.toml", "squad-manager.toml", "squad-verifier.toml")
agent_tomls = sorted(tracked_files("codex/agents/*.toml"))
if not agent_tomls:
    fail("git ls-files found no codex/agents/*.toml")
profiles_text = read("codex/profiles.toml")
profiles = {}
for name, body in re.findall(r"^\[profiles\.([^\]]+)\]\n(.*?)(?=^\[|\Z)", profiles_text, re.MULTILINE | re.DOTALL):
    profiles[name] = "".join(
        line + "\n" for line in body.splitlines() if re.match(r"(model|model_reasoning_effort)\s*=", line)
    )
if not profiles:
    fail("codex/profiles.toml has no [profiles.*] section")

with tempfile.TemporaryDirectory() as tmp:
    bin_dir = os.path.join(tmp, "bin")
    codex_home = os.path.join(tmp, "codex-home")
    agents_dir = os.path.join(codex_home, "agents")
    stub_log = os.path.join(tmp, "stub-calls.txt")
    for d in (bin_dir, agents_dir, os.path.join(tmp, "home")):
        os.makedirs(d)
    for tool in ("git", "codex"):
        shutil.copyfile("tests/stubs/ok", os.path.join(bin_dir, tool))
        os.chmod(os.path.join(bin_dir, tool), 0o755)
    seeded = {name: f"# retired agent {name}\n" for name in RETIRED}
    seeded["squad-pm.toml"] = 'name = "squad-pm"\nmodel = "stale"\n'
    user_files = {
        os.path.join(agents_dir, "my-reviewer.toml"): 'name = "my-reviewer"\n',
        os.path.join(codex_home, "config.toml"): 'model = "user-choice"\n',
    }
    for name, content in seeded.items():
        with open(os.path.join(agents_dir, name), "w", encoding="utf-8") as f:
            f.write(content)
    with open(os.path.join(codex_home, "compute-squad-pm.config.toml"), "w", encoding="utf-8") as f:
        f.write('model = "stale"\n')
    for path, content in user_files.items():
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)

    env = dict(
        os.environ,
        HOME=os.path.join(tmp, "home"),
        CODEX_HOME=codex_home,
        GIT_BIN=os.path.join(bin_dir, "git"),
        CODEX_BIN=os.path.join(bin_dir, "codex"),
        STUB_LOG=stub_log,
    )
    run = subprocess.run(["bash", "codex/update.sh"], env=env, capture_output=True, text=True)
    if run.returncode != 0:
        fail(f"codex/update.sh with stub git and codex exited {run.returncode}:\n{run.stdout}{run.stderr}")

    calls = read(stub_log).splitlines() if os.path.exists(stub_log) else []
    expected_tail = ["codex plugin marketplace upgrade compute-squad", "codex plugin add compute-squad@compute-squad"]
    git_call = re.fullmatch(r"git -C (.+) pull --ff-only", calls[0]) if calls else None
    if (
        len(calls) != 3
        or not git_call
        or os.path.realpath(git_call.group(1)) != os.path.realpath(os.getcwd())
        or calls[1:] != expected_tail
    ):
        fail(f"codex/update.sh should call git pull on this repo, then the two codex plugin commands; calls were {calls!r}")

    left = [name for name in RETIRED if os.path.exists(os.path.join(agents_dir, name))]
    if left:
        fail(f"codex/update.sh left retired agents in CODEX_HOME/agents: {left!r}")
    installed = sorted(os.listdir(agents_dir))
    wanted = sorted([os.path.basename(p) for p in agent_tomls] + ["my-reviewer.toml"])
    if installed != wanted:
        fail(f"CODEX_HOME/agents holds {installed!r} after the update; expected {wanted!r}")
    for path in agent_tomls:
        with open(path, "rb") as f, open(os.path.join(agents_dir, os.path.basename(path)), "rb") as g:
            if f.read() != g.read():
                fail(f"CODEX_HOME/agents/{os.path.basename(path)} differs from {path}")
    for name, values in profiles.items():
        path = os.path.join(codex_home, f"{name}.config.toml")
        if not os.path.exists(path) or read(path) != values:
            fail(f"CODEX_HOME/{name}.config.toml should hold {values!r} from codex/profiles.toml")
    for path, content in user_files.items():
        if read(path) != content:
            fail(f"codex/update.sh changed the user's file {os.path.relpath(path, codex_home)}")

print(
    f"PASS: check 8: codex/update.sh with stub git and codex prunes the retired agents ({', '.join(RETIRED)}), "
    f"installs the {len(agent_tomls)} codex/agents TOMLs byte for byte, writes {len(profiles)} profiles, "
    f"and leaves the user's files in CODEX_HOME untouched"
)
PYEOF

echo "verify.sh: all checks passed"
