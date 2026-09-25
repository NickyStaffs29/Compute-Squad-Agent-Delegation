#!/usr/bin/env bash
# Verification gate for the compute-squad plugin repo. Run from anywhere;
# paths resolve against the repo root. Requires python3 and unzip.
#
# Checks, in order:
#   1. Claude and Codex plugin/marketplace manifests parse as JSON.
#   2. Every agents/*.md has YAML frontmatter that parses, only the keys name,
#      description, model, color, tools, and omitClaudeMd (placed after model),
#      model in {sonnet, opus, fable} and equal to the Claude alias models.conf
#      assigns that agent's rung, and at least one <example> block in the
#      description. Every Claude rung alias in models.conf is in that set.
#   3. skills/compute-squad/SKILL.md frontmatter parses and its metadata.version
#      equals plugin.json's version. codex/SKILL.md, a reading copy no host
#      loads, opens with its reading-copy title and has a Version: line equal
#      to that version.
#   4. CHANGELOG.md has a heading for that version.
#   5. dist/compute-squad.plugin matches skills/, agents/, commands/, README.md,
#      and .claude-plugin/plugin.json by content (unzip + diff -r, not a rebuild+
#      byte-diff, since zip embeds mtimes and a fresh rebuild would always differ).
#   6. models.conf holds routing policy: it parses (and a malformed copy does
#      not), its roles are the agents plus strategy, finder, and skeptic, each
#      host's three rungs name three different models, the PM is on the top
#      rung, the executors climb one rung per classification under the PM,
#      the skeptic sits above the finders, only the MECHANICAL executor, the
#      helper, and the intern may sit on the Claude bottom rung, and every
#      Codex effort is a known level. The agent TOMLs are well formed, the
#      five manual prompts codex/01-archive.md to codex/05-pm-accept.md are
#      each marked as generated on line 2, and codex/build-agents.py --check
#      holds everything it writes (model lines, TOMLs, profiles, routing
#      blocks, prompts) to models.conf and the agent bodies.
#   7. Shared protocol blocks and facts read identically across files:
#      7a the Goal — Locked template; 7b the BLOCKER block in both SKILL.md
#      files; 7c the helper cap; 7d each of the four files with a generated
#      routing block has one begin and one end marker; 7e the product
#      description; 7f the ## Status and ## Decision templates in SKILL.md
#      and codex/README.md; 7i log headings stay on SKILL.md's closed list; 7j the
#      archive command; 7l protocol text names rungs, not
#      models, outside the routing block; 7m the three executor bodies are one
#      protocol apart from each agent's own name and the MECHANICAL stop line;
#      7o no file names the deleted routing
#      reference; 7p the shared-span table, whose rows include the blocker
#      grammar span (7k), the command output forms (7n), the latest-Goal
#      read, and the rule that changing a criterion's command redefines the
#      criterion; 7q the agent
#      description budget; 7r no agent has a tool to spawn agents; 7s
#      codex/SKILL.md stays a reading copy and both SKILL.md files carry the
#      no-absorption rule; 7t no file names a renamed executor or the old
#      escalation wording, and both SKILL.md files carry the FAIL charge rule
#      and the setup-gap stop; 7u no file under agents/, codex/, or skills/
#      reads the goal from the entry at the top of the log.
#   8. Behavior without a model, on fixtures under tests/: log grammar,
#      including the grant hook's verdict on every Executor entry, the
#      re-lock record, and the stop at a needs-human blocker (8a), the
#      grant hook's decisions on synthetic PreToolUse JSON and over the live
#      seed logs, including its hold on every stage agent except squad-mech
#      while a needs-human blocker is open (8c),
#      codex/update.sh with stubs (8e), which must refuse a model the
#      stub catalog lacks and leave CODEX_HOME unchanged, and whose catalog
#      validator must apply its effort, retirement, upgrade, and format rules,
#      and the usage ledger hook on synthetic transcripts (8f), whose records
#      must hold exact token sums, including a final message written after
#      the hook starts, and which must print nothing. The live
#      tier, tests/live/run.sh, spends model tokens, so neither this script
#      nor CI runs it.
#   9. Staleness: models.conf's reviewed date, or a Snapshot date in README.md
#      or codex/README.md, older than 90 days prints a warning, never a
#      failure.
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
# only allowed keys, the model models.conf assigns its rung (within
# ALLOWED_MODELS), and at least one <example> block in the description.
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

ALLOWED_MODELS = {"sonnet", "opus", "fable"}
EXAMPLE_RE = re.compile(r"<example>.*?</example>", re.DOTALL)

# Every other frontmatter field is a reviewed decision, not a default. The
# camelCase omitClaudeMd must come after model:, because codex/build-agents.py
# ends the description at the next lowercase key and would swallow it there.
ALLOWED_KEYS = ("name", "description", "model", "color", "tools", "omitClaudeMd")

# models.conf assigns each agent a rung, and each rung one Claude alias.
# codex/build-agents.py writes the model: line from it; this names the agent
# whose line disagrees. Check 6 holds the rest of the manifest to policy.
manifest_run = subprocess.run(
    [sys.executable, "codex/build-agents.py", "--parse-manifest", "models.conf"],
    capture_output=True, text=True,
)
if manifest_run.returncode != 0:
    fail(2, f"models.conf does not parse: {manifest_run.stderr.strip()}")
manifest = json.loads(manifest_run.stdout)
rung_aliases = {rung: row["claude"] for rung, row in manifest["rungs"].items()}
unallowed = {rung: alias for rung, alias in rung_aliases.items() if alias not in ALLOWED_MODELS}
if unallowed:
    fail(2, f"models.conf: Claude rung aliases {unallowed!r} are not in {sorted(ALLOWED_MODELS)}")

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
    agent = os.path.basename(path)[:-len(".md")]
    role = manifest["roles"].get(agent)
    if role is None:
        fail(2, f"{path}: models.conf has no [role] row for {agent}")
    assigned = rung_aliases[role["claude_rung"]]
    if model != assigned:
        fail(
            2,
            f"{path}: model {model!r} differs from models.conf, which puts {agent} on the "
            f"{role['claude_rung']} rung ({assigned!r}); edit models.conf and run python3 codex/build-agents.py",
        )

    description = data.get("description", "")
    if not EXAMPLE_RE.search(description):
        fail(2, f"{path}: description has no <example>...</example> block")

ok(2, f"{len(agent_paths)} agent files have valid frontmatter with only allowed keys, the model models.conf assigns, and an <example> block")


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
# Check 6: models.conf, the one file that names models, parses and holds the
# routing policy; the Codex agent TOMLs are well formed; the five manual
# prompts are generated from the agent bodies; and codex/build-agents.py
# --check holds every file it writes to models.conf and the agent bodies.
# The policy is tested here, not the model names, so a re-point that keeps
# the rungs distinct and ordered passes, and one that collapses or inverts
# them fails. This uses only stdlib-compatible text checks so the gate also
# runs on Python 3.9, which predates tomllib.
# ---------------------------------------------------------------------------
python3 <<'PYEOF'
import json
import os
import pathlib
import subprocess
import sys
import tempfile


def fail(msg):
    print(f"FAIL: check 6: {msg}", file=sys.stderr)
    sys.exit(1)


def parse_manifest(path):
    return subprocess.run(
        [sys.executable, "codex/build-agents.py", "--parse-manifest", path],
        capture_output=True, text=True,
    )


RUNG_ORDER = ("bottom", "mid", "top")
HOSTS = ("claude", "codex")
EXTRA_ROLES = ("strategy", "finder", "skeptic")
EFFORTS = ("low", "medium", "high", "xhigh", "max")
MECHANICAL, STANDARD, COMPLEX = "squad-executor-mechanical", "squad-executor", "squad-executor-complex"
# The roles that need no judgment beyond a tight spec; every other role runs
# on the mid rung or above in Claude Code.
BOTTOM_ALLOWED = (MECHANICAL, "squad-helper", "squad-mech")

# (i) models.conf parses. Check 2 holds its Claude aliases to ALLOWED_MODELS.
run = parse_manifest("models.conf")
if run.returncode != 0:
    fail(f"models.conf does not parse: {run.stderr.strip()}")
manifest = json.loads(run.stdout)
if set(manifest["rungs"]) != set(RUNG_ORDER):
    fail(f"models.conf: the rungs are {sorted(manifest['rungs'])!r}, expected {list(RUNG_ORDER)!r}")
rungs, roles = manifest["rungs"], manifest["roles"]

# (ii) the roles are the git-tracked agents plus exactly strategy, finder,
# and skeptic.
agents = sorted(
    path[len("agents/"):-len(".md")]
    for path in subprocess.run(
        ["git", "ls-files", "--", "agents/*.md"], check=True, capture_output=True, text=True,
    ).stdout.split()
)
if sorted(roles) != sorted(agents + list(EXTRA_ROLES)):
    fail(f"models.conf: the [role] rows are {sorted(roles)!r}; expected the agents {agents!r} plus {list(EXTRA_ROLES)!r}")

# (iii) the agent TOMLs are exactly the agent roles, each well formed.
agent_dir = pathlib.Path("codex/agents")
actual = {path.name for path in agent_dir.glob("*.toml")}
if actual != {f"{agent}.toml" for agent in agents}:
    fail(f"codex/agents files are {sorted(actual)!r}, expected one per agent: {[a + '.toml' for a in agents]!r}")
for filename in sorted(actual):
    text = (agent_dir / filename).read_text(encoding="utf-8")
    if 'developer_instructions = """' not in text:
        fail(f"{filename}: missing developer_instructions")
    if not text.rstrip().endswith('"""'):
        fail(f"{filename}: developer_instructions is not closed")


def level(role, host):
    return RUNG_ORDER.index(roles[role][f"{host}_rung"])


problems = []
for host in HOSTS:
    # (iv) each host's three rungs name three different models, so no two
    # rungs collapse onto one model.
    models = [rungs[rung][host] for rung in RUNG_ORDER]
    if len(set(models)) != len(models):
        problems.append(
            f"{host}: the rungs must name three different models; bottom, mid, top are {', '.join(models)}"
        )
    # (v) the PM plans and accepts on the top rung.
    if roles["squad-pm"][f"{host}_rung"] != "top":
        problems.append(f"{host}: squad-pm is on the {roles['squad-pm'][host + '_rung']} rung, not top")
    # (vi) execution climbs one rung per classification, the PM sits above
    # STANDARD execution and at or above every executor, and the skeptic
    # sits above the finders it checks.
    ladder = [level(role, host) for role in (MECHANICAL, STANDARD, COMPLEX)]
    if not ladder[0] < ladder[1] < ladder[2]:
        problems.append(
            f"{host}: executor rungs must climb {MECHANICAL} < {STANDARD} < {COMPLEX}; "
            f"they are {', '.join(RUNG_ORDER[i] for i in ladder)}"
        )
    if not (level("squad-pm", host) > ladder[1] and level("squad-pm", host) >= max(ladder)):
        problems.append(f"{host}: squad-pm must sit above {STANDARD} and at or above every executor")
    if not level("skeptic", host) > level("finder", host):
        problems.append(f"{host}: the skeptic must sit above the finders")
# (vii) in Claude Code, only work that needs no judgment runs on the bottom
# rung.
for role, row in roles.items():
    if row["claude_rung"] == "bottom" and role not in BOTTOM_ALLOWED:
        problems.append(f"claude: {role} is on the bottom rung; only {', '.join(BOTTOM_ALLOWED)} may be")
# (viii) every Codex effort is a level Codex names.
for role, row in roles.items():
    if row["codex_effort"] not in EFFORTS:
        problems.append(f"codex: {role} has effort {row['codex_effort']!r}, not one of {', '.join(EFFORTS)}")
if problems:
    fail("models.conf breaks the routing policy: " + "; ".join(problems))

# (ix) the parser fails on a malformed manifest rather than defaulting: a
# role row missing a column, a role on an unknown rung, a duplicated row,
# and a missing section each exit nonzero with no parsed output.
source_lines = pathlib.Path("models.conf").read_text(encoding="utf-8").split("\n")
role_header = next(i for i, line in enumerate(source_lines) if line.startswith("[role]"))
rung_header = next(i for i, line in enumerate(source_lines) if line.startswith("[rung]"))
row_at = next(
    i for i in range(role_header + 1, len(source_lines))
    if source_lines[i].strip() and not source_lines[i].lstrip().startswith("#")
)
row_fields = source_lines[row_at].split()
rung_end = next(
    (i for i in range(rung_header + 1, len(source_lines)) if not source_lines[i].strip()), len(source_lines)
)
malformed = {
    "a role row missing a column": source_lines[:row_at] + [" ".join(row_fields[:-1])] + source_lines[row_at + 1:],
    "a role on an unknown rung": source_lines[:row_at] + [" ".join([row_fields[0], "upper"] + row_fields[2:])]
    + source_lines[row_at + 1:],
    "a duplicated role row": source_lines[:row_at + 1] + [source_lines[row_at]] + source_lines[row_at + 1:],
    "no [rung] section": source_lines[:rung_header] + source_lines[rung_end:],
}
with tempfile.TemporaryDirectory() as tmp:
    for what, lines in malformed.items():
        path = os.path.join(tmp, "models.conf")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines))
        bad = parse_manifest(path)
        if bad.returncode == 0 or bad.stdout.strip() or "FAIL:" not in bad.stderr:
            fail(f"the models.conf parser accepted a copy with {what}; it must exit nonzero and print no manifest")

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

sync = subprocess.run([sys.executable, "codex/build-agents.py", "--check"], capture_output=True, text=True)
if sync.returncode != 0:
    fail(
        "codex/build-agents.py --check failed; a generated file was hand-edited or models.conf or an agent "
        f"body changed without a regeneration (run python3 codex/build-agents.py):\n{sync.stdout}{sync.stderr}"
    )

with open(".codex-plugin/plugin.json", encoding="utf-8") as handle:
    manifest = json.load(handle)
if manifest.get("skills") != "./skills/":
    fail(".codex-plugin/plugin.json does not point at ./skills/")

print(
    f"PASS: check 6: models.conf parses and holds the routing policy on both hosts, {len(malformed)} malformed "
    f"copies fail to parse, the {len(actual)} Codex agent TOMLs and 5 manual prompts are valid, and "
    f"codex/build-agents.py --check finds every generated file in sync"
)
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
    "agents/squad-executor-mechanical.md",
    "agents/squad-executor-complex.md",
]
cap_re = re.compile(r"5[^0-9]{0,20}per\s+stage\s+per\s+run")
for path in cap_paths:
    if not cap_re.search(read(path)):
        fail(f"{path}: no '5 ... per stage per run' helper-cap phrase found")

print(f"PASS: check 7: the 5-helper-per-stage-per-run cap reads '5' in {', '.join(cap_paths)}")

# ---- 7d: the routing blocks. codex/build-agents.py writes each block from
# models.conf between one "<!-- routing:begin -->" line and one
# "<!-- routing:end -->" line in four files, and check 6's --check holds
# their content to models.conf. Here each file must have exactly one begin
# marker, then one end marker, each alone on its line. In the shared skill,
# 7l bans model names everywhere outside the block.
ROUTING_BEGIN = "<!-- routing:begin -->"
ROUTING_END = "<!-- routing:end -->"
routing_block_paths = ["skills/compute-squad/SKILL.md", "codex/SKILL.md", "README.md", "codex/README.md"]


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


for path in routing_block_paths:
    routing_block_span(path, read(path).splitlines())

print(
    f"PASS: check 7: {', '.join(routing_block_paths)} each have one routing block between a begin and an end "
    f"marker (check 6's --check holds the content to models.conf)"
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

# ---- 7f: the ## Status and ## Decision templates. Only the main session
# writes these entries; on the manual Codex path the user writes them by hand
# from codex/README.md, so both fenced templates are byte-identical there and
# in SKILL.md. Check 8c builds its logs from SKILL.md's Status template.
main_entry_paths = ["skills/compute-squad/SKILL.md", "codex/README.md"]
for heading in ("## Status", "## Decision"):
    blocks = {path: extract_fenced_block(read(path), path, "```markdown", heading) for path in main_entry_paths}
    ref_path, ref_block = next(iter(blocks.items()))
    for path, block in blocks.items():
        if block != ref_block:
            fail(f"{path}: {heading} template differs from {ref_path}")

print(f"PASS: check 7: the ## Status and ## Decision templates are byte-identical across {', '.join(main_entry_paths)}")


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
# such as 1.67x, except inside the routing block that 7d checks. The match is
# case-sensitive, so the lowercase aliases in frontmatter model: lines pass.
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

# ---- 7m: one executor protocol under three names, one per rung. The three
# executor bodies must be byte-identical once each file's own agent name is
# replaced by a placeholder and the MECHANICAL executor's under-classification
# stop line is dropped. That line must stay, exactly once, in the MECHANICAL
# body: bottom-rung execution stops on work that needs more than
# transcription instead of pushing it through to acceptance.
EXECUTOR_NAMES = {
    "agents/squad-executor.md": "squad-executor",
    "agents/squad-executor-mechanical.md": "squad-executor-mechanical",
    "agents/squad-executor-complex.md": "squad-executor-complex",
}
MECHANICAL_BODY = "agents/squad-executor-mechanical.md"
MECHANICAL_STOP = (
    "- If any task in the plan requires more than transcription of an explicitly specified change, "
    "stop and log a `BLOCKER:` with `rerun: Plan` stating the plan under-classified the work."
)
tracked_executors = sorted(tracked_files("agents/squad-executor*.md"))
if tracked_executors != sorted(EXECUTOR_NAMES):
    fail(f"the tracked executor files are {tracked_executors!r}; expected {sorted(EXECUTOR_NAMES)!r}")
executor_bodies = {}
for path, name in EXECUTOR_NAMES.items():
    text = read(path)
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        fail(f"{path}: no frontmatter")
    body = text[text.index("\n---\n", 4) + len("\n---\n"):]
    lines = re.sub(re.escape(name) + r"(?![\w-])", "<agent>", body).split("\n")
    stops = [i for i, line in enumerate(lines) if line == MECHANICAL_STOP]
    if path == MECHANICAL_BODY:
        if len(stops) != 1:
            fail(f"{path}: needs the MECHANICAL stop line exactly once; found {len(stops)}: {MECHANICAL_STOP!r}")
        del lines[stops[0]]
    executor_bodies[path] = lines
ref_path = "agents/squad-executor.md"
for path, lines in executor_bodies.items():
    if lines != executor_bodies[ref_path]:
        at = next(
            (i for i, pair in enumerate(zip(lines, executor_bodies[ref_path])) if pair[0] != pair[1]),
            min(len(lines), len(executor_bodies[ref_path])),
        )
        expected = executor_bodies[ref_path][at] if at < len(executor_bodies[ref_path]) else "<end of body>"
        found = lines[at] if at < len(lines) else "<end of body>"
        fail(
            f"{path}: the executor body differs from {ref_path} at body line {at + 1} (agent names shown as "
            f"<agent>): expected {expected!r}, found {found!r}"
        )

print(
    f"PASS: check 7: {', '.join(EXECUTOR_NAMES)} share one body apart from each agent's own name and the "
    f"MECHANICAL stop line, which {MECHANICAL_BODY} keeps"
)

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
    "agents/squad-executor-mechanical.md",
    "agents/squad-executor-complex.md",
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
# Every stage reads the goal from the latest ## Goal — Locked entry, since a
# re-lock appends a new one, and every file that can change a command names
# the rule that doing so redefines the criterion (7u bans the old read).
LATEST_GOAL_READ = (
    "read the locked goal and acceptance criteria from the latest `## Goal — Locked` entry in the log "
    "(a re-lock appends a new one"
)
CRITERION_COMMAND = (
    "Changing a command, test, or check that an acceptance criterion names counts as redefining that criterion."
)


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
    span_row("latest Goal read", BODIES + CODEX_STAGE_PROMPTS, text=LATEST_GOAL_READ),
    span_row("criterion command", [SKILL, "agents/squad-pm.md"] + EXECUTOR_BODIES + CODEX_STAGE_PROMPTS[1:],
             text=CRITERION_COMMAND),
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

# ---- 7t: the ladder text. The executors are named by classification
# (squad-executor-mechanical, squad-executor-complex), not by model, and a
# FAIL moves its stage one rung, not two FAILs per tier. No tracked file
# outside the history files, the updater (whose retired list prunes the old
# TOMLs), this script, and dist/ names an old executor or the old escalation
# wording; both SKILL.md files carry the FAIL charge rule and the setup-gap
# stop. Text is compared with whitespace collapsed, so a wrapped line still
# counts.
RETIRED_LADDER_TEXT = (
    "squad-executor-haiku",
    "squad-executor-opus",
    "two FAILs at a tier",
    "top-tier main-session pass",
)
LADDER_EXEMPT = ("CHANGELOG.md", "LEFTOVER_FINDINGS.md", "codex/update.sh", "scripts/verify.sh")
LADDER_RULES = ("charged to the stage its", "report the setup gap")
stale_ladder = []
for path in tracked_files():
    if path in LADDER_EXEMPT or path.startswith("dist/"):
        continue
    try:
        with open(path, "rb") as handle:
            flat = " ".join(handle.read().decode("utf-8", errors="replace").split())
    except (FileNotFoundError, IsADirectoryError):
        continue
    stale_ladder.extend(f"{path}: {phrase!r}" for phrase in RETIRED_LADDER_TEXT if phrase in flat)
if stale_ladder:
    fail("retired executor names or escalation wording: " + "; ".join(stale_ladder))
for path in (SKILL, "codex/SKILL.md"):
    flat = " ".join(read(path).split())
    missing = [rule for rule in LADDER_RULES if rule not in flat]
    if missing:
        fail(f"{path}: missing the ladder rules {missing!r}")

print(
    f"PASS: check 7: no tracked file outside {', '.join(LADDER_EXEMPT)} and dist/ names a retired executor or "
    f"the old escalation wording, and both SKILL.md files carry {' and '.join(repr(r) for r in LADDER_RULES)}"
)

# ---- 7u: stages read the latest Goal entry. A re-lock appends a new
# ## Goal — Locked entry after a re-lock ## Decision, so no tracked file under
# agents/, codex/, or skills/ tells a stage to read the goal from the entry
# "at the top of the log". The 7p rows "latest Goal read" and "criterion
# command" pin the wording that replaced it. Text is compared with whitespace
# collapsed, so a wrapped line still counts.
STALE_GOAL_READ = "at the top of the log"
goal_read_paths = tracked_files("agents", "codex", "skills")
if not any(p.startswith("codex/agents/") for p in goal_read_paths):
    fail("check 7u found no tracked codex/agents/*.toml")
stale_goal_read = []
for path in goal_read_paths:
    try:
        with open(path, "rb") as handle:
            flat = " ".join(handle.read().decode("utf-8", errors="replace").split())
    except (FileNotFoundError, IsADirectoryError):
        continue
    if STALE_GOAL_READ in flat:
        stale_goal_read.append(path)
if stale_goal_read:
    fail(f"these files still read the goal {STALE_GOAL_READ!r}; read it from the latest `## Goal — Locked` entry: "
         + ", ".join(stale_goal_read))

print(
    f"PASS: check 7: no tracked file under agents/, codex/, or skills/ ({len(goal_read_paths)} files) reads the goal "
    f"{STALE_GOAL_READ!r}; every stage reads the latest ## Goal — Locked entry"
)
PYEOF

# ---------------------------------------------------------------------------
# Check 8: behavior without a model. Checks 1 to 7 compare text; this check
# runs the protocol's own grammar and scripts on fixtures, so a change that
# keeps every copy in sync but breaks behavior still fails CI. Everything
# runs in temp dirs; nothing here writes into the repo.
# ---------------------------------------------------------------------------
python3 <<'PYEOF'
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time


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
# opening entry, the timestamp form, the BLOCKER grammar, the Goal
# template's Attended: field and the re-lock rule from
# skills/compute-squad/SKILL.md and lints a log against them; its grant rule
# runs the grant hook (8c) over the log above every Executor entry, its
# re-lock rule holds every later Goal entry to a re-lock Decision directly
# above it, and its needs-human rule lets no stage entry follow a needs-human
# blocker until a Decision. The example
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

# ---- 8c: the grant hook. skills/compute-squad/hooks/grant-gate.sh runs on
# Claude Code's PreToolUse event for the spawn tool, wired inline under the
# hooks key of .claude-plugin/plugin.json with a matcher for both of its
# names, Agent and Task (Claude Code 2.1.282 reports Task); a root
# hooks/hooks.json would load in Codex too, where it would allow every
# spawn. Synthetic PreToolUse JSON
# is piped into the script under sh, and under dash and bash where they are
# installed, in a temp git repo whose log is built from SKILL.md's ## Status
# template. Every tracked executor, with and without the plugin prefix, is
# denied with no log, with Grant: none, with no Grant line in the latest
# Status, with a grant for another plan revision, and with a grant written
# anywhere but the latest Status; it is allowed with a grant for the current
# revision (the count of ## PM — Plan entries without (cont.)) or for all
# revisions. While a needs-human: BLOCKER has no ## Decision after it, the
# script holds every executor and every other stage agent except squad-mech
# (it archives a fresh run at Stage 1): squad-helper, squad-pm, and
# squad-recon. A Decision releases the hold; a later needs-human: blocker
# holds again, and so does a later rerun: blocker, which cannot resolve it.
# Every other agent, and input the script cannot read, is allowed silently.
# Over the live seeds in tests/fixtures/logs/ that tests/live/run.sh uses,
# every executor is denied for s1 and s2b and allowed for s2 and s2c.
# An allow prints nothing; a deny prints one PreToolUse decision, whose
# reason names ## Status for a missing grant and the open blocker for a hold.
GATE = "skills/compute-squad/hooks/grant-gate.sh"
CLAUDE_PLUGIN = ".claude-plugin/plugin.json"
SKILL = "skills/compute-squad/SKILL.md"
GATE_COMMAND = 'sh "${CLAUDE_PLUGIN_ROOT}/' + GATE + '"'
if GATE not in tracked_set:
    fail(f"{GATE} is not tracked, so the plugin would ship without it")
if "hooks/hooks.json" in tracked_set:
    fail(f"hooks/hooks.json is tracked; Codex loads a plugin's root hooks/hooks.json, so Claude hooks stay inline in {CLAUDE_PLUGIN}")
if re.search(r"\b(?:python3?|jq)\b", read(GATE)):
    fail(f"{GATE} calls python or jq; the hook stays POSIX sh with git, sed, awk, and grep")
wired = 0
for entry in json.loads(read(CLAUDE_PLUGIN)).get("hooks", {}).get("PreToolUse", []):
    try:
        matches = all(re.fullmatch(entry.get("matcher", ""), tool) for tool in ("Agent", "Task"))
    except re.error:
        matches = False
    commands = [h.get("command") for h in entry.get("hooks", []) if h.get("type") == "command"]
    if matches and GATE_COMMAND in commands:
        wired += 1
if wired != 1:
    fail(f"{CLAUDE_PLUGIN}: hooks.PreToolUse must run {GATE_COMMAND!r} once, under a matcher that matches Agent and Task")

skill_lines = read(SKILL).splitlines()
status_at = [i for i in range(len(skill_lines) - 1) if skill_lines[i] == "```markdown" and skill_lines[i + 1] == "## Status"]
if len(status_at) != 1:
    fail(f"{SKILL}: needs one ```markdown block that opens with ## Status; found {len(status_at)}")
status_template = []
for line in skill_lines[status_at[0] + 1:]:
    if line == "```":
        break
    status_template.append(line)
if sum(line.startswith("Grant: ") for line in status_template) != 1:
    fail(f"{SKILL}: the ## Status template needs exactly one 'Grant: ' line, which {GATE} reads")


def status(grant):
    """A ## Status entry from SKILL.md's template with its Grant: line set to
    grant, or dropped when grant is None."""
    lines = []
    for line in status_template:
        if line.startswith("Grant: "):
            if grant is None:
                continue
            line = "Grant: " + grant
        lines.append(line)
    return "\n".join(lines) + "\n\n"


GOAL = "## Goal — Locked\nTimestamp: 2026-09-01T09:00:00Z\n\nGoal: g\n\n"
PLAN = "## PM — Plan\nTimestamp: 2026-09-01T09:05:00Z\n\nTasks.\n\n"
PLAN_CONT = "## PM — Plan (cont.)\nTimestamp: 2026-09-01T09:06:00Z\n\nMore tasks.\n\n"
DECISION = '## Decision\nTimestamp: 2026-09-01T09:07:00Z\nType: grant\nCovers: r1, work order all\nUser\'s words: "go"\n\n'
R1 = "r1 all, per Decision 2026-09-01T09:07:00Z"
R2 = "r2 WO-1, per Decision 2026-09-01T09:07:00Z"
ALL = "all revisions, full-mode request"
GATE_CASES = [
    ("no log", None, "deny"),
    ("Grant: none", GOAL + status("none"), "deny"),
    ("no Grant line in the latest Status", GOAL + status(None), "deny"),
    ("no Grant line in the latest Status after a granting one", GOAL + status(ALL) + PLAN + status(None), "deny"),
    ("Grant: all revisions", GOAL + status(ALL), "allow"),
    ("r1 before any plan", GOAL + status(R1), "deny"),
    ("r0 before any plan", GOAL + status("r0 all, per Decision 2026-09-01T09:07:00Z"), "deny"),
    ("r1 over one plan", GOAL + status("none") + PLAN + status(R1), "allow"),
    ("r2 over two plans and a (cont.)", GOAL + status("none") + PLAN + PLAN_CONT + PLAN + status(R2), "allow"),
    ("r2 after a third plan", GOAL + status("none") + PLAN + PLAN_CONT + PLAN + status(R2) + PLAN, "deny"),
    ("r1 over eleven plans", GOAL + PLAN * 11 + status(R1), "deny"),
    ("r11 over eleven plans", GOAL + PLAN * 11 + status("r11 all, per Decision 2026-09-01T09:07:00Z"), "allow"),
    ("r11 over one plan", GOAL + PLAN + status("r11 all, per Decision 2026-09-01T09:07:00Z"), "deny"),
    ("a Grant line outside a Status entry", GOAL + status("none") + PLAN.replace("Tasks.", "Tasks.\nGrant: " + ALL), "deny"),
    ("a grant Decision with no Status after it", GOAL + status("none") + PLAN + DECISION, "deny"),
    ("a later Status that revokes", GOAL + status(ALL) + PLAN + status("none"), "deny"),
    ("a later Status that grants", GOAL + status("none") + PLAN + status(ALL), "allow"),
]
SEED_VERDICTS = [("s1", "deny"), ("s2", "allow"), ("s2b", "deny"), ("s2c", "allow")]
for seed, _ in SEED_VERDICTS:
    if FIXTURES + seed + ".log.md" not in tracked_set:
        fail(f"check 8c needs the tracked live seed {FIXTURES}{seed}.log.md")
executors = sorted(os.path.basename(p)[:-len(".md")] for p in tracked_files("agents/squad-executor*.md"))
others = sorted(os.path.basename(p)[:-len(".md")] for p in tracked_files("agents/*.md"))
others = [a for a in others if a not in executors]
if not executors or not others:
    fail("check 8c found no tracked executor or no other agent under agents/")
# A needs-human: blocker holds every stage agent; only the intern, which
# archives a fresh run's log at Stage 1, and agents outside the squad pass.
HOLD_EXEMPT = "squad-mech"
HOLD_REASON = "needs-human blocker unresolved"
if HOLD_EXEMPT not in others:
    fail(f"check 8c found no tracked agents/{HOLD_EXEMPT}.md")
held = [a for a in others if a != HOLD_EXEMPT]
PLAN_NH = (
    "## PM — Plan\nTimestamp: 2026-09-01T09:05:00Z\n\nTasks.\n\nBLOCKER:\n"
    "- needs-human: whether the command a criterion names may change\n- why: it fails on the base commit.\n\n"
)
RECON_NH = PLAN_NH.replace("## PM — Plan", "## Recon (cont.)").replace("09:05:00Z", "09:09:00Z")
RERUN = "## Executor\nTimestamp: 2026-09-01T09:10:00Z\n\nStopped.\n\nBLOCKER:\n- rerun: Plan\n- why: w.\n\n"
RELOCK = (
    "## Decision\nTimestamp: 2026-09-01T09:08:00Z\nType: re-lock\nCovers: criterion 2\n"
    "User's words: \"change it\"\n\n"
)
# (name, log, executor verdict, verdict for the other held agents)
HOLD_CASES = [
    ("a log that ends in a needs-human: blocker", GOAL + status(ALL) + PLAN_NH, "hold", "hold"),
    ("a Status after a needs-human: blocker", GOAL + status(ALL) + PLAN_NH + status(ALL), "hold", "hold"),
    ("a needs-human: blocker and no grant", GOAL + status("none") + PLAN_NH, "deny", "hold"),
    ("a blank line inside the BLOCKER: block", GOAL + status(ALL) + PLAN_NH.replace("BLOCKER:\n", "BLOCKER:\n\n"),
     "hold", "hold"),
    ("a Decision after a needs-human: blocker", GOAL + status(ALL) + PLAN_NH + RELOCK, "allow", "allow"),
    ("a Decision and a Status after a needs-human: blocker", GOAL + status(ALL) + PLAN_NH + RELOCK + status(ALL),
     "allow", "allow"),
    ("a second needs-human: blocker after a Decision", GOAL + status(ALL) + PLAN_NH + RELOCK + status(ALL) + RECON_NH,
     "hold", "hold"),
    ("a rerun: blocker after an open needs-human: blocker", GOAL + status(ALL) + PLAN_NH + RERUN, "hold", "hold"),
    ("a suffixed Decision heading", GOAL + status(ALL) + PLAN_NH + RELOCK.replace("## Decision", "## Decision (addendum)"),
     "hold", "hold"),
    ("only a rerun: blocker", GOAL + status(ALL) + PLAN + RERUN, "allow", "allow"),
    ("needs-human: text outside a BLOCKER: block",
     GOAL + status(ALL) + PLAN.replace("Tasks.", "Tasks. The PM weighed a `BLOCKER:` block.\n- needs-human: none"),
     "allow", "allow"),
]
shells = [sh for sh in ("sh", "dash", "bash") if shutil.which(sh)]
if "sh" not in shells:
    fail("check 8c needs sh, which runs the hook on every host")
gate_path = os.path.abspath(GATE)
gate_env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}


def gate(shell, payload, cwd):
    run = subprocess.run([shell, gate_path], input=payload, capture_output=True, text=True, env=gate_env, cwd=cwd, timeout=60)
    if run.returncode != 0 or run.stderr:
        fail(f"{GATE} under {shell} exited {run.returncode} with stderr {run.stderr.strip()!r} for {payload!r}")
    if not run.stdout:
        return "allow"
    try:
        decision = json.loads(run.stdout)["hookSpecificOutput"]
        reason = decision["permissionDecisionReason"]
        ok = (decision["hookEventName"] == "PreToolUse" and decision["permissionDecision"] == "deny"
              and run.stdout.count("\n") == 1)
    except (ValueError, KeyError, TypeError):
        ok, reason = False, ""
    if ok and HOLD_REASON in reason:
        return "hold"
    if not ok or "## Status" not in reason:
        fail(
            f"{GATE} under {shell} printed something other than one PreToolUse deny naming ## Status or "
            f"{HOLD_REASON!r}: {run.stdout!r}"
        )
    return "deny"


def payload(agent, cwd, style="compact"):
    data = {"session_id": "s", "hook_event_name": "PreToolUse", "tool_name": "Agent",
            "tool_input": {"description": "d", "prompt": "p", "subagent_type": agent}, "cwd": cwd}
    if style == "spaced":
        return json.dumps(data, separators=(" , ", " : "))
    if style == "indented":
        return json.dumps(data, indent=2)
    return json.dumps(data, separators=(",", ":"))


checked = 0
with tempfile.TemporaryDirectory() as tmp:
    repo = os.path.join(tmp, "repo")
    sub = os.path.join(repo, "src", "deep")
    os.makedirs(sub)
    subprocess.run(["git", "init", "-q", repo], check=True, env=gate_env)
    log = os.path.join(repo, "COMPUTE_SQUAD_LOG.md")
    for name, text, expected in GATE_CASES:
        if text is None:
            if os.path.exists(log):
                os.remove(log)
        else:
            with open(log, "w", encoding="utf-8") as handle:
                handle.write(text)
        for shell in shells:
            for agent in executors:
                for form in (agent, "compute-squad:" + agent):
                    got = gate(shell, payload(form, repo), tmp)
                    checked += 1
                    if got != expected:
                        fail(f"{GATE} under {shell}: {form} with {name}: expected {expected}, got {got}")
            if expected == "allow":
                continue
            for agent in others + ["general-purpose", "Explore"]:
                for form in (agent, "compute-squad:" + agent):
                    checked += 1
                    if gate(shell, payload(form, repo), tmp) != "allow":
                        fail(f"{GATE} under {shell}: {form} with {name}: a spawn that is not an executor must pass")
    # The live seeds of section 6 (tests/live/run.sh) as they stand: S1's
    # empty log and S2b's grant for r1 under plan r2 deny, S2's r1 WO-1 grant
    # allows. S2c allows too: its zero spawns rest on the work-order scope of
    # a grant, which this hook does not check, so 8b covers S2c.
    for seed, expected in SEED_VERDICTS:
        with open(log, "w", encoding="utf-8") as handle:
            handle.write(read(FIXTURES + seed + ".log.md"))
        for shell in shells:
            for agent in executors:
                got = gate(shell, payload("compute-squad:" + agent, repo), tmp)
                checked += 1
                if got != expected:
                    fail(f"{GATE} under {shell}: compute-squad:{agent} over the live seed {FIXTURES}{seed}.log.md: "
                         f"expected {expected}, got {got}")
    # A needs-human: blocker with no ## Decision after it holds every stage.
    for name, text, for_executor, for_held in HOLD_CASES:
        with open(log, "w", encoding="utf-8") as handle:
            handle.write(text)
        for shell in shells:
            for agent in executors + held + [HOLD_EXEMPT, "general-purpose", "Explore"]:
                expected = for_executor if agent in executors else for_held if agent in held else "allow"
                for form in (agent, "compute-squad:" + agent):
                    got = gate(shell, payload(form, repo), tmp)
                    checked += 1
                    if got != expected:
                        fail(f"{GATE} under {shell}: {form} with {name}: expected {expected}, got {got}")
    # JSON layout, the working directory, and unreadable input.
    for text, expected in ((GOAL + status("none"), "deny"), (GOAL + status(ALL), "allow")):
        with open(log, "w", encoding="utf-8") as handle:
            handle.write(text)
        for shell in shells:
            for style in ("spaced", "indented"):
                for cwd in (repo, sub):
                    checked += 1
                    if gate(shell, payload("compute-squad:" + executors[0], cwd, style), tmp) != expected:
                        fail(f"{GATE} under {shell}: {style} JSON with cwd {cwd} must {expected}")
            for bad in ("", "not json", '{"tool_input":{}}'):
                checked += 1
                if gate(shell, bad, tmp) != "allow":
                    fail(f"{GATE} under {shell}: input with no subagent_type ({bad!r}) must pass silently")
    # Outside a git repository the log is read from cwd itself.
    plain = os.path.join(tmp, "plain")
    os.makedirs(plain)
    ceiling = dict(gate_env, GIT_CEILING_DIRECTORIES=tmp)
    for text, expected in ((GOAL + status("none"), "deny"), (GOAL + status(ALL), "allow")):
        with open(os.path.join(plain, "COMPUTE_SQUAD_LOG.md"), "w", encoding="utf-8") as handle:
            handle.write(text)
        run = subprocess.run(["sh", gate_path], input=payload(executors[0], plain), capture_output=True, text=True,
                             env=ceiling, timeout=60)
        checked += 1
        if run.returncode != 0 or ("deny" if run.stdout else "allow") != expected:
            fail(f"{GATE}: outside a git repository, a log in cwd with {text.splitlines()[-2]!r} must {expected}")

print(
    f"PASS: check 8: {GATE} is wired once in {CLAUDE_PLUGIN} for Agent and Task and made {checked} decisions as "
    f"specified under {', '.join(shells)}: {', '.join(executors)} denied without a grant for the current plan "
    f"revision, with and without the compute-squad: prefix, and over the live seeds "
    f"{', '.join(f'{seed} {verdict}' for seed, verdict in SEED_VERDICTS)}; {', '.join(executors + held)} held while a "
    f"needs-human: blocker has no ## Decision after it; and {HOLD_EXEMPT} always allowed"
)

# ---- 8e: codex/update.sh with stubs. The updater runs with stub git
# (tests/stubs/ok) and a stub codex (tests/stubs/codex, whose `debug models`
# prints a stub catalog), both recording their calls, against a temp
# CODEX_HOME seeded with the five retired agents, a stale squad-pm.toml, a
# stale profile, and files that belong to the user. First the stub catalog
# lacks one pinned model: the updater must exit 1 after git pull and
# `codex debug models`, name that model, and leave CODEX_HOME byte for byte
# as it was. Then the catalog lists every pinned model and effort: it must
# exit 0, call git pull, `codex debug models`, and the two codex plugin
# commands, remove the retired agents, install the tracked
# codex/agents/*.toml byte for byte, write each profile in
# codex/profiles.toml, and leave the user's files untouched. Last,
# codex/build-agents.py --validate-catalog runs on its own against stub
# catalogs, one per remaining rule: a missing effort, a past or near
# retirement, an upgrade target, and a format it cannot read.
RETIRED = (
    "squad-design.toml",
    "squad-manager.toml",
    "squad-verifier.toml",
    "squad-executor-haiku.toml",
    "squad-executor-opus.toml",
)
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

# The stub catalog, in the shape `codex debug models` prints: every pinned
# model with its pinned efforts, plus one listed model nothing pins.
pinned = {}
for text in [read(p).split("developer_instructions", 1)[0] for p in agent_tomls] + list(profiles.values()):
    model = re.search(r'^model\s*=\s*"([^"]+)"', text, re.MULTILINE)
    effort = re.search(r'^model_reasoning_effort\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if not model or not effort:
        fail(f"a codex/agents TOML or codex/profiles.toml table has no model or effort line:\n{text}")
    pinned.setdefault(model.group(1), set()).add(effort.group(1))


def stub_catalog(models):
    entries = [
        {
            "slug": model,
            "visibility": "list",
            "supported_reasoning_levels": [{"effort": e} for e in sorted(pinned.get(model, {"medium"}))],
            "upgrade": None,
        }
        for model in models
    ]
    return json.dumps({"models": entries}, indent=2) + "\n"


def snapshot(root):
    state = {}
    for dirpath, dirnames, filenames in os.walk(root):
        for name in dirnames:
            state[os.path.relpath(os.path.join(dirpath, name), root) + "/"] = None
        for name in filenames:
            with open(os.path.join(dirpath, name), "rb") as f:
                state[os.path.relpath(os.path.join(dirpath, name), root)] = f.read()
    return state


absent = sorted(pinned)[0]
with tempfile.TemporaryDirectory() as tmp:
    bin_dir = os.path.join(tmp, "bin")
    codex_home = os.path.join(tmp, "codex-home")
    agents_dir = os.path.join(codex_home, "agents")
    stub_log = os.path.join(tmp, "stub-calls.txt")
    catalog_path = os.path.join(tmp, "catalog.json")
    for d in (bin_dir, agents_dir, os.path.join(tmp, "home")):
        os.makedirs(d)
    for tool, stub in (("git", "tests/stubs/ok"), ("codex", "tests/stubs/codex")):
        shutil.copyfile(stub, os.path.join(bin_dir, tool))
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
        STUB_CATALOG=catalog_path,
    )

    def run_update(models):
        with open(catalog_path, "w", encoding="utf-8") as f:
            f.write(stub_catalog(models))
        if os.path.exists(stub_log):
            os.remove(stub_log)
        run = subprocess.run(["bash", "codex/update.sh"], env=env, capture_output=True, text=True)
        calls = read(stub_log).splitlines() if os.path.exists(stub_log) else []
        git_call = re.fullmatch(r"git -C (.+) pull --ff-only", calls[0]) if calls else None
        if not git_call or os.path.realpath(git_call.group(1)) != os.path.realpath(os.getcwd()):
            fail(f"codex/update.sh should first call git pull on this repo; calls were {calls!r}")
        return run, calls[1:]

    before = snapshot(codex_home)
    run, calls = run_update(sorted(set(pinned) - {absent}) + ["stub-model-not-pinned"])
    if run.returncode != 1 or absent not in run.stderr:
        fail(
            f"codex/update.sh should exit 1 and name {absent}, which the stub catalog lacks; it exited "
            f"{run.returncode}:\n{run.stdout}{run.stderr}"
        )
    if calls != ["codex debug models"]:
        fail(f"codex/update.sh should stop after `codex debug models` when the catalog lacks a model; calls were {calls!r}")
    after = snapshot(codex_home)
    if after != before:
        changed = sorted(p for p in set(before) | set(after) if before.get(p, 0) != after.get(p, 0))
        fail(f"codex/update.sh refused {absent} but changed CODEX_HOME: {changed!r}")

    run, calls = run_update(sorted(pinned) + ["stub-model-not-pinned"])
    if run.returncode != 0:
        fail(f"codex/update.sh with stub git and codex exited {run.returncode}:\n{run.stdout}{run.stderr}")
    expected_calls = [
        "codex debug models",
        "codex plugin marketplace upgrade compute-squad",
        "codex plugin add compute-squad@compute-squad",
    ]
    if calls != expected_calls:
        fail(f"codex/update.sh should call git pull, then {expected_calls!r}; after git pull the calls were {calls!r}")

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

# The validator's other rules, run directly on a stub catalog that lists
# every pinned model. Each case changes one key of one entry (DROP removes
# it) and gives the exit code without and with --strict, the text stderr
# must hold, and whether stdout prints the validated line.
DROP = object()
target = sorted(pinned)[0]
soon = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=10)).strftime("%Y-%m-%dT%H:%M:%SZ")
validator_cases = (
    ("an effort the model lacks", "supported_reasoning_levels", [{"effort": "stub-effort"}], 1, 1,
     f"{target} does not support reasoning effort", False),
    ("a past retirement", "upgrade", {"model": None, "retirement_at": "2000-01-01T00:00:00Z"}, 1, 1,
     f"{target} was retired at", False),
    ("a retirement within 30 days", "upgrade", {"model": None, "retirement_at": soon}, 0, 1,
     f"{target} retires at", True),
    ("an upgrade target", "upgrade", {"model": "stub-successor"}, 0, 0,
     f"{target} is superseded by stub-successor", True),
    ("no upgrade key", "upgrade", DROP, 0, 1,
     "catalog format not recognized; models were not validated", False),
)
with tempfile.TemporaryDirectory() as tmp:
    catalog_path = os.path.join(tmp, "catalog.json")
    for label, key, value, plain_rc, strict_rc, needle, validated in validator_cases:
        catalog = json.loads(stub_catalog(sorted(pinned)))
        entry = next(e for e in catalog["models"] if e["slug"] == target)
        if value is DROP:
            del entry[key]
        else:
            entry[key] = value
        with open(catalog_path, "w", encoding="utf-8") as f:
            json.dump(catalog, f)
        for strict, want in ((False, plain_rc), (True, strict_rc)):
            args = [sys.executable, "codex/build-agents.py", "--validate-catalog", catalog_path] + ["--strict"] * strict
            run = subprocess.run(args, capture_output=True, text=True)
            says_validated = "each is in the catalog" in run.stdout
            if run.returncode != want or needle not in run.stderr or says_validated != (validated and want == 0):
                fail(
                    f"codex/build-agents.py --validate-catalog{' --strict' * strict} on a catalog with {label} for "
                    f"{target} should exit {want}, print {needle!r}, and "
                    f"{'print' if validated and want == 0 else 'not print'} its validated line; it exited "
                    f"{run.returncode}:\n{run.stdout}{run.stderr}"
                )

print(
    f"PASS: check 8: codex/update.sh with stub git and codex refuses a catalog that lacks {absent} and leaves "
    f"CODEX_HOME unchanged; with every pinned model listed it prunes the retired agents ({', '.join(RETIRED)}), "
    f"installs the {len(agent_tomls)} codex/agents TOMLs byte for byte, writes {len(profiles)} profiles, "
    f"and leaves the user's files in CODEX_HOME untouched; --validate-catalog handles {len(validator_cases)} "
    f"more stub catalogs ({', '.join(case[0] for case in validator_cases)}) as specified, with and without --strict"
)

# ---- 8f: the usage ledger. skills/compute-squad/hooks/usage-ledger.sh runs
# on Claude Code's SubagentStop and Stop events, wired inline in
# .claude-plugin/plugin.json with no matcher: a SubagentStop matcher filters
# by agent type, and the ledger must also record agents that have no agent
# file, such as audit finders, while a run's log is non-empty. Measured on
# Claude Code 2.1.282 with a Haiku main session: the host queues transcript
# writes and flushes them every 100 ms, so an agent's final message can reach
# its transcript after SubagentStop fires. One probe's ledger missed a
# background executor's last call that way, and another's snapshot taken as
# the hook started lacked the final message, so the script waits, at most
# five seconds, while the last assistant record still ends in a tool call or
# has no stop reason. A message with parallel tool calls can keep the output
# count of its first streamed record (3 where the host counted 193), so the
# ledger's output can read low while billed input stays exact; the live
# tier's 1% check reports that. On a small run without such a message the
# ledger's totals equal the host's modelUsage exactly, a compute-squad:.*
# matcher runs the hook for squad agents only, and the Stop hook's output did
# not reach the model on the next turn. SubagentStop's payload lists running
# agents, each with its own agent_type, in background_tasks after the
# top-level fields, so the script reads each field's first value.
# Payloads shaped like the host's are piped into the script under sh, and
# under dash and bash where installed, in a temp git repo, against the
# synthetic transcripts in tests/fixtures/ledger/ (real ones carry the
# user's identity). Each line it appends must equal the record computed here
# with a JSON parser: exact token sums, a message split across lines counted
# once, escaped JSON in tool output ignored, the first heading of each log
# append, and elapsed seconds across a month boundary. When the final message
# lands 0.5 s after the hook starts, at SubagentStop or at Stop, the hook is
# still waiting then and its line counts that message. It records squad
# agents always, other agents only while the log is non-empty, the main
# session's total with each, and Stop only for a session already in the
# ledger. The run ID is the log's, or the newest archive's once the log is
# empty. It prints nothing and exits 0 on every input, malformed included.
# Last, the end-of-run command in SKILL.md's Hard rules, run on that ledger,
# prints the run's subagent lines and then its last main line.
LEDGER = "skills/compute-squad/hooks/usage-ledger.sh"
LEDGER_COMMAND = 'sh "${CLAUDE_PLUGIN_ROOT}/' + LEDGER + '"'
LEDGER_FIXTURES = "tests/fixtures/ledger/"
LEDGER_KEYS = [
    "v", "run", "session", "agent", "agent_id", "models", "started", "stopped", "elapsed_s", "calls",
    "input", "cache_write", "cache_write_1h", "cache_read", "output", "entries",
]
for path in (LEDGER, LEDGER_FIXTURES + "agent.jsonl", LEDGER_FIXTURES + "main.jsonl"):
    if path not in tracked_set:
        fail(f"{path} is not tracked")
ledger_source = read(LEDGER)
if re.search(r"\b(?:python3?|jq)\b", ledger_source):
    fail(f"{LEDGER} calls python or jq; the hook stays POSIX sh with git, sed, awk, and grep")
target_match = re.search(r'^ledger="\$root/([^"]+)"$', ledger_source, re.MULTILINE)
if not target_match:
    fail(f"{LEDGER}: no ledger=\"$root/<path>\" line")
LEDGER_TARGET = target_match.group(1)
for path in (SKILL, "README.md"):
    if LEDGER_TARGET not in read(path):
        fail(f"{path} does not name {LEDGER_TARGET}, where {LEDGER} writes")
plugin_hooks = json.loads(read(CLAUDE_PLUGIN)).get("hooks", {})
for event in ("SubagentStop", "Stop"):
    wired = [
        entry for entry in plugin_hooks.get(event, [])
        if LEDGER_COMMAND in [h.get("command") for h in entry.get("hooks", []) if h.get("type") == "command"]
    ]
    if len(wired) != 1 or "matcher" in wired[0]:
        fail(f"{CLAUDE_PLUGIN}: hooks.{event} must run {LEDGER_COMMAND!r} once, with no matcher")
end_match = re.search(r"print this run's records with `([^`]+)`", read(SKILL))
if not end_match or "<run ID>" not in end_match.group(1) or LEDGER_TARGET not in end_match.group(1):
    fail(f"{SKILL}: the usage rule must print this run's records with a command that names <run ID> and {LEDGER_TARGET}")
END_COMMAND = end_match.group(1)


def transcript_record(path, run, session, agent, agent_id):
    """The ledger line for one transcript, computed with a JSON parser."""
    calls, models, stamps, heads, lines = {}, [], [], [], 0
    for raw in read(path).splitlines():
        line = json.loads(raw)
        if isinstance(line.get("timestamp"), str):
            stamps.append(line["timestamp"])
        message = line.get("message")
        if line.get("type") != "assistant" or not isinstance(message, dict) or "usage" not in message:
            continue
        lines += 1
        usage = message["usage"]
        calls[message["id"]] = (
            usage.get("input_tokens", 0), usage.get("cache_creation_input_tokens", 0),
            usage.get("cache_creation", {}).get("ephemeral_1h_input_tokens", 0),
            usage.get("cache_read_input_tokens", 0), usage.get("output_tokens", 0),
        )
        if message["model"] not in models:
            models.append(message["model"])
        for block in message["content"]:
            if block.get("type") == "tool_use" and block.get("name") == "Bash":
                command = block["input"].get("command", "")
                if ">> COMPUTE_SQUAD_LOG.md" in command:
                    heads.append(next(l for l in command.split("\n") if l.startswith("## ")))
    if lines <= len(calls) or stamps[0][5:7] == stamps[-1][5:7]:
        fail(f"{path} must split a message across lines and cross a month boundary, so 8f tests both")
    sums = [sum(call[i] for call in calls.values()) for i in range(5)]
    start, stop = (datetime.datetime.strptime(s[:19], "%Y-%m-%dT%H:%M:%S") for s in (stamps[0], stamps[-1]))
    return dict(zip(LEDGER_KEYS, [
        1, run, session, agent, agent_id, ",".join(models), stamps[0], stamps[-1],
        int((stop - start).total_seconds()), len(calls), *sums, "; ".join(heads),
    ]))


if "msg_trap" not in read(LEDGER_FIXTURES + "agent.jsonl"):
    fail(f"{LEDGER_FIXTURES}agent.jsonl must quote transcript JSON in tool output (msg_trap), which the ledger ignores")
agent_fixture = os.path.abspath(LEDGER_FIXTURES + "agent.jsonl")
main_fixture = os.path.abspath(LEDGER_FIXTURES + "main.jsonl")
ledger_path = os.path.abspath(LEDGER)
ledger_env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
ledger_shells = [sh for sh in ("sh", "dash", "bash") if shutil.which(sh)]
if "sh" not in ledger_shells:
    fail("check 8f needs sh, which runs the hook on every host")
SESSION, OTHER_SESSION = "00000000-0000-4000-8000-00000000000a", "00000000-0000-4000-8000-00000000000b"
RUN, OLD_RUN = "2026-02-28-reset-cooldown", "2026-02-27-older-run"


def ledger_payload(event, cwd, session=SESSION, agent_type=None, agent_path=agent_fixture, main_path=main_fixture,
                   style="compact"):
    """A hook payload with the host's key order; SubagentStop's names another agent last in background_tasks
    and quotes an agent_type in its last message."""
    data = {"session_id": session, "transcript_path": main_path, "cwd": cwd, "prompt_id": "p",
            "permission_mode": "acceptEdits"}
    if event == "SubagentStop":
        other = "compute-squad:squad-helper" if agent_type == "general-purpose" else "general-purpose"
        data.update({
            "agent_id": "a0f1e2d3c4b5a6978", "agent_type": agent_type, "hook_event_name": event,
            "stop_hook_active": False, "agent_transcript_path": agent_path,
            "last_assistant_message": 'Done. The log says "agent_type":"compute-squad:squad-pm".',
            "background_tasks": [
                {"id": "a0f1e2d3c4b5a6978", "type": "subagent", "status": "running", "description": "d",
                 "agent_type": agent_type},
                {"id": "b1c2d3e4f5a6b7c80", "type": "subagent", "status": "running", "description": "o",
                 "agent_type": other},
            ],
            "session_crons": [],
        })
    else:
        data.update({"hook_event_name": event, "stop_hook_active": False, "last_assistant_message": "done",
                     "background_tasks": [], "session_crons": []})
    return json.dumps(data, separators=(" , ", " : ") if style == "spaced" else (",", ":"))


def run_ledger(shell, payload, cwd):
    run = subprocess.run([shell, ledger_path], input=payload, capture_output=True, text=True, env=ledger_env,
                         cwd=cwd, timeout=60)
    if run.returncode != 0 or run.stdout or run.stderr:
        fail(f"{LEDGER} under {shell} must print nothing and exit 0; exit {run.returncode}, stdout "
             f"{run.stdout!r}, stderr {run.stderr!r}, for {payload[:160]!r}")


def run_ledger_late(shell, payload, cwd, path, source):
    """Run the hook while path holds source up to its final message, and append that message 0.5 s later: the
    host flushes transcript writes every 100 ms, so the last message can land after the event fires."""
    lines = read(source).splitlines(keepends=True)
    final = [json.loads(line)["message"]["id"] for line in lines if json.loads(line).get("type") == "assistant"][-1]
    cut = next(i for i, line in enumerate(lines) if f'"id":"{final}"' in line)
    with open(path, "w", encoding="utf-8") as handle:
        handle.writelines(lines[:cut])
    proc = subprocess.Popen([shell, ledger_path], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, env=ledger_env, cwd=cwd)
    proc.stdin.write(payload)
    proc.stdin.close()
    time.sleep(0.5)
    waited = proc.poll() is None
    with open(path, "a", encoding="utf-8") as handle:
        handle.writelines(lines[cut:])
    out, err = proc.stdout.read(), proc.stderr.read()
    code = proc.wait(timeout=60)
    if not waited or code != 0 or out or err:
        fail(f"{LEDGER} under {shell} must wait while the transcript's last assistant record ends in a tool call, "
             f"then print nothing and exit 0; still running at 0.5 s: {waited}, exit {code}, stdout {out!r}, "
             f"stderr {err!r}")


def ledger_records(repo):
    path = os.path.join(repo, LEDGER_TARGET)
    if not os.path.exists(path):
        return []
    records = []
    for line in read(path).splitlines():
        try:
            record = json.loads(line)
        except ValueError:
            fail(f"{LEDGER} wrote a line that is not JSON: {line!r}")
        if list(record) != LEDGER_KEYS:
            fail(f"{LEDGER} wrote keys {list(record)!r}; expected {LEDGER_KEYS!r}")
        records.append(record)
    return records


ledger_runs = 0
with tempfile.TemporaryDirectory() as tmp:
    empty = os.path.join(tmp, "empty.jsonl")
    open(empty, "w").close()
    malformed = [
        "", "not json", '{"hook_event_name":"PreToolUse","cwd":"."}',
        '{"hook_event_name":"SubagentStop","agent_type":"compute-squad:squad-pm"',
    ]
    for shell in ledger_shells:
        repo = os.path.join(tmp, shell, "repo")
        sub = os.path.join(repo, "src", "deep")
        os.makedirs(sub)
        subprocess.run(["git", "init", "-q", repo], check=True, env=ledger_env)
        log = os.path.join(repo, "COMPUTE_SQUAD_LOG.md")
        archive = os.path.join(repo, os.path.dirname(LEDGER_TARGET))
        expected = []

        def step(label, payload, cwd, *new):
            global ledger_runs
            run_ledger(shell, payload, cwd)
            ledger_runs += 1
            expected.extend(new)
            got = ledger_records(repo)
            if got != expected:
                fail(f"{LEDGER} under {shell}, {label}: the ledger holds\n{got!r}\nexpected\n{expected!r}")

        def rec(path, run, agent, agent_id, session=SESSION):
            return transcript_record(path, run, session, agent, agent_id)

        main_rec = lambda run: rec(main_fixture, run, "main", "main")
        # No log: another agent and Stop record nothing and create nothing.
        step("a general-purpose agent with no log", ledger_payload("SubagentStop", repo, agent_type="general-purpose"), tmp)
        step("Stop with no ledger", ledger_payload("Stop", repo), tmp)
        if os.path.exists(archive):
            fail(f"{LEDGER} under {shell} created {archive} for an agent outside a squad run")
        # A squad agent is recorded with no log (the intern at Stage 1), then
        # against the log's Run: line, from a subdirectory, under either spelling.
        step("squad-mech with no log or archive", ledger_payload("SubagentStop", repo, agent_type="compute-squad:squad-mech"),
             tmp, rec(agent_fixture, "", "squad-mech", "a0f1e2d3c4b5a6978"), main_rec(""))
        with open(log, "w", encoding="utf-8") as handle:
            handle.write(f"## Goal — Locked\nTimestamp: 2026-02-28T23:58:10Z\nRun: {RUN}\n\n## Status\nRun: {RUN}\n\n")
        step("squad-recon from a subdirectory, with another agent last in background_tasks",
             ledger_payload("SubagentStop", sub, agent_type="compute-squad:squad-recon", style="spaced"), tmp,
             rec(agent_fixture, RUN, "squad-recon", "a0f1e2d3c4b5a6978"), main_rec(RUN))
        # The final message reaches the transcript after the event fires: the
        # hook waits for it, for an agent at SubagentStop and for the main
        # session at Stop.
        late = os.path.join(tmp, shell, "late.jsonl")
        run_ledger_late(shell, ledger_payload("SubagentStop", repo, agent_type="compute-squad:squad-executor",
                                              agent_path=late), tmp, late, agent_fixture)
        ledger_runs += 1
        expected.extend([rec(agent_fixture, RUN, "squad-executor", "a0f1e2d3c4b5a6978"), main_rec(RUN)])
        run_ledger_late(shell, ledger_payload("Stop", repo, main_path=late), tmp, late, main_fixture)
        ledger_runs += 1
        expected.append(main_rec(RUN))
        if ledger_records(repo) != expected:
            fail(f"{LEDGER} under {shell}, final messages flushed after the event: the ledger holds\n"
                 f"{ledger_records(repo)!r}\nexpected\n{expected!r}")
        # Another agent (an audit finder) is recorded while the log is non-empty.
        step("a general-purpose agent during a run", ledger_payload("SubagentStop", repo, agent_type="general-purpose"),
             tmp, rec(agent_fixture, RUN, "general-purpose", "a0f1e2d3c4b5a6978"), main_rec(RUN))
        step("Stop for a session in the ledger", ledger_payload("Stop", repo), tmp, main_rec(RUN))
        step("Stop for another session", ledger_payload("Stop", repo, session=OTHER_SESSION), tmp)
        # Once a PASS clears the log, the run ID comes from the newest archive.
        for name, run_id, stamp in (("older", OLD_RUN, 1000000000), ("newer", RUN, 2000000000)):
            path = os.path.join(archive, f"COMPUTE_SQUAD_LOG_2026-02-28_000000_{name}.md")
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(f"## Goal — Locked\nRun: {run_id}\n")
            os.utime(path, (stamp, stamp))
        open(log, "w").close()
        step("a general-purpose agent after the log is cleared",
             ledger_payload("SubagentStop", repo, agent_type="general-purpose"), tmp)
        step("squad-pm after the log is cleared", ledger_payload("SubagentStop", repo, agent_type="compute-squad:squad-pm"),
             tmp, rec(agent_fixture, RUN, "squad-pm", "a0f1e2d3c4b5a6978"), main_rec(RUN))
        # Unreadable input and missing or empty transcripts write nothing.
        for bad in malformed:
            step(f"malformed input {bad!r}", bad, tmp)
        step("missing transcripts", ledger_payload("SubagentStop", repo, agent_type="compute-squad:squad-pm",
                                                   agent_path=os.path.join(tmp, "gone.jsonl"),
                                                   main_path=os.path.join(tmp, "gone.jsonl")), tmp)
        step("empty transcripts", ledger_payload("SubagentStop", repo, agent_type="compute-squad:squad-pm",
                                                 agent_path=empty, main_path=empty), tmp)
        # The end-of-run command prints this run's subagent lines, then its last main line.
        with open(os.path.join(repo, LEDGER_TARGET), "a", encoding="utf-8") as handle:
            handle.write(json.dumps(dict(main_rec(OLD_RUN), output=1), separators=(",", ":")) + "\n")
        lines = read(os.path.join(repo, LEDGER_TARGET)).splitlines()
        mine = [line for line in lines if f'"run":"{RUN}"' in line]
        want = [line for line in mine if '"agent":"main"' not in line] + [
            [line for line in mine if '"agent":"main"' in line][-1]]
        printed = subprocess.run([shell, "-c", END_COMMAND.replace("<run ID>", RUN)], capture_output=True, text=True,
                                 cwd=repo, env=ledger_env, timeout=60)
        if printed.returncode != 0 or printed.stdout.splitlines() != want:
            fail(f"{SKILL}'s end-of-run command under {shell} printed\n{printed.stdout}{printed.stderr}\nexpected\n"
                 + "\n".join(want))

print(
    f"PASS: check 8: {LEDGER} is wired once, with no matcher, for SubagentStop and Stop in {CLAUDE_PLUGIN} and "
    f"ran {ledger_runs} times as specified under {', '.join(ledger_shells)} on {LEDGER_FIXTURES}: exact token "
    f"sums with split messages counted once, a final message flushed after the event waited for, squad agents "
    f"always, other agents only during a run, Stop only for "
    f"a session in the ledger, the run ID from the log or the newest archive, silent on every input; "
    f"{SKILL}'s end-of-run command prints the run's lines"
)
PYEOF

# ---------------------------------------------------------------------------
# Check 9: staleness. A dated claim about models or prices goes stale with no
# file changing. models.conf's reviewed date, and each "Snapshot YYYY-MM-DD"
# in README.md and codex/README.md, older than 90 days prints a warning and
# never fails: a new model is not a defect in this repo. The weekly
# model-currency job in .github/workflows/ci.yml fails instead, through
# codex/build-agents.py --validate-catalog --strict.
# ---------------------------------------------------------------------------
python3 <<'PYEOF'
import datetime
import json
import re
import subprocess
import sys

LIMIT_DAYS = 90
SNAPSHOT_FILES = ("README.md", "codex/README.md")

parsed = subprocess.run(
    [sys.executable, "codex/build-agents.py", "--parse-manifest", "models.conf"],
    capture_output=True, text=True,
)
if parsed.returncode != 0:
    print(f"FAIL: check 9: models.conf does not parse:\n{parsed.stderr}", file=sys.stderr)
    sys.exit(1)
dated = [("models.conf reviewed", json.loads(parsed.stdout)["reviewed"])]
for path in SNAPSHOT_FILES:
    with open(path, encoding="utf-8") as f:
        for number, line in enumerate(f, 1):
            for date in re.findall(r"\bSnapshot ([0-9]{4}-[0-9]{2}-[0-9]{2})\b", line):
                dated.append((f"{path}:{number} Snapshot", date))

today = datetime.datetime.now(datetime.timezone.utc).date()
stale = []
for what, date in dated:
    try:
        age = (today - datetime.date.fromisoformat(date)).days
    except ValueError:
        print(f"FAIL: check 9: {what} {date} is not a calendar date", file=sys.stderr)
        sys.exit(1)
    if age > LIMIT_DAYS:
        stale.append(what)
        print(
            f"WARN: check 9: {what} {date} is {age} days old, over {LIMIT_DAYS}; re-check what it claims "
            "(Changing models in CONTRIBUTING.md) and update the date",
            file=sys.stderr,
        )
if stale:
    print(f"PASS: check 9: {len(stale)} of {len(dated)} dated claims are over {LIMIT_DAYS} days old (warning only)")
else:
    print(f"PASS: check 9: {len(dated)} dated claims ({', '.join(w for w, _d in dated)}) are at most {LIMIT_DAYS} days old")
PYEOF

echo "verify.sh: all checks passed"
