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
#      files; 7c the helper cap, and the audit's skeptic cap with the rest of
#      finding 20's audit text; 7d each of the four files with a generated
#      routing block has one begin and one end marker; 7e the product
#      description; 7f the ## Status and ## Decision templates in SKILL.md
#      and codex/README.md; 7g the PM's criteria block in both SKILL.md
#      files, the PM body, and its Codex prompt, with the Result values the
#      log linter checks; 7h the high-stakes review: its template in SKILL.md
#      and codex/README.md, the PM's archive-nothing step, squad-mech's close
#      guard, the example's review, and no trace of the main session
#      clearing the log itself; 7i log headings stay on SKILL.md's closed list,
#      whose bullet carries the (cont.) rule, and every log template carries
#      the routing fields the log linter checks; 7j the archive command; 7l
#      protocol text names rungs, not models, outside the routing block; 7m the three executor bodies are one
#      protocol apart from each agent's own name and the MECHANICAL stop line;
#      7o no file names the deleted routing
#      reference; 7p the shared-span table, whose rows include the blocker
#      grammar span (7k), the command output forms (7n), the latest-Goal
#      read, the rule that changing a criterion's command redefines the
#      criterion, and finding 9's (cont.), plan-read, verdict-scope,
#      attempt, routing, and FAIL-count text, squad-mech's open-run guard,
#      finding 13's Answers: sentence in every stage body, and finding 5's
#      precedence sentences, final-message forms, Stage 0 bound, spawn
#      pointer, and route grep, finding 18's per-spawn-or-continuation
#      rule and output caps, and finding 20's audit ruling in ACCEPT; 7q the agent
#      description budget; 7r no agent has a tool to spawn agents; 7s
#      codex/SKILL.md stays a reading copy and both SKILL.md files carry the
#      no-absorption rule; 7t no file names a renamed executor or the old
#      escalation wording, and both SKILL.md files carry the FAIL charge rule
#      and the setup-gap stop; 7u no file under agents/, codex/, or skills/
#      reads the goal from the entry at the top of the log; 7v the resume
#      table in references/resume.md routes from every stage heading, both
#      SKILL.md files point a resume at it and carry the one-active-run rule,
#      and squad-mech's open-run guard is in its body, prompt, and TOML; 7w
#      the Recon and Executor templates carry the labels the log linter
#      checks, and the PLAN template a Totals: line; 7x Recon checks the
#      evidence prerequisites, its template's Checks: block matches the
#      linter's forms, PLAN starts from it and reconciles its counts, and no
#      stage keeps the old one-carve-out Bash rule; 7y both SKILL.md files
#      bound Stage 0's reads, give every stage a pointer spawn prompt, and
#      route from the log with a grep that names every routing field the
#      log linter checks, and no stage ends with a summary final message; 7z
#      small work stays in-stage, a BLOCKING requester is continued before it
#      is re-spawned, and every DELEGATE: subtask caps its helper's output.
#   8. Behavior without a model, on fixtures under tests/: log grammar,
#      including the grant hook's verdict on every Executor entry, the
#      re-lock record, the stop at a needs-human blocker, and the routing
#      fields, attempt numbers, governing plan revision, high-stakes line,
#      and (cont.) rule, the numbered criteria and every verdict's criteria
#      block, waivers, top-rung parity, entry labels, Executor points, plan
#      totals, the high-stakes review's place, Rerun: line, and close, the
#      Answers: line of every re-run, the Recon entry's goal-facts and
#      baseline lines, DELEGATE: and BLOCKER: lines at column 0, where
#      the route grep finds them, every DELEGATE: subtask's output cap,
#      which the Delegated entries answering it keep to, and the audit's
#      ## Audit Findings entry, skeptic cap, and PM rulings, over every
#      fixture log and over the verdicts a live
#      seed lists as outcomes, S5's among them (8a), the next action
#      references/resume.md gives
#      for every fixture log under the states its .expect.json names, with
#      every row, step, and check exercised, each live scenario's repo as
#      tests/live/run.sh --setup-only builds it giving its static twin's
#      state and action, the live S5 check's verdict rule agreeing with
#      those outcomes, the rules of the live checks that read the hook log
#      and the usage ledger (S8's Stage 0 bound and main-session budget,
#      S9's skeptic cap) agreeing with the cases in tests/fixtures/live/,
#      every claude call run.sh prints carrying the hook log, and
#      squad-mech's open-run guard agreeing with the
#      one-active-run rule (8b), the
#      grant hook's decisions on synthetic PreToolUse JSON and over the live
#      seed logs, including its hold on every stage agent except squad-mech
#      while a needs-human blocker is open (8c), the archive command in temp
#      dirs, which must copy exactly, clear only after cmp (keeping the log
#      when a cmp shim fails), and change nothing on a name collision or an
#      unwritable archive directory, and squad-mech's
#      close guard, which must allow the closing archive only after an upheld
#      high-stakes review, whose entry the archive then holds, with the S6a
#      seed closing only once its review is appended and the S6b seed's
#      colliding archive changing nothing (8d),
#      codex/update.sh with stubs (8e), which must install the plugin,
#      agents, and profiles from one build that carries the account's saved
#      Codex model choices, only from main at origin/main or an approved
#      commit it never pulls, ask for choices only on a terminal, reject a
#      model the catalog does not offer, change nothing in CODEX_HOME when it
#      stops, fail an install that differs from the source, and whose --check
#      must name each difference while writing nothing, and whose catalog
#      validator must apply its effort, retirement,
#      upgrade, and format rules,
#      and the usage ledger hook on synthetic transcripts (8f), whose records
#      must hold exact token sums, including a final message written after
#      the hook starts, and which must print nothing. The live
#      tier, tests/live/run.sh, spends model tokens, so neither this script
#      nor CI runs a scenario live; 8b runs only its --list, --dry-run, and
#      --setup-only modes, which call no model.
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


# codex/update.sh installs, and --check compares, the manifest plus skills/:
# a component path the manifest declares beyond that would be loaded by
# Codex but neither installed from the source nor checked.
def declared_paths(value):
    if isinstance(value, str):
        return [value] if value.startswith("./") else []
    items = value.values() if isinstance(value, dict) else value if isinstance(value, list) else []
    return [path for item in items for path in declared_paths(item)]


declared = {key: declared_paths(value) for key, value in manifest.items() if declared_paths(value)}
if declared != {"skills": ["./skills/"]}:
    fail(
        f".codex-plugin/plugin.json declares component paths {declared!r}; codex/update.sh and its --check cover "
        "only ./skills/, so extend codex/build-agents.py --render-codex before adding another"
    )

print(
    f"PASS: check 6: models.conf parses and holds the routing policy on both hosts, {len(malformed)} malformed "
    f"copies fail to parse, the {len(actual)} Codex agent TOMLs and 5 manual prompts are valid, "
    f"codex/build-agents.py --check finds every generated file in sync, and .codex-plugin/plugin.json declares "
    f"no component path but ./skills/"
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

# ---- 7c: the caps. The "5 helpers per stage per run" cap names the same
# digit everywhere it's restated: the shared skill, the reading copy, the
# README, and each stage body that can delegate. The audit's skeptic cap
# follows below.
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

# The audit's skeptic cap (finding 20) names one number everywhere it is
# stated: the procedure and the ## Audit Findings template in
# references/audit-prompts.md, whose template the log linter reads, and the
# audit sections of both SKILL.md files. The rest of finding 20 stays in
# place: the entry's heading and its UNREVIEWED and NEEDS-HUMAN verdicts in
# SKILL.md, the brief, and the PM body and its Codex prompt; the procedure's
# spawn type, scope read, severity field, and no-writes rule; the skeptic's
# production-only security verdict beside the concurrency and accessibility
# carve-out; SKILL.md's routing of each verdict; the Codex reading copy's
# pointer to the procedure; and README's tree comment. No file keeps the old
# rule that only skeptic-confirmed findings count.
AUDIT_PROMPTS = "skills/compute-squad/references/audit-prompts.md"
AUDIT_CAP_FORMS = {
    AUDIT_PROMPTS: (r"for at most ([0-9]+) findings\. The rest are UNREVIEWED\.",
                    r"^Findings: <n>; skeptics run: <k> \(cap ([0-9]+)\)$"),
    "skills/compute-squad/SKILL.md": (r"attempt to refute each finding, for at most ([0-9]+) findings\.",),
    "codex/SKILL.md": (r"one fresh top-rung skeptic per finding, for at most ([0-9]+) findings; the rest are UNREVIEWED\.",),
}
audit_caps = {}
for path, forms in AUDIT_CAP_FORMS.items():
    text = " ".join(read(path).split()) if path != AUDIT_PROMPTS else read(path)
    for form in forms:
        found = re.findall(form, text, re.MULTILINE)
        if len(found) != 1:
            fail(f"{path}: needs exactly one audit skeptic cap reading {form!r}; found {len(found)}")
        audit_caps[f"{path} ({form.split('(')[0].strip('^ ')})"] = found[0]
if len(set(audit_caps.values())) != 1:
    fail(f"the audit skeptic cap differs between files: {audit_caps!r}")
audit_cap = next(iter(audit_caps.values()))
AUDIT_TEXT = {
    AUDIT_PROMPTS: (
        "## Audit Findings", "UNREVIEWED", "NEEDS-HUMAN",
        f"at most {audit_cap} findings",
        "whose reproduction needs credentials",
        "Spawn finders and skeptics as the host's general-purpose agent type, never as a squad agent",
        "every finder reads the locked record: `awk '/^## /{p = /^## (Goal|Recon|PM — Plan)/} p' COMPUTE_SQUAD_LOG.md`",
        "severity: <high | medium | low>",
        "Order the findings by severity, high first, then by finder number.",
        "If the output differs from step 1, stop, append nothing, and report the change to the user.",
        "Finders and skeptics change nothing: no file edits, no commits, no log entries.",
        "For concurrency findings (races, unserialized concurrent writes) and accessibility findings (keyboard "
        "operability, ARIA, focus order): failure to reproduce is not refutation.",
        "return `NEEDS-HUMAN` with what reproduction would need, never `REFUTED`.",
        "First read the locked goal:",
    ),
    "skills/compute-squad/SKILL.md": (
        "## Audit Findings", "UNREVIEWED", "NEEDS-HUMAN",
        "following the procedure in `references/audit-prompts.md`, and records the result in one `## Audit Findings` "
        "entry.",
        "CONFIRMED and UNREVIEWED findings are FAIL evidence, a NEEDS-HUMAN finding stops for the user, and a REFUTED "
        "finding is not evidence.",
        "That stop runs through the PM:",
        "it rules on every CONFIRMED, UNREVIEWED, and NEEDS-HUMAN finding the entry lists",
        "an audit whose `git status --porcelain` changed (`references/audit-prompts.md` step 4)",
    ),
    "agents/squad-pm.md": ("## Audit Findings", "UNREVIEWED", "NEEDS-HUMAN"),
    "codex/05-pm-accept.md": ("## Audit Findings", "UNREVIEWED", "NEEDS-HUMAN"),
    "codex/SKILL.md": (
        "## Audit Findings", "UNREVIEWED", "NEEDS-HUMAN",
        "Follow the procedure in `skills/compute-squad/references/audit-prompts.md`.",
        "CONFIRMED and UNREVIEWED findings are FAIL evidence, a NEEDS-HUMAN finding stops for the user, and a REFUTED "
        "finding is not evidence.",
        "The PM rules on every CONFIRMED, UNREVIEWED, and NEEDS-HUMAN finding the entry lists",
    ),
    "skills/compute-squad/references/resume.md": ("| `## Audit Findings` | Spawn `squad-pm` in ACCEPT mode. |",),
    "README.md": ("audit-prompts.md  # audit procedure, finder and skeptic briefs",),
}
for path, needed in AUDIT_TEXT.items():
    flat = " ".join(read(path).split())
    missing = [text for text in needed if " ".join(text.split()) not in flat]
    if missing:
        fail(f"{path}: missing the audit text (finding 20) {missing!r}")
OLD_AUDIT_RULE = re.compile(r"only (?:skeptic-confirmed|skeptic-CONFIRMED|findings that survive refutation) (?:findings )?"
                            r"counts?", re.IGNORECASE)
stale = [path for path in tracked_files("agents", "codex", "skills", "README.md", "docs")
         if OLD_AUDIT_RULE.search(" ".join(read(path).split()))]
if stale:
    fail(f"these files keep the old audit rule that only skeptic-confirmed findings count: {stale!r}")

print(
    f"PASS: check 7: the audit skeptic cap reads '{audit_cap}' in {', '.join(AUDIT_CAP_FORMS)}, and finding 20's "
    f"procedure, entry, verdicts, and PM ruling are in {', '.join(AUDIT_TEXT)}"
)

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

# ---- 7g: the criteria block (finding 2). Every PASS and FAIL entry carries
# one block: a Tested: line naming the tree, a table with one row per
# criterion ID, then Regressions:, Outside scope:, and Executor points:
# (finding 16). SKILL.md and its reading copy carry it as a bare-fenced block
# that opens with the Tested: line; the PM body and its generated Codex prompt
# carry the same lines inside the ACCEPT template's heredoc. All four match
# byte for byte. The PM files state the Result values and the question a
# pre-existing failure puts to the user, all four say what a PASS means, the
# log linter's Result values are the PM's, and both SKILL.md files number the
# Goal template's criteria (7a holds the template's three copies alike).
CRITERIA_OPEN = "Tested: <commit SHA>, working tree <clean | N changed files>"
CRITERIA_SKILLS = ["skills/compute-squad/SKILL.md", "codex/SKILL.md"]
CRITERIA_PM = ["agents/squad-pm.md", "codex/05-pm-accept.md"]
LOG_HEREDOC = "cat >> COMPUTE_SQUAD_LOG.md <<'EOF'"
criteria_blocks = {path: extract_fenced_block(read(path), path, "```", CRITERIA_OPEN) for path in CRITERIA_SKILLS}
for path in CRITERIA_PM:
    lines = read(path).splitlines()
    starts = [i for i, line in enumerate(lines) if line == CRITERIA_OPEN]
    if len(starts) != 1:
        fail(f"{path}: needs the line {CRITERIA_OPEN!r} exactly once, in the ACCEPT template; found {len(starts)}")
    opened = max((i for i in range(starts[0]) if lines[i] == LOG_HEREDOC), default=None)
    if opened is None or "EOF" in lines[opened:starts[0]]:
        fail(f"{path}: the criteria block must sit inside the ACCEPT template's {LOG_HEREDOC!r} heredoc")
    end = starts[0]
    while end < len(lines) and lines[end].strip():
        end += 1
    criteria_blocks[path] = lines[starts[0]:end]
ref_path = CRITERIA_SKILLS[0]
for path, block in criteria_blocks.items():
    if block != criteria_blocks[ref_path]:
        fail(f"{path}: the criteria block differs from {ref_path}'s: {block!r}")
if not any(line.startswith("Executor points:") for line in criteria_blocks[ref_path]):
    fail(f"{ref_path}: the criteria block has no Executor points: line (finding 16)")
CRITERIA_TEXT = {
    "Result is exactly one of": CRITERIA_PM,
    "needs-human: waive or re-scope <ID>": CRITERIA_PM,
    "PASS means local acceptance of the tested tree": CRITERIA_PM + CRITERIA_SKILLS,
    "numbered AC1, AC2, and so on": CRITERIA_SKILLS,
    "- AC1: <concrete, verifiable item>": CRITERIA_SKILLS,
}
for needed, paths in CRITERIA_TEXT.items():
    for path in paths:
        if needed not in " ".join(read(path).split()):
            fail(f"{path}: missing {needed!r}")
sys.dont_write_bytecode = True
sys.path.insert(0, "tests")
import check_logs  # noqa: E402
result_sentence = re.search(r"Result is exactly one of (.+?)\. ", " ".join(read(CRITERIA_PM[0]).split()))
pm_results = re.findall(r"`([^`]+)`", result_sentence.group(1)) if result_sentence else []
if sorted(pm_results) != sorted(check_logs.RESULTS):
    fail(f"{CRITERIA_PM[0]} gives the Result values {pm_results!r}, but tests/check_logs.py lints {list(check_logs.RESULTS)!r}")

print(
    f"PASS: check 7: the criteria block is byte-identical across {', '.join(criteria_blocks)} (in the PM files, inside "
    f"the ACCEPT template), the PM files state its Result values ({', '.join(pm_results)}) as the log linter does, and "
    f"both SKILL.md files number the Goal template's criteria"
)


# ---- 7h: the high-stakes review (finding 3). On a high-stakes PASS the PM
# archives nothing; the main session reviews the change, appends a
# ## High-stakes review entry, and only an upheld review sends the log to
# squad-mech's closing archive. The review template is byte-identical in
# SKILL.md and codex/README.md (on the manual Codex path the operator writes
# it by hand), the PM body and its Codex prompt stop a high-stakes PASS with
# nothing archived, squad-mech's body and its Codex prompt carry the close
# guard (check 8d runs it), the example log's review has one Tested: line and
# one Result: line, and no file keeps the old flow, in which the main session
# cleared or archived the log itself.
REVIEW_HEADING = "## High-stakes review"
REVIEW_PATHS = ["skills/compute-squad/SKILL.md", "codex/README.md"]
review_blocks = {path: extract_fenced_block(read(path), path, "```markdown", REVIEW_HEADING) for path in REVIEW_PATHS}
for path, block in review_blocks.items():
    if block != review_blocks[REVIEW_PATHS[0]]:
        fail(f"{path}: the {REVIEW_HEADING} template differs from {REVIEW_PATHS[0]}'s: {block!r}")
for path in CRITERIA_PM:
    if "archive nothing and clear nothing" not in " ".join(read(path).split()):
        fail(f"{path}: a high-stakes PASS must 'archive nothing and clear nothing' (finding 3)")
CLOSE_GUARD = "grep '^Result:' COMPUTE_SQUAD_LOG.md | tail -n 1"
for path in ("agents/squad-mech.md", "codex/01-archive.md"):
    if CLOSE_GUARD not in read(path):
        fail(f"{path}: squad-mech's closing archive must first run `{CLOSE_GUARD}`")
example_review = extract_fenced_block(read("docs/example-log.md"), "docs/example-log.md", "```markdown", REVIEW_HEADING)
tested_lines = [line for line in example_review if line.startswith("Tested: ")]
result_lines = [line for line in example_review if re.fullmatch(r"Result: (upheld|overturned|held)", line)]
if len(tested_lines) != 1 or len(result_lines) != 1:
    fail(f"docs/example-log.md: the {REVIEW_HEADING} entry needs one 'Tested: ' line and one 'Result: <upheld|overturned|"
         f"held>' line; found {len(tested_lines)} and {len(result_lines)}")
# The last two are WO-2's interim close, which this flow replaced.
RETIRED_CLOSE = (
    "clear the log yourself", "clears it themselves", "you clear it once", "clears the log afterwards",
    "archived, log kept", "main session's own step",
)
for path in tracked_files("skills", "agents", "codex", "docs", "README.md"):
    flat = " ".join(read(path).split()).lower()
    for phrase in RETIRED_CLOSE:
        if phrase in flat:
            fail(f"{path}: contains {phrase!r}, the old high-stakes close; the log is archived only by squad-mech "
                 f"after an upheld {REVIEW_HEADING}")

print(
    f"PASS: check 7: the {REVIEW_HEADING} template is byte-identical across {', '.join(REVIEW_PATHS)}, the PM files "
    f"archive nothing on a high-stakes PASS, squad-mech carries its close guard, the example's review has one Tested: "
    f"and one Result: line, and no file keeps the old high-stakes close"
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
# fails too. The bullet also carries the (cont.) rule the log linter's cont
# rule enforces, word for word.
HEADING_BULLET = "- Log entries use only these headings: "
HEADING_BAN = "Any other heading or suffix is a protocol violation."
CONT_RULE = (
    ", and only for a stage continuing after its own `BLOCKING` `DELEGATE:` block; that entry covers only the "
    "remainder and extends the stage's latest attempt."
)
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
if not sep or not sep2 or tail != CONT_RULE + " " + HEADING_BAN:
    fail(
        f"{skill_path}: the heading-list bullet must read {HEADING_BULLET!r}<headings>. Only <headings> "
        f"may add `{CONT}`{CONT_RULE} {HEADING_BAN}"
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

# The routing fields (finding 9). tests/check_logs.py holds the table of
# fixed lines each stage entry carries directly under its Agent: line, and
# prints it with --fields. Every log template in agents/*.md and codex/0*.md
# (a cat >> COMPUTE_SQUAD_LOG.md <<'EOF' block) must carry exactly those
# lines, in order, right under its Agent: line, and no other template line
# may start with a routing field. The main session's ## High-stakes review
# template, fenced in SKILL.md and codex/README.md (7h), is held to the same
# table. Every heading in the table needs a template, except the PASS and
# pending entries, which the PM body derives from the FAIL template by the
# two sentences named below, so their fields must be the FAIL fields without
# the ones each sentence drops (Rerun, and for a pending entry High-stakes
# too). Both SKILL.md files route from the Classification: line and count
# FAILs from the Rerun: lines.
HEREDOC_OPEN = "cat >> COMPUTE_SQUAD_LOG.md <<'EOF'"
DERIVED_FROM_FAIL = {
    "## PM — PASS": ("A PASS uses `## PM — PASS` and has no `Rerun:` line.", ("Rerun",)),
    "## PM — Accept (pending)": (
        "A pending entry uses `## PM — Accept (pending)`, has no `High-stakes:` or `Rerun:` line,",
        ("High-stakes", "Rerun"),
    ),
}
FIELD_ROUTE_RULES = (
    "`Classification:` line of the governing plan revision",
    "the number of lines matching `^(Rerun: |- rerun: )`",
)
fields_run = subprocess.run([sys.executable, "tests/check_logs.py", "--fields"], capture_output=True, text=True)
try:
    field_table = json.loads(fields_run.stdout) if fields_run.returncode == 0 else None
except ValueError:
    field_table = None
if not isinstance(field_table, dict) or "## PM — FAIL" not in field_table:
    fail(f"tests/check_logs.py --fields exited {fields_run.returncode} without its routing-field table: {fields_run.stderr.strip()}")
field_names = sorted({name for fields in field_table.values() for name, _ in fields})
for heading in field_table:
    if not heading_on_list(heading):
        fail(f"tests/check_logs.py gives routing fields to {heading!r}, which is not on {skill_path}'s heading list")
templated = {}
log_templates = []
for path in tracked_files("agents/*.md", "codex/0*.md"):
    lines = read(path).splitlines()
    for start in (i for i, line in enumerate(lines) if line == HEREDOC_OPEN):
        block = []
        for line in lines[start + 1:]:
            if line == "EOF":
                break
            block.append(line)
        log_templates.append((path, start, block))
for path in REVIEW_PATHS:
    lines = read(path).splitlines()
    start = next(i for i in range(len(lines) - 1) if lines[i] == "```markdown" and lines[i + 1] == REVIEW_HEADING)
    log_templates.append((path, start, review_blocks[path]))
for path, start, block in log_templates:
    heading = block[0] if block else ""
    agent_at = next((i for i, line in enumerate(block) if line.startswith("Agent: ")), None)
    if not heading.startswith("## ") or agent_at is None:
        fail(f"{path}:{start + 1}: a log template opens with its heading and carries an Agent: line")
    expected = [f"{name}: {placeholder}" for name, placeholder in field_table.get(heading, [])]
    got = block[agent_at + 1:agent_at + 1 + len(expected)]
    if got != expected:
        fail(f"{path}:{start + 1}: the {heading} template's lines under Agent: must be {expected!r}, the FIELDS "
             f"table in tests/check_logs.py; found {got!r}. Change the template and the table together")
    stray = [line for index, line in enumerate(block)
             if not agent_at < index <= agent_at + len(expected)
             and any(line.startswith(name + ": ") for name in field_names)]
    if stray:
        fail(f"{path}:{start + 1}: the {heading} template has routing field lines outside its fixed lines: {stray!r}")
    templated.setdefault(heading, []).append(path)
for heading, fields in field_table.items():
    if heading in templated:
        continue
    sentence, dropped = DERIVED_FROM_FAIL.get(heading, (None, ()))
    if sentence is None or fields != [f for f in field_table["## PM — FAIL"] if f[0] not in dropped]:
        fail(f"no log template in agents/*.md or {', '.join(REVIEW_PATHS)} carries the routing fields "
             f"tests/check_logs.py gives {heading!r}")
    for path in ("agents/squad-pm.md", "codex/05-pm-accept.md"):
        if sentence not in read(path):
            fail(f"{path}: must say {sentence!r}, which defines the {heading} entry from the FAIL template")
for path in (skill_path, "codex/SKILL.md"):
    flat = " ".join(read(path).split())
    missing = [rule for rule in FIELD_ROUTE_RULES if rule not in flat]
    if missing:
        fail(f"{path}: missing the field routing rules {missing!r}")

print(
    f"PASS: check 7: every log heading the protocol writes or names is on {skill_path}'s closed list "
    f"({len(listed_headings)} headings, {len(cont_headings)} with (cont.)), and the log templates in agents/ and "
    f"codex/0*.md carry the routing fields tests/check_logs.py lints ("
    + "; ".join(f"{h}: {', '.join(n for n, _ in f)}" for h, f in field_table.items()) + ")"
)

# ---- 7j: the archive command. Every archive copy is written by the one
# command in SKILL.md's Hard rules: a noclobber copy named from date -u and
# the run ID, verified with cmp, with the clear chained after cmp. The block
# right after that rule is the canonical copy. In every file that runs it,
# the ```bash blocks that name compute-squad-archive must be exactly the
# expected forms: the plain command, or the PM's form (the prefix the rule
# names, then the second line). A high-stakes PASS archives nothing (7h), so
# there is no third form. The read-back and whole-file Write wording it
# replaced must not come back.
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
pm_forms = [[archive_first, prefix_match.group(1) + archive_second]]


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
# Finding 9: a stage continues under (cont.) only after its own BLOCKING
# delegation, and every other re-spawn writes a complete entry; executors
# work the revision and work order the latest Status names; ACCEPT judges
# only that work order and leaves the log open while another one remains;
# the main session routes on the Classification: line and counts FAILs from
# the Rerun: lines. The work-order stop also holds a high-stakes PASS for the
# main session's review (finding 3).
EXECUTOR_PLAN_READ = (
    "Work through the tasks of the plan revision and work order that the latest `## Status` entry names, in order, "
    "and stop at the end of that work order; with no `## Status`, use the latest `## PM — Plan` entry and all its "
    "work orders. Earlier revisions are history, not instructions."
)
VERDICT_SCOPE = (
    "Judge only the plan revision and work order that the latest `## Status` entry names. Earlier revisions are "
    "history, and other work orders are outside this verdict."
)
WORK_ORDER_STOP = (
    "If any line in the log reads `High-stakes: yes`, or the governing plan revision has a work order after the one "
    "you accepted, stop here: archive nothing and clear nothing. Your final message's archive line reads "
    "`No archive.` followed by which: the log awaits the main session's high-stakes review, the run stays open for "
    "the next work order, or both."
)
PLAN_ATTEMPT = (
    "`Attempt: <n>`: n counts the `## PM — Plan` entries without `(cont.)` in the log, this one included; attempt n "
    "is plan revision r<n>."
)
VERDICT_ATTEMPT = (
    "`Attempt: <n>` counts the `## PM — PASS` and `## PM — FAIL` entries in the log, this one included; a pending "
    "entry takes the number of the verdict it waits for."
)
CLASSIFICATION_ROUTE = (
    "route by the `Classification:` line of the governing plan revision, never by the PM's final message. A missing "
    "line, or any value other than these three, routes as COMPLEX:"
)
FAIL_COUNT = (
    "Count FAILs from the log, never from memory: the FAIL total is the number of lines matching "
    "`^(Rerun: |- rerun: )`, and each such line charges one FAIL to the stage it names."
)
# Finding 13: every stage body tells a re-spawned stage what sent it back,
# on its Answers: line, in one sentence (the log linter's answers rule checks
# the line; the PM's ACCEPT section states the verdict form).
ANSWERS_SENTENCE = (
    "On attempt 1, leave the template's `Answers:` line out. From attempt 2 on, write `Answers:` directly under your "
    "`Attempt:` line, naming by heading and timestamp what sent "
    "this stage back: the latest `## PM — FAIL` or overturned `## High-stakes review` whose `Rerun:` line names this "
    "stage, the latest `BLOCKER:` whose `rerun:` line names it, or the `## Decision` that resolved your own "
    "`needs-human:` blocker. If this stage re-runs only because an earlier stage did, name what sent that stage back; "
    "if it re-runs for a moved base commit, name the latest `## Status`. Closing what it names is your first objective; "
    "then complete the rest of the work in full."
)
# Finding 11: squad-mech refuses to archive a log whose latest Next: line is
# open, so a second run cannot truncate a live one (check 8b runs the guard).
OPEN_RUN_GUARD_SPAN = (
    "When told a new run is starting, first run `grep '^Next: ' COMPUTE_SQUAD_LOG.md | tail -n 1`. If it prints a "
    "line other than `Next: none`, change nothing and report `ARCHIVE REFUSED: open run` followed by that line."
)
# Finding 5: the main session routes from the log, so a stage's final message
# only points at its entry, and every spawn prompt is a pointer in one form.
# The main session reads product source only from Recon on, and after every
# spawn it greps the log's headings, fixed lines, and blocks (7y ties the grep
# to the linter's field table).
FINAL_MESSAGE = (
    "Then end with a final message of at most three lines: the heading you appended, then the first line of each "
    "`DELEGATE:` or `BLOCKER:` block your entry ends with, or `No DELEGATE or BLOCKER block.` Do not restate the entry."
)
ACCEPT_FINAL_MESSAGE = (
    "End every ACCEPT run with a final message of at most five lines: the heading you appended, the first line of any "
    "`DELEGATE:` or `BLOCKER:` block your entry ends with, the archive path and the result of the check that verified "
    "it (or `No archive.`), and whether you cleared the log. That verified confirmation belongs in this message, not "
    "in the log: the append-only `## PM — PASS` entry only ever states the archive target as intent, since it is "
    "written before the copy exists."
)
STAGE0_BOUND = (
    "Stage 0 reads only what finding gaps in the goal needs: the user's request, the project instructions already in "
    "context, the README, at most one directory listing, files the user named, and `COMPUTE_SQUAD_LOG.md` for the "
    "checks above. It never reads product source to map it, never runs tests or builds, and never lists files or "
    "questions for Recon; mapping and the baseline run are Recon's."
)
SPAWN_POINTER = "\n".join((
    "```",
    "Stage: <Archive|Recon|Plan|Execute|Accept>",
    "Mode: <PLAN|ACCEPT|close|none>",
    "Repo root: <absolute path>",
    "Log: COMPUTE_SQUAD_LOG.md, run <Run of the latest ## Status entry, or none>",
    "Since your last spawn: <new run | first spawn | the headings appended since your last entry>",
    "```",
))
ROUTE_GREP = (
    "grep -n -E '^(## |DELEGATE:|BLOCKER:|Attempt: |Answers: |Plan: |Classification: |High-stakes: |Rerun: |Result: )' "
    "COMPUTE_SQUAD_LOG.md | tail -n 12"
)
# Finding 18: every DELEGATE: subtask caps what its helper returns, and the
# helpers keep to the cap (8a's delegate-cap rule holds logs to it; 7z holds
# the rest of the delegation text).
DELEGATION_CAP = "Each subtask names the most output lines the helper may return (`return at most <N> lines`)."
HELPER_OUTPUT_CAP = (
    "If the procedure caps the output, return at most that many lines of it (the last ones, for command output) and "
    "say how many lines you cut."
)
# Finding 20: ACCEPT rules on every audit finding the PM must answer for
# (8a's audit-ruling rule holds verdicts to it; 7c holds the rest).
AUDIT_RULING = (
    "If an `## Audit Findings` entry follows the Executor entry you are judging, name every CONFIRMED, UNREVIEWED, and "
    "NEEDS-HUMAN finding in the latest one with your ruling in your verdict entry. A CONFIRMED finding is FAIL evidence "
    "unless you quote the Out of scope or criterion text of the latest `## Goal — Locked` entry that places it outside "
    "the goal; a defect this change introduced is never outside it. An UNREVIEWED finding is FAIL evidence until you "
    "refute it yourself. A NEEDS-HUMAN finding you cannot settle by showing the guard goes into a "
    "`## PM — Accept (pending)` entry ending with a `BLOCKER:` block (`needs-human: <what reproduction needs>`), never "
    "into a PASS. You may reopen a REFUTED finding whose only reason is that it did not reproduce."
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
    span_row("per-spawn", BODIES + CODEX_STAGE_PROMPTS, text="The one-entry rule is per spawn or continuation."),
    span_row("cont only after BLOCKING", BODIES + CODEX_STAGE_PROMPTS, canon="agents/squad-executor.md",
             start="Append `## ", end="any other re-spawn also appends a new, complete entry.",
             mask=("Append `## ", " (cont.)`")),
    span_row("precedence", BODIES + CODEX_STAGE_PROMPTS, canon="agents/squad-executor.md",
             start="Your own protocol and the log outrank your spawn prompt", end="name the conflict in your entry."),
    span_row("latest Goal read", BODIES + CODEX_STAGE_PROMPTS, text=LATEST_GOAL_READ),
    span_row("criterion command", [SKILL, "agents/squad-pm.md"] + EXECUTOR_BODIES + CODEX_STAGE_PROMPTS[1:],
             text=CRITERION_COMMAND),
    span_row("mech precedence", ["agents/squad-mech.md", "codex/01-archive.md"],
             text="The procedures in this file outrank your spawn prompt: where the prompt conflicts with one, "
                  "follow this file and name the conflict in your report."),
    span_row("7k blocker grammar", BODIES + CODEX_STAGE_PROMPTS, canon="agents/squad-executor.md",
             start="Blockers use one grammar, as the last block of your own entry", end="no block means no blocker.",
             contains=(BLOCKER_FENCE, "is a protocol violation.")),
    span_row("7n output form", EXECUTOR_BODIES + ["codex/04-execute.md"], text="`" + OUTPUT_FORM + "`"),
    span_row("7n ACCEPT output form", PM_FILES, text="`" + ACCEPT_FORM + "`"),
    # The PASS step repeats the form, so the row anchors on step 2's sentence.
    span_row("7n check line", PM_FILES, text="Record each command in your entry as " + CHECK_LINE_FORM + "."),
] + [
    span_row(f"ACCEPT read: {part}", PM_FILES, text=command) for part, command in ACCEPT_READS
] + [
    # The backtick keeps squad-mech's `ARCHIVE REFUSED: open run` report from standing in for the refusal marker.
    span_row("refused", ["agents/squad-helper.md", "agents/squad-mech.md"], text="`REFUSED:"),
    span_row("refusal route", [SKILL],
             text="If a helper refused a step or reports one that did not run as the procedure says, append that "
                  "report the same way and re-spawn the requesting stage even if its request was not `BLOCKING`"),
    span_row("switchboard", [SKILL], text="no squad agent is given a tool for it"),
    span_row("executor plan read", EXECUTOR_BODIES + ["codex/04-execute.md"], text=EXECUTOR_PLAN_READ),
    span_row("verdict scope", PM_FILES, text=VERDICT_SCOPE),
    span_row("work-order stop", PM_FILES, text=WORK_ORDER_STOP),
    span_row("plan attempt", ["agents/squad-pm.md", "codex/03-pm-plan.md"], text=PLAN_ATTEMPT),
    span_row("verdict attempt", PM_FILES, text=VERDICT_ATTEMPT),
    span_row("classification route", [SKILL], text=CLASSIFICATION_ROUTE),
    span_row("FAIL count", [SKILL], text=FAIL_COUNT),
    span_row("open-run guard", ["agents/squad-mech.md", "codex/01-archive.md"], text=OPEN_RUN_GUARD_SPAN),
    span_row("answers", BODIES + ["codex/02-recon.md", "codex/03-pm-plan.md", "codex/04-execute.md"], text=ANSWERS_SENTENCE),
    span_row("final message", BODIES + CODEX_STAGE_PROMPTS[:3], text=FINAL_MESSAGE),
    span_row("ACCEPT final message", PM_FILES, text=ACCEPT_FINAL_MESSAGE),
    span_row("Stage 0 bound", [SKILL], text=STAGE0_BOUND),
    span_row("spawn pointer", [SKILL, "codex/SKILL.md"], text=SPAWN_POINTER),
    span_row("route grep", [SKILL, "codex/SKILL.md"], text=ROUTE_GREP),
    span_row("delegation cap", BODIES + CODEX_STAGE_PROMPTS, text=DELEGATION_CAP),
    span_row("helper output cap", ["agents/squad-helper.md", "agents/squad-mech.md", "codex/01-archive.md"],
             text=HELPER_OUTPUT_CAP),
    span_row("audit ruling", PM_FILES, text=AUDIT_RULING),
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

# ---- 7v: resume, handoff, and one active run (findings 10 and 11; the
# report's 7x). references/resume.md is tracked, and its next-action table's
# first column names every heading on SKILL.md's closed list except ## Status
# and ## Delegated — <stage>, the two it never routes from. Both SKILL.md
# files send a resume to it and carry the one-active-run rule; SKILL.md,
# codex/SKILL.md, and codex/README.md stop Stage 1 on ARCHIVE REFUSED;
# SKILL.md's Status rule lets resume.md's steps 2 and 3 stop without a
# Status, so S7b's log stays unchanged; and
# squad-mech's open-run guard, which check 8b runs, is in its body, the
# generated Codex prompt, and its TOML. Text is compared with whitespace
# collapsed. Check 8b drives the table itself.
RESUME = "skills/compute-squad/references/resume.md"
if RESUME not in tracked_files(RESUME):
    fail(f"{RESUME} is not tracked, so the plugin would ship without the resume table")
resume_lines = read(RESUME).splitlines()
try:
    table_at = resume_lines.index("| Last entry | Next action |")
except ValueError:
    fail(f"{RESUME}: no '| Last entry | Next action |' table")
first_column = []
for line in resume_lines[table_at + 2:]:
    if not line.startswith("|"):
        break
    first_column.append(line.strip("|").split(" | ")[0].strip())
# The one placeholder heading on the list is ## Delegated — <stage>.
routed = [h for h in listed_headings if h != "## Status" and "<" not in h]
unrouted = [h for h in routed if not any(cell.startswith("`" + h + "`") for cell in first_column)]
if unrouted:
    fail(f"{RESUME}: the next-action table has no row whose first column names {unrouted!r}")
RESUME_RULES = {
    SKILL: (
        "read `references/resume.md` and route by it before any spawn",
        "first recompute `Next:` from `references/resume.md`",
        "then revalidate, execute it, accept it, and stop.",
        "One active run per worktree.",
        "If it reports `ARCHIVE FAILED` or `ARCHIVE REFUSED`, append nothing",
        "and a resume stop whose state the latest `## Status` already records (`references/resume.md` steps 2 and 3).",
        "The latest `## Status` is the handoff record.",
    ),
    "codex/SKILL.md": (
        "read `skills/compute-squad/references/resume.md`",
        "first recompute `Next:` from `skills/compute-squad/references/resume.md`",
        "One active run per worktree.",
        "If it reports `ARCHIVE FAILED` or `ARCHIVE REFUSED`, append nothing",
        "The latest `## Status` is the handoff record.",
    ),
    "codex/README.md": ("`ARCHIVE FAILED` or `ARCHIVE REFUSED`", "references/resume.md"),
}
OPEN_RUN_GUARD = (
    "When told a new run is starting, first run `grep '^Next: ' COMPUTE_SQUAD_LOG.md | tail -n 1`. If it prints a "
    "line other than `Next: none`, change nothing and report `ARCHIVE REFUSED: open run` followed by that line."
)
for path in ("agents/squad-mech.md", "codex/01-archive.md", "codex/agents/squad-mech.toml"):
    RESUME_RULES[path] = (OPEN_RUN_GUARD,)
for path, rules in RESUME_RULES.items():
    flat = " ".join(read(path).split())
    missing = [rule for rule in rules if rule not in flat]
    if missing:
        fail(f"{path}: missing the resume and one-active-run text {missing!r}")

print(
    f"PASS: check 7: {RESUME}'s next-action table routes from {', '.join(routed)}; both SKILL.md files send a resume "
    f"to it and carry the one-active-run rule, and squad-mech's open-run guard is in its body, prompt, and TOML"
)

# ---- 7w: entry labels (finding 16). Recon and Executor entries are labeled
# sections, one line per item, not prose paragraphs. The Recon template in
# agents/squad-recon.md and codex/02-recon.md, and the Executor template in
# agents/squad-executor.md and codex/04-execute.md (7m holds the other two
# executors to it), carry exactly the labels tests/check_logs.py --labels
# lints, in its order, after their fixed lines. The PLAN template states the
# plan's totals on a Totals: line, and ACCEPT answers every Executor point.
labels_run = subprocess.run([sys.executable, "tests/check_logs.py", "--labels"], capture_output=True, text=True)
try:
    label_table = json.loads(labels_run.stdout) if labels_run.returncode == 0 else None
except ValueError:
    label_table = None
if not isinstance(label_table, dict) or set(label_table) != {"## Recon", "## Executor"}:
    fail(f"tests/check_logs.py --labels exited {labels_run.returncode} without its label table: {labels_run.stderr.strip()}")
LABEL_TEMPLATES = {
    "## Recon": ["agents/squad-recon.md", "codex/02-recon.md"],
    "## Executor": ["agents/squad-executor.md", "codex/04-execute.md"],
}
FIXED_PREFIXES = ("Timestamp:", "Agent:", "Attempt:", "Answers:", "Plan:")
for heading, paths in LABEL_TEMPLATES.items():
    for path in paths:
        lines = read(path).splitlines()
        opens = [i for i, line in enumerate(lines) if line == LOG_HEREDOC and lines[i + 1:i + 2] == [heading]]
        if len(opens) != 1:
            fail(f"{path}: needs one {LOG_HEREDOC!r} template for {heading!r}; found {len(opens)}")
        block = []
        for line in lines[opens[0] + 2:]:
            if line == "EOF":
                break
            block.append(line)
        found = [line.split(":", 1)[0] for line in block
                 if line.strip() and not line.startswith("- ") and ":" in line and not line.startswith(FIXED_PREFIXES)]
        if found != label_table[heading]:
            fail(f"{path}: the {heading} template's labels are {found!r}; tests/check_logs.py lints "
                 f"{label_table[heading]!r}. Change the template and LABELS together")
for path in ("agents/squad-pm.md", "codex/03-pm-plan.md"):
    if "\nTotals: <every quantity the work produces>\n" not in read(path) or "on a `Totals:` line" not in read(path):
        fail(f"{path}: the PLAN template needs its 'Totals: <every quantity the work produces>' line and the Totals: rule")
for path in CRITERIA_PM:
    if "Never PASS with an unanswered point." not in read(path):
        fail(f"{path}: ACCEPT must answer every Executor point ('Never PASS with an unanswered point.')")

print(
    "PASS: check 7: the Recon and Executor templates carry the labels the log linter checks ("
    + "; ".join(f"{h}: {', '.join(l)}" for h, l in label_table.items())
    + "), the PLAN template a Totals: line, and ACCEPT answers every Executor point"
)

# ---- 7x: evidence prerequisites (finding 14). Recon checks the goal's stated
# facts, runs the project's test or verify command once on the untouched
# tree, and confirms the tools the criteria's evidence needs; its Checks:
# block opens with those results. PLAN starts from that block, reconciles its
# counts, marks its own assumptions, and escalates before dropping existing
# behavior. The Recon template in agents/squad-recon.md and codex/02-recon.md
# carries the Checks: lines, and an instance of each must match the forms the
# log linter's recon-checks rule reads (tests/check_logs.py GOAL_FACTS_LINE,
# BASELINE_LINE, BASELINE_SKIPPED). The Recon body and prompt carry
# the one baseline command form and the skip line; no agent body or Codex
# prompt keeps the old "exactly one carve-out" Bash rule. The executors stop
# with needs-human: on a failure Recon's Checks block already records
# (finding 13), so that clause names the block this check pins.
EVIDENCE = "evidence prerequisites"
EVIDENCE_PATHS = ["agents/squad-recon.md", "codex/02-recon.md", "skills/compute-squad/SKILL.md", "codex/SKILL.md"]
RECON_TEMPLATES = ["agents/squad-recon.md", "codex/02-recon.md"]
RECON_CHECKS = [
    "Checks:",
    "- goal facts: <all confirmed | each false one, with the file:line that contradicts it>",
    "- `<baseline command>` -> exit <code>; <last summary line>; tree changed: <no | the paths>",
    "- `<presence check for a tool a criterion needs>` -> exit <code>; <version or path>",
]
BASELINE_FORM = (
    '`git status --porcelain; set -o pipefail; <command> 2>&1 | tail -n 20; echo "exit $?"; git status --porcelain`'
)
BASELINE_SKIP = "- baseline: not run, <why>"
PLAN_PREREQS = (
    "Start from Recon's Checks block and do not re-run a baseline it logged.",
    "Reconcile before you append:",
    "with `Assumed:` and name the check that would confirm it.",
    "Never describe a compatibility loss as accepted.",
)
PLAN_PATHS = ["agents/squad-pm.md", "codex/03-pm-plan.md"]
STOP_TARGET = "`needs-human:` when Recon's Checks block or the plan records the same failure on the unchanged tree"
OLD_CARVE_OUT = "exactly one carve-out"


def instance(line):
    line = line.replace("<baseline command>", "npm test").replace(
        "<presence check for a tool a criterion needs>", "node --version").replace("<code>", "0")
    return re.sub(r"<[^<>]+>", "x", line)


for path in EVIDENCE_PATHS:
    if EVIDENCE not in " ".join(read(path).split()):
        fail(f"{path}: must name the {EVIDENCE!r} Recon checks")
for path in RECON_TEMPLATES:
    lines = read(path).splitlines()
    opens = [i for i, line in enumerate(lines) if line == LOG_HEREDOC and lines[i + 1:i + 2] == ["## Recon"]]
    block = []
    for line in lines[opens[0] + 2:] if len(opens) == 1 else []:
        if line == "EOF":
            break
        block.append(line)
    at = [i for i, line in enumerate(block) if line == RECON_CHECKS[0]]
    if len(at) != 1 or block[at[0]:at[0] + len(RECON_CHECKS)] != RECON_CHECKS:
        fail(f"{path}: the ## Recon template's Checks: block must read {RECON_CHECKS!r}")
    text = read(path)
    for needed in (BASELINE_FORM, "`" + BASELINE_SKIP + "`"):
        if needed not in text:
            fail(f"{path}: Recon's baseline step must give {needed!r}")
forms = [
    (instance(RECON_CHECKS[1]), check_logs.GOAL_FACTS_LINE, "GOAL_FACTS_LINE"),
    (instance(RECON_CHECKS[2]), check_logs.BASELINE_LINE, "BASELINE_LINE"),
    (instance(BASELINE_SKIP), check_logs.BASELINE_SKIPPED, "BASELINE_SKIPPED"),
]
for sample, pattern, name in forms:
    if not re.fullmatch(pattern, sample):
        fail(f"tests/check_logs.py {name} rejects {sample!r}, an instance of the Recon template's line; change the "
             f"template and the linter together")
for path in PLAN_PATHS:
    missing = [phrase for phrase in PLAN_PREREQS if phrase not in read(path)]
    if missing:
        fail(f"{path}: PLAN must start from Recon's Checks block, reconcile, mark assumptions, and keep behavior; "
             f"missing {missing!r}")
for path in EXECUTOR_BODIES + ["codex/04-execute.md"]:
    if STOP_TARGET not in read(path):
        fail(f"{path}: the stop target must name Recon's Checks block: {STOP_TARGET!r}")
stale = [path for path in tracked_files("agents/", "codex/") if OLD_CARVE_OUT in read(path)]
if stale:
    fail(f"{', '.join(stale)}: still say {OLD_CARVE_OUT!r}; Recon's Bash has two carve-outs, the baseline run and the log append")

print(
    f"PASS: check 7: Recon checks the {EVIDENCE} ({', '.join(EVIDENCE_PATHS)}), its template's Checks: block matches "
    f"the log linter's recon-checks forms, PLAN starts from it and reconciles its counts ({', '.join(PLAN_PATHS)}), the "
    f"executors' stop target names it, and no agent body or Codex prompt keeps {OLD_CARVE_OUT!r}"
)

# ---- 7y: orchestrator economy (finding 5). Stage 0 reads no product source,
# every stage spawn prompt is the five-line pointer, and the main session
# routes from the log: after every spawn it greps the headings, the fixed
# lines, and the DELEGATE: and BLOCKER: blocks, never a stage's final message,
# which only points at the entry (the 7p rows "Stage 0 bound", "spawn
# pointer", "route grep", "final message", and "ACCEPT final message" pin
# the text). Both SKILL.md files carry the rules, compared with whitespace
# collapsed; the grep names every routing field tests/check_logs.py --fields
# lints, and its tail covers the longest entry's matching lines (heading,
# fixed lines, DELEGATE:, BLOCKER:). No stage body or Codex prompt keeps the
# one-paragraph summary, and neither SKILL.md passes Recon the goal.
ECONOMY_RULES = (
    STAGE0_BOUND,
    "Every stage spawn prompt is a pointer of at most 400 characters, in exactly",
    "Route from the log, never from a stage's final message.",
    "Route on those field lines, not on the entry's prose.",
    "Spawn `squad-recon`; it reads the locked goal and criteria from the log.",
)
for path in (SKILL, "codex/SKILL.md"):
    flat = " ".join(read(path).split())
    missing = [rule for rule in ECONOMY_RULES if " ".join(rule.split()) not in flat]
    if missing:
        fail(f"{path}: missing the Stage 0 bound, pointer, or route-from-log text {missing!r}")
    if "Spawn `squad-recon` with the locked goal" in flat:
        fail(f"{path}: Recon reads the goal from the log; its spawn prompt never carries it")
# squad-mech keys its two archive procedures on the pointer's values, so the
# closing archive and the refusal-guarded new-run archive never depend on
# prose in the prompt.
MECH_POINTER = (
    "A spawn prompt reading `Mode: close` tells you to close a run; one reading `Mode: none` and "
    "`Since your last spawn: new run` tells you a new run is starting."
)
for path in ("agents/squad-mech.md", "codex/01-archive.md", "codex/agents/squad-mech.toml"):
    if MECH_POINTER not in " ".join(read(path).split()):
        fail(f"{path}: squad-mech must name the pointer values that start each archive procedure: {MECH_POINTER!r}")
grep_match = re.fullmatch(r"grep -n -E '\^\(([^)]*)\)' COMPUTE_SQUAD_LOG\.md \| tail -n ([0-9]+)", ROUTE_GREP)
if not grep_match:
    fail(f"the route grep {ROUTE_GREP!r} is not one grep -n -E '^(...)' over the log piped to tail -n N")
grep_alternatives = grep_match.group(1).split("|")
grep_wanted = ["## ", "DELEGATE:", "BLOCKER:"] + [name + ": " for name in field_names]
grep_missing = [item for item in grep_wanted if item not in grep_alternatives]
if grep_missing:
    fail(f"the route grep misses {grep_missing!r}; it must match every heading, block, and routing field "
         f"tests/check_logs.py --fields lints ({', '.join(field_names)})")
longest_entry = 1 + max(len(fields) for fields in field_table.values()) + 2
if int(grep_match.group(2)) < longest_entry:
    fail(f"the route grep keeps {grep_match.group(2)} lines, fewer than the {longest_entry} one entry can match, so "
         f"the newest heading could fall off")
RETIRED_SUMMARY = ("one-paragraph summary", "final summary")
stale_summary = [f"{path}: {phrase!r}" for path in tracked_files("agents/", "codex/", "skills/")
                 for phrase in RETIRED_SUMMARY if phrase in " ".join(read(path).split())]
if stale_summary:
    fail("a stage's final message points at its entry and never summarizes it: " + "; ".join(stale_summary))

print(
    f"PASS: check 7: both SKILL.md files bound Stage 0, send every stage a pointer prompt, and route from the log "
    f"with a grep over {', '.join(grep_wanted)} (tail -n {grep_match.group(2)}, one entry matches at most "
    f"{longest_entry}), and no stage body or Codex prompt keeps a summary final message"
)

# ---- 7z: delegation economy (finding 18). Small work stays in-stage, a
# BLOCKING requester is continued with SendMessage and re-spawned only when
# that fails, and every subtask caps its helper's output (the 7p rows
# "delegation cap" and "helper output cap" pin the body sentences, and 8a's
# delegate-cap rule holds logs to the cap). The switchboard stays: 7r keeps
# spawning tools out of every agent file and 7p's "switchboard" row keeps
# SKILL.md's reason. Both SKILL.md files carry the rules, compared with
# whitespace collapsed; every stage body limits delegation to work too large
# to do in a few commands; no agent body or Codex prompt says a stage is
# only re-spawned; the resume table continues or re-spawns a BLOCKING
# requester; and a needs-human: blocker holds continuations as it holds
# spawns.
DELEGATION_RULES = {
    SKILL: (
        "Delegate only work too large to do in a few commands: a count, a listing, or an inventory of one directory "
        "costs less in-stage than the orchestrating session's spawn and append turns, so the stage does it and puts "
        "the result in its own entry.",
        "Each subtask is one item: `- [<intern|execution>] <exact procedure>; return at most <N> lines.`",
        "Each appended result keeps to its subtask's line cap, plus one line saying how the procedure ran and how many "
        "lines were cut.",
        "If the requesting stage marked the block `BLOCKING`, continue that stage's agent with SendMessage (load it "
        "through ToolSearch if it is listed only by name) and point it at the new `## Delegated — <stage>` entry",
        "re-spawn the stage only when the host cannot message a finished agent or the message fails.",
        "the one-entry rule is per spawn or continuation, not per run.",
        "Counts, listings, and single-directory inventories stay in-stage.",
        "then continue or re-spawn the PM in ACCEPT mode for the verdict (DELEGATE step 2).",
        "A `needs-human:` blocker stops the pipeline: spawn or continue no stage until it is resolved.",
    ),
    "codex/SKILL.md": (
        "`- [<intern|execution>] <exact procedure>; return at most <N> lines.`",
        "counts, listings, and single-directory inventories stay in-stage",
        "re-spawns the requester only when the host cannot message a finished agent or the message fails.",
        "the one-entry rule is per spawn or continuation, not per run.",
        "then continue or respawn the PM for the verdict.",
        "A `needs-human:` blocker stops the pipeline: spawn or continue no stage until it is resolved.",
    ),
    "skills/compute-squad/references/resume.md": (
        "Then, if the block is `BLOCKING`, continue or re-spawn that stage to finish",
        "only the session that spawned the stage's agent can continue it, so any other session re-spawns it.",
    ),
    "README.md": ("push busywork too large to do in-stage down a tier",),
}
for path, rules in DELEGATION_RULES.items():
    flat = " ".join(read(path).split())
    missing = [rule for rule in rules if " ".join(rule.split()) not in flat]
    if missing:
        fail(f"{path}: missing finding 18's delegation text {missing!r}")
IN_STAGE_LIMIT = {path: "zero-judgment bulk work too large to do in a few commands" for path in ["agents/squad-recon.md"]}
IN_STAGE_LIMIT.update({path: "zero-judgment busywork too large to do in a few commands" for path in EXECUTOR_BODIES})
IN_STAGE_LIMIT["agents/squad-pm.md"] = "zero-judgment inputs too large to gather in a few commands"
for path, phrase in IN_STAGE_LIMIT.items():
    if phrase not in read(path):
        fail(f"{path}: its DELEGATE paragraph must limit delegation to {phrase!r}")
bare_respawn = [
    f"{path}:{number}" for path in tracked_files("agents/*.md", "codex/0*.md")
    for number, line in enumerate(read(path).splitlines(), 1)
    for match in re.finditer(r"re-spawns you", line) if not line[:match.start()].endswith("continues or ")
]
if bare_respawn:
    fail("a stage waiting on its own delegation is continued first; say 'continues or re-spawns you', not a bare "
         "'re-spawns you': " + ", ".join(bare_respawn))
old_examples = [f"{path}: {phrase!r}" for path in tracked_files("agents/", "codex/", "skills/")
                for phrase in ("symbol counts", "bulk file inventories") if phrase in " ".join(read(path).split())]
if old_examples:
    fail("counts and single-directory inventories stay in-stage, so no protocol file offers them for delegation: "
         + "; ".join(old_examples))

print(
    f"PASS: check 7: both SKILL.md files keep small work in-stage, continue a BLOCKING requester before re-spawning "
    f"it, and cap every subtask's output; the {len(IN_STAGE_LIMIT)} stage bodies delegate only work too large to do "
    f"in a few commands, no agent body or Codex prompt only re-spawns a waiting stage, and the resume table and "
    f"README agree"
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
import shlex
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
# blocker until a Decision. Its fields, attempt, governing-plan, high-stakes,
# and cont rules hold the routing lines finding 9 fixes under each stage
# entry's Agent: line (check 7i holds the templates to the same table). Its
# criteria, waiver, and parity rules hold every PASS and FAIL to finding 2's
# criteria block, whose shape it reads from SKILL.md (check 7g holds the
# copies alike), and its labels, executor-points, and totals rules hold the
# Recon and Executor entries, the verdict's answers, and the plan to finding
# 16's labels (check 7w holds the templates to them). Its review rules hold
# the main session's ## High-stakes review to finding 3: one follows every
# high-stakes PASS, its Rerun: line appears only when it is overturned, and an
# upheld review has no open item and closes the run. Its answers rule holds
# every re-run to finding 13's Answers: line, and its recon-checks rule holds
# the Recon entry's Checks: block to finding 14's goal-facts and baseline
# lines (check 7x holds the template to the same forms). Its block-column
# rule keeps every DELEGATE: and BLOCKER: line at column 0, where the main
# session's route grep finds it (finding 5; 7y holds the grep). Its
# delegate-cap rule holds every DELEGATE: subtask to its output cap, and the
# ## Delegated entries answering a block to those caps plus one line per
# subtask (finding 18; 7z holds the protocol text). Its audit, audit-cap,
# and audit-ruling rules hold the main session's ## Audit Findings entry to
# finding 20's procedure and template, whose cap, verdicts, and severities it
# reads from references/audit-prompts.md: the entry follows execution, lists
# as many findings as its Findings: count, runs skeptics on at most the cap's
# findings in severity order and marks the rest UNREVIEWED, and every PASS or
# FAIL after it names each CONFIRMED, UNREVIEWED, and NEEDS-HUMAN finding
# (7c and 7p hold the protocol text). The example log must
# lint clean. Each fixture tests/fixtures/logs/<name>.log.md has a
# <name>.expect.json that cites the protocol text it tests (each cited text
# must still be in the cited file) and says whether the linter passes it or
# which rules it fails. Every negative fixture must fail with exactly its
# rules, and every linter rule needs at least one negative fixture. A live
# seed's .expect.json may also list outcomes, entries a live call could
# append, each with the lint result the seed plus that entry must give.
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

# A live seed's .expect.json may list outcomes: entries a live call could
# append ("append", one string per line), each with the lint result the seed
# plus that entry must give. S5's are the verdicts section 6 names as its
# 8a twin: over the S5 seed, a PASS with a not met row and a PASS with a
# waived row and no Decision fail; the FAIL and the pending entry S5 accepts
# lint clean. Check 8b holds the live check's judgment to each "live" value.
OUTCOME_KEYS = {"note", "append", "lint", "live"}
outcomes_linted = 0
with tempfile.TemporaryDirectory() as tmp:
    for log in logs:
        expect_path = log[:-len(".log.md")] + ".expect.json"
        for number, outcome in enumerate(json.loads(read(expect_path)).get("outcomes") or [], 1):
            if (not isinstance(outcome, dict) or set(outcome) != OUTCOME_KEYS or not outcome["append"]
                    or not all(isinstance(line, str) for line in outcome["append"])
                    or outcome["live"] not in ("pass", "fail")):
                fail(f"{expect_path}: outcome {number} needs exactly {sorted(OUTCOME_KEYS)!r}, with 'append' a list "
                     f"of lines and 'live' pass or fail")
            outcome_lint = outcome["lint"] if isinstance(outcome["lint"], dict) else {}
            wanted, wanted_rules = outcome_lint.get("result"), outcome_lint.get("rules")
            if wanted not in ("pass", "fail") or not isinstance(wanted_rules, list) \
                    or (wanted == "fail") != bool(wanted_rules) or any(r not in linter_rules for r in wanted_rules):
                fail(f"{expect_path}: outcome {number}'s lint.result must be pass with no rules, or fail with rules "
                     f"from {linter_rules!r}")
            appended = os.path.join(tmp, f"{os.path.basename(log)[:-len('.log.md')]}-{number}.log.md")
            with open(appended, "w", encoding="utf-8") as handle:
                handle.write(read(log).rstrip("\n") + "\n\n" + "\n".join(outcome["append"]) + "\n")
            run = run_linter(appended)
            found = fired_rules(run.stdout)
            if (wanted == "pass" and run.returncode != 0) \
                    or (wanted == "fail" and (run.returncode != 1 or found != set(wanted_rules))):
                fail(f"{log} with {expect_path}'s outcome {number} appended should "
                     + ("lint clean" if wanted == "pass" else f"fail exactly {sorted(wanted_rules)!r}")
                     + f"; exit {run.returncode}, fired {sorted(found)!r}:\n{run.stdout}{run.stderr}")
            outcomes_linted += 1

print(
    f"PASS: check 8: docs/example-log.md lints clean, {len(passing)} fixture logs pass, and {len(failing)} fail "
    f"with exactly their expected rules; every linter rule has a failing fixture ({', '.join(linter_rules)}); "
    f"{outcomes_linted} live-seed outcomes, each appended to its seed, lint as their fixtures state"
)

# ---- 8b: the resume table. tests/resume_next.py models
# skills/compute-squad/references/resume.md: its steps, its next-action table
# (read from that file, so a changed row stops the model with status 2 until
# the model changes with it), the tree and base checks before an executor
# spawn, and SKILL.md's one-active-run rule for a new goal over the log.
# Every fixture log's .expect.json carries resume cases, each a state (what
# the session sees besides the log: the request, the host, HEAD and the
# paths moved since Base:, the dirty paths, and whether it can still message
# the agent of a BLOCKING requester, which it then continues rather than
# re-spawns (finding 18)) with the next action and the
# step or row the model must give for it. Every row, step, and check must
# be exercised by a fixture that lints clean. The section 6 scenarios whose
# static twin is 8b must map to the case named below, with the action the
# scenario asserts. Every live scenario in tests/live/run.sh is the live half
# of one of those twins, seeded with the twin's fixture (S5 and S5b on
# tests/fixtures/repo-ui/, the rest on tests/fixtures/repo-reset/; S5's
# verdicts are also 8a's outcomes, and S6a and S6b also have 8d twins),
# and the live S5 check's rule gives each of its seed's outcomes the value
# the fixture states. The rules of the live checks that read the hook log or
# the usage ledger, S8's Stage 0 bound and main-session budget and S9's
# skeptic cap (work order WO-3f), give each case in tests/fixtures/live/
# <check>.json the value it states, over cases that pass and cases that fail,
# and S9's passing cases, appended to its seed, lint clean. run.sh's --list,
# --dry-run, and --setup-only run for every scenario with CI set and a claude
# stub that must never be called, --dry-run prints each claude call's
# --settings with the hook that writes the hook log (a PreToolUse hook with no
# matcher, which, run with sh and dash on synthetic input, prints nothing,
# exits 0, and writes one record per call), and in each repo
# --setup-only builds, HEAD
# and git status against the seeded Base: must give the twin's state, and the
# model over the seeded log must give the twin's action with the repo's own
# commits in it. Where node is installed, each repo's npm test script passes,
# so no live scenario starts on a broken tree, and a scenario that prints a
# preflight passes it as printed (S5's and S5b's only where Playwright's
# Chromium starts). squad-mech's open-run guard,
# the command its archive procedure runs before the archive command, runs
# with sh (and dash and bash where installed) over every fixture log, and
# must refuse the archive for exactly the logs the one-active-run rule
# refuses.
RESUME_MODEL = "tests/resume_next.py"
RESUME_TABLE = "skills/compute-squad/references/resume.md"
MECH = "agents/squad-mech.md"
for path in (RESUME_MODEL, RESUME_TABLE):
    if path not in tracked_set:
        fail(f"{path} is not tracked")
sys.dont_write_bytecode = True
sys.path.insert(0, "tests")
import resume_next  # noqa: E402

try:
    resume_rows = resume_next.load_rows()
except (OSError, resume_next.ProtocolError) as e:
    fail(f"{RESUME_MODEL} cannot model the resume table: {e}")
# The DELEGATE row's refusal case (a helper's REFUSED: or not run: step)
# reports its own source, so a fixture must exercise it too.
RESUME_SOURCES = ["row: " + first for first, _ in resume_rows] + [
    "row: " + resume_next.ROWS[1][0] + resume_next.REFUSED_SOURCE,
    "step 1", "step 2", "step 3", "step 4: perform Next", "step 5: accept", "tree check",
    "base check: re-map", "base check: continue", "new run: empty log", "new run: refuse", "new run: archive",
]
# (scenario, fixture, state, step or row, a phrase the action contains, a
# phrase it must not contain)
EXECUTOR_SPAWN = "squad-executor"
RESUME_TWINS = [
    ("S1", "plan-shelved", {}, "step 4: perform Next", "await a grant", EXECUTOR_SPAWN),
    ("S1 turn 1", "s1", {"request": "new-goal"}, "new run: empty log", "run Stage 1", None),
    ("S2", "s2", {}, "step 4: perform Next", EXECUTOR_SPAWN, None),
    ("S2b", "s2b", {}, "row: `## PM — Plan`", "awaits a grant for r2", EXECUTOR_SPAWN),
    ("S2c", "s2c", {"dirty": ["src/server/auth/reset.service.js", "src/server/auth/__tests__/reset.routes.test.js"]},
     "row: `## PM — PASS` in a high-stakes run", "high-stakes review procedure", EXECUTOR_SPAWN),
    ("S3a", "s3", {"head": "b7e41d2", "moved": ["src/server/db/store.js"]}, "base check: re-map",
     "spawn squad-recon to re-map src/server/db/store.js", EXECUTOR_SPAWN),
    ("S3b", "s3", {"head": "b7e41d2", "moved": ["docs/notes.md"]}, "base check: continue", EXECUTOR_SPAWN,
     "squad-recon"),
    ("S4", "s4", {"head": "c3a9f05", "moved": ["src/server/auth/reset.service.js",
                                              "src/server/auth/__tests__/reset.routes.test.js"]},
     "step 5: accept", "review git diff 4f2c9a1 against c3a9f05", EXECUTOR_SPAWN),
    ("S4b", "s4", {"head": "c3a9f05", "moved": ["src/server/auth/reset.service.js",
                                               "src/server/auth/__tests__/reset.routes.test.js",
                                               "src/server/log.js"]},
     "step 5: accept", "review git diff 4f2c9a1 against c3a9f05", EXECUTOR_SPAWN),
    ("S5", "s5", {"dirty": ["public/index.html", "public/styles.css", "test/page.test.js"]}, "step 4: perform Next",
     "spawn squad-pm (ACCEPT)", EXECUTOR_SPAWN),
    ("S5b", "s5b", {}, "step 4: perform Next", "spawn squad-recon", "squad-pm"),
    ("S6a", "s6a", {"dirty": ["src/server/auth/reset.service.js", "src/server/auth/__tests__/reset.routes.test.js"]},
     "row: `## PM — PASS` in a high-stakes run", "high-stakes review procedure", "squad-mech"),
    ("S6b", "run-parked", {"request": "new-goal"}, "new run: archive", "archive the log", "refuse"),
    ("S7b", "s7b", {}, "step 2", "three FAILs", "append"),
    ("second run", "s2", {"request": "new-goal"}, "new run: refuse", "park, or abandon", "Stage 1"),
    ("S9", "s9", {"dirty": ["package.json", "src/server/auth/__tests__/reset.routes.test.js",
                            "src/server/auth/reset.service.js"]},
     "step 4: perform Next", "run the audit", "squad-pm"),
]


def sources_of(via):
    if via.startswith("row: "):
        return ["row: " + part for part in via[len("row: "):].split(" / ")]
    return [via]


resume_cases, resume_covered = {}, set()
clean_fixtures = set(passing)
for log in logs:
    name = os.path.basename(log)[:-len(".log.md")]
    expect_path = log[:-len(".log.md")] + ".expect.json"
    cases = json.loads(read(expect_path)).get("resume")
    if not isinstance(cases, list) or not cases:
        fail(f"{expect_path}: needs a 'resume' list of cases, each {{'state', 'next', 'via'}}")
    lines = [(n, t) for n, t in enumerate(read(log).splitlines(), 1)]
    for case in cases:
        if not isinstance(case, dict) or set(case) != {"state", "next", "via"} or not isinstance(case["state"], dict):
            fail(f"{expect_path}: each resume case is {{'state': {{...}}, 'next': ..., 'via': ...}}; got {case!r}")
        try:
            got = resume_next.next_action(lines, case["state"])
        except resume_next.ProtocolError as e:
            fail(f"{expect_path}: {e}")
        if list(got) != [case["next"], case["via"]]:
            fail(f"{log} with state {json.dumps(case['state'])}: the resume table gives {got[0]!r} [{got[1]}], "
                 f"the fixture expects {case['next']!r} [{case['via']}]")
        resume_cases.setdefault(name, []).append(case)
        if log in clean_fixtures:
            resume_covered.update(sources_of(case["via"]))
missing = [s for s in RESUME_SOURCES if s not in resume_covered]
if missing:
    fail(f"no fixture that lints clean exercises these parts of {RESUME_TABLE}: {missing!r}")
twin_cases = {}
for scenario, name, state, via, phrase, banned in RESUME_TWINS:
    case = next((c for c in resume_cases.get(name, []) if c["state"] == state), None)
    if case is None:
        fail(f"8b is the static twin of {scenario}: {FIXTURES}{name}.expect.json needs a resume case with state {state!r}")
    if case["via"] != via or phrase not in case["next"] or (banned and banned in case["next"]):
        fail(f"{scenario}'s static twin ({name}, {state!r}) must come from {via!r} and name {phrase!r}"
             + (f" but not {banned!r}" if banned else "") + f"; got {case['next']!r} [{case['via']}]")
    twin_cases[scenario] = case

# The live tier: each tests/live/run.sh scenario and the RESUME_TWINS row it
# is the live half of.
LIVE_RUN = "tests/live/run.sh"
LIVE_CHECK = "tests/live/check_live.py"
LIVE_TWINS = {
    "s1": "S1 turn 1", "s1n": "S1 turn 1", "s2": "S2", "s2b": "S2b", "s2c": "S2c", "s2o": "second run",
    "s3a": "S3a", "s3b": "S3b", "s4": "S4", "s4b": "S4b", "s5": "S5", "s5b": "S5b", "s6a": "S6a", "s6b": "S6b",
    "s7b": "S7b", "s8": "S1 turn 1", "s9": "S9",
}
GIT_STATE = ("head", "moved", "dirty")
for path in (LIVE_RUN, LIVE_CHECK):
    if path not in tracked_set:
        fail(f"{path} is not tracked")
sys.path.insert(0, "tests/live")
import check_live  # noqa: E402

twin_rows = {row[0]: row for row in RESUME_TWINS}
unknown_twins = sorted(set(LIVE_TWINS.values()) - set(twin_rows))
if unknown_twins:
    fail(f"LIVE_TWINS names rows RESUME_TWINS lacks: {unknown_twins!r}")

# The live check's rule for a scenario whose seed lists outcomes (8a lints
# them): over each outcome's entries it gives the outcome's "live" value, so
# the rule a live S5 call is judged by is the one these fixtures pin, and the
# outcomes hold at least one verdict it accepts and one it rejects.
LIVE_JUDGES = {"s5": check_live.s5_judgment}
judged_outcomes = 0
for seed, judge in LIVE_JUDGES.items():
    seed_log = FIXTURES + seed + ".log.md"
    outcomes = json.loads(read(seed_log[:-len(".log.md")] + ".expect.json")).get("outcomes") or []
    if {o["live"] for o in outcomes} != {"pass", "fail"}:
        fail(f"{FIXTURES}{seed}.expect.json needs outcomes the live {seed} check accepts and outcomes it rejects")
    start = len(read(seed_log).rstrip("\n").splitlines()) + 2
    for number, outcome in enumerate(outcomes, 1):
        accepted, found = judge(check_live.entries_of(outcome["append"], start), check_live.SEED_BASE)
        if accepted != (outcome["live"] == "pass"):
            fail(f"{LIVE_CHECK}'s {seed} rule " + ("accepts" if accepted else "rejects") + f" outcome {number} of "
                 f"{FIXTURES}{seed}.expect.json ({found}); the fixture says live: {outcome['live']}")
        judged_outcomes += 1

# The live rules that read the hook log or the usage ledger (WO-3f): S8's
# Stage 0 bound and main-session budget, and S9's skeptic cap. Each case in
# tests/fixtures/live/<check>.json is what a live call could leave (its hook
# log, and S8's ledger lines or the entries S9's call appends to its seed),
# and the check's rule must give it the case's "live" value; each file holds
# cases the rule accepts and cases it rejects, and cites the protocol text it
# tests. S9's accepted cases, appended to its seed, must lint clean.
LIVE_RULES = check_live.LIVE_FIXTURES + "/"
live_rule_files = tracked_files(LIVE_RULES)
live_rule_checks = sorted(os.path.basename(p)[:-len(".json")] for p in live_rule_files if p.endswith(".json"))
if sorted(live_rule_files) != sorted(LIVE_RULES + c + ".json" for c in live_rule_checks) \
        or live_rule_checks != sorted(check_live.LOG_RULE_CHECKS):
    fail(f"{LIVE_RULES} holds exactly one <check>.json for each check whose rule reads the hook log or the ledger "
         f"({', '.join(check_live.LOG_RULE_CHECKS)}); found {live_rule_files!r}")
LIVE_CASE_KEYS = {"note", "live", "events", "session", "ledger", "append", "host_output"}
live_cases = 0
with tempfile.TemporaryDirectory() as tmp:
    for check in live_rule_checks:
        path = LIVE_RULES + check + ".json"
        try:
            fixture = json.loads(read(path))
            cases, cites = fixture["cases"], fixture["cites"]
        except (ValueError, KeyError, TypeError) as e:
            fail(f"{path}: needs 'cites' and 'cases': {e}")
        for cite in cites if isinstance(cites, list) else [None]:
            if not isinstance(cite, dict) or cite.get("file") not in tracked_set or not cite.get("text"):
                fail(f"{path}: each cite needs a tracked 'file' and the 'text' it quotes; got {cite!r}")
            if collapse(cite["text"]) not in collapse(read(cite["file"])):
                fail(f"{path}: {cite['file']} no longer contains the cited text {cite['text']!r}; update the cases "
                     f"with the protocol")
        if not isinstance(cases, list) or {c.get("live") for c in cases if isinstance(c, dict)} != {"pass", "fail"}:
            fail(f"{path}: needs cases the live {check} rule accepts ('live': 'pass') and cases it rejects ('fail')")
        seed = check_live.seed_text(fixture)
        for number, case in enumerate(cases, 1):
            if not isinstance(case, dict) or not set(case) <= LIVE_CASE_KEYS or not {"note", "live", "events"} <= set(case):
                fail(f"{path}: case {number} needs 'note', 'live', and 'events', and only keys from "
                     f"{sorted(LIVE_CASE_KEYS)!r}")
            try:
                accepted, found = check_live.judge_case(check, fixture, case)
            except (check_live.SetupError, check_live.check_logs.ProtocolError) as e:
                fail(f"{path}: case {number}: {e}")
            if accepted != (case["live"] == "pass"):
                fail(f"{LIVE_CHECK}'s {check} rule " + ("accepts" if accepted else "rejects") + f" case {number} of "
                     f"{path} ({case['note']}): {found}; the case says live: {case['live']}")
            if accepted and case.get("append"):
                appended = os.path.join(tmp, f"{check}-{number}.log.md")
                with open(appended, "w", encoding="utf-8") as handle:
                    handle.write(seed.rstrip("\n") + "\n\n" + "\n".join(case["append"]) + "\n")
                run = run_linter(appended)
                if run.returncode != 0:
                    fail(f"{path}: case {number}, appended to its seed, should lint clean:\n{run.stdout}{run.stderr}")
            live_cases += 1


def porcelain_paths(text):
    """The paths git status --porcelain -z lists (a rename's source skipped)."""
    paths, parts = [], text.split("\0")
    index = 0
    while index < len(parts):
        entry = parts[index]
        index += 1
        if len(entry) > 3:
            paths.append(entry[3:])
            if entry[0] in "RC":
                index += 1
    return sorted(paths)


live_repos = live_tests = 0
browser, preflights_run, preflights_skipped = None, [], []
with tempfile.TemporaryDirectory() as tmp:
    claude_stub = os.path.join(tmp, "claude")
    with open(claude_stub, "w", encoding="utf-8") as handle:
        handle.write('#!/bin/sh\n: > "$0.called"\nexit 3\n')
    os.chmod(claude_stub, 0o755)
    live_env = dict(os.environ, CI="1", CLAUDE_BIN=claude_stub, PYTHON=sys.executable)

    def run_live(*args):
        return subprocess.run(["bash", LIVE_RUN, *args], capture_output=True, text=True, env=live_env, timeout=600)

    listing = run_live("--list")
    if listing.returncode != 0:
        fail(f"{LIVE_RUN} --list exited {listing.returncode}: {listing.stderr.strip()}")
    scenarios = re.findall(r"^(\S+) +\S.*\n +seed tests/fixtures/logs/(\S+)\.log\.md(?:, [^;\n]*)?; turns: (.+)$",
                           listing.stdout, re.MULTILINE)
    if sorted(s[0] for s in scenarios) != sorted(LIVE_TWINS):
        fail(f"{LIVE_RUN} --list names the scenarios {[s[0] for s in scenarios]!r}; each needs a static twin in "
             f"LIVE_TWINS, which names {sorted(LIVE_TWINS)!r}")
    turn_checks = set()
    for name, seed, turns in scenarios:
        twin = twin_rows[LIVE_TWINS[name]]
        if seed != twin[1]:
            fail(f"{LIVE_RUN} seeds {name} with {FIXTURES}{seed}.log.md, but its static twin {twin[0]} reads "
                 f"{FIXTURES}{twin[1]}.log.md")
        for turn in turns.split():
            if turn not in check_live.CHECKS:
                fail(f"{LIVE_RUN} runs check {turn!r} for {name}; {LIVE_CHECK} has no such check")
            turn_checks.add(turn)
    unused = [c for c in check_live.CHECKS if c not in turn_checks]
    if unused:
        fail(f"{LIVE_CHECK} has checks no scenario in {LIVE_RUN} runs: {unused!r}")

    dry = run_live("--dry-run", "all")
    if dry.returncode != 0:
        fail(f"{LIVE_RUN} --dry-run all exited {dry.returncode}: {dry.stderr.strip()}")
    for name, _, turns in scenarios:
        wanted = [f"== {name} (run 1 of 1)"] + [f"turn {i}, check {turn}:" for i, turn in enumerate(turns.split(), 1)]
        if any(line not in dry.stdout for line in wanted):
            fail(f"{LIVE_RUN} --dry-run all does not print {name}'s setup and every turn's claude command")
    # Every claude call's --settings carries the hook log: a PreToolUse hook
    # with no matcher that runs check_live.py toollog on this scenario run's
    # file and can never block a call.
    settings_seen, hook_command = 0, None
    for line in dry.stdout.splitlines():
        if claude_stub + " -p " not in line:
            continue
        try:
            words = shlex.split(line.strip())
            settings = json.loads(words[words.index("--settings") + 1])
            hooks = settings["hooks"]["PreToolUse"]
            command = hooks[0]["hooks"][0]["command"]
        except (ValueError, KeyError, IndexError, TypeError) as e:
            fail(f"{LIVE_RUN} --dry-run all prints a claude call whose --settings has no hook log: {e}: {line[:300]}")
        if (len(hooks) != 1 or "matcher" in hooks[0] or settings.get("enabledPlugins") != {"compute-squad@compute-squad": False}
                or not re.search(r"check_live\.py'? toollog '?<out>/\S+/turn[0-9]+\.tools\.jsonl'? >/dev/null 2>&1 \|\| true$",
                                 command)):
            fail(f"{LIVE_RUN} --dry-run all: the --settings hook must be one PreToolUse hook with no matcher running "
                 f"'check_live.py toollog <out>/<run>/turn<n>.tools.jsonl >/dev/null 2>&1 || true'; got {settings!r}")
        settings_seen += 1
        hook_command = hook_command or command
    if settings_seen != sum(len(turns.split()) for _, _, turns in scenarios):
        fail(f"{LIVE_RUN} --dry-run all printed {settings_seen} claude calls with --settings; the scenarios have "
             f"{sum(len(turns.split()) for _, _, turns in scenarios)} turns")
    # The hook as a command hook runs, with sh (and dash where installed), on
    # synthetic PreToolUse input: it prints nothing and exits 0 on every
    # input, one it cannot parse and a log it cannot write included, and
    # writes one record per tool call that keeps what the live checks read,
    # a subagent's agent_id and agent_type, and a prompt cut to 4,000
    # characters with its full length.
    hook_log = os.path.join(tmp, "hook.tools.jsonl")
    hook_path = re.compile(r"'?<out>/\S+/turn[0-9]+\.tools\.jsonl'?")
    main_read = {"session_id": "s", "transcript_path": "/t", "cwd": "/w", "hook_event_name": "PreToolUse",
                 "tool_name": "Read", "tool_input": {"file_path": "/w/src/a.js", "limit": 5}, "tool_use_id": "t1"}
    sub_spawn = {"session_id": "s", "agent_id": "a1", "agent_type": "general-purpose", "cwd": "/w",
                 "hook_event_name": "PreToolUse", "tool_name": "Agent",
                 "tool_input": {"subagent_type": "general-purpose", "model": "fable", "prompt": "x" * 5000}}
    want_records = [
        {"session_id": "s", "cwd": "/w", "tool_name": "Read", "tool_use_id": "t1",
         "tool_input": {"file_path": "/w/src/a.js"}},
        {"session_id": "s", "agent_id": "a1", "agent_type": "general-purpose", "cwd": "/w", "tool_name": "Agent",
         "prompt_chars": 5000, "tool_input": {"subagent_type": "general-purpose", "model": "fable", "prompt": "x" * 4000}},
    ]
    hook_shells = [shell for shell in ("sh", "dash") if shutil.which(shell)]
    for shell in hook_shells:
        for target in (hook_log, os.path.join(tmp, "missing", "hook.tools.jsonl")):
            for payload in (json.dumps(main_read), json.dumps(sub_spawn), "not json", ""):
                run = subprocess.run([shell, "-c", hook_path.sub(lambda _: shlex.quote(target), hook_command)],
                                     input=payload, capture_output=True, text=True, timeout=60)
                if run.returncode != 0 or run.stdout or run.stderr:
                    fail(f"{LIVE_RUN}'s hook-log command under {shell} exited {run.returncode} and printed "
                         f"{(run.stdout + run.stderr)[:300]!r} on {payload[:80]!r}; it must print nothing and exit 0")
    hook_records = check_live.read_tool_log(hook_log)
    if hook_records != want_records * len(hook_shells) \
            or [r.get("tool_name") for r in check_live.main_calls(hook_records)] != ["Read"] * len(hook_shells):
        fail(f"{LIVE_RUN}'s hook-log command wrote {hook_records!r}; expected {want_records!r} under each of "
             f"{hook_shells!r}")

    out = os.path.join(tmp, "out")
    node = shutil.which("node")
    for name, seed, _ in scenarios:
        setup = run_live("--setup-only", "--out", out, name)
        if setup.returncode != 0:
            fail(f"{LIVE_RUN} --setup-only {name} exited {setup.returncode}: {setup.stderr.strip()}\n"
                 f"{setup.stdout[-1500:]}")
        if os.path.exists(claude_stub + ".called"):
            fail(f"{LIVE_RUN} called the claude CLI under --dry-run or --setup-only")
        label = LIVE_TWINS[name]
        state, via = twin_rows[label][2], twin_rows[label][3]
        repo = os.path.join(out, name + "-1", "repo")
        try:
            roots = check_live.git(repo, "rev-list", "--max-parents=0", "HEAD").split()
            head = check_live.git(repo, "rev-parse", "HEAD").strip()
            moved = check_live.git(repo, "diff", "--name-only", "-z", roots[0], "HEAD").split("\0")
            moved = sorted(p for p in moved if p)
            dirty = porcelain_paths(check_live.git(repo, "status", "--porcelain", "-z", "--untracked-files=all"))
        except check_live.SetupError as e:
            fail(f"{LIVE_RUN} --setup-only built no usable repo for {name}: {e}")
        base = roots[0]
        found = {}
        if head != base:
            found["head"], found["moved"] = head[:7], moved
        if dirty:
            found["dirty"] = dirty
        wanted = {k: (sorted(v) if isinstance(v, list) else v) for k, v in state.items() if k in GIT_STATE}
        if set(found) != set(wanted) or any(found[k] != wanted[k] for k in ("moved", "dirty") if k in found):
            fail(f"{LIVE_RUN} {name}: the repo --setup-only builds shows {found!r} against base A, but its static twin "
                 f"{label} ({FIXTURES}{seed}.expect.json) reads {wanted!r}")
        # The live session sees the repo's own HEAD, moved or not.
        live_state = dict(state, head=head[:7])
        seeded = os.path.join(repo, "COMPUTE_SQUAD_LOG.md")
        try:
            got = resume_next.next_action(list(enumerate(read(seeded).splitlines(), 1)), live_state)
        except resume_next.ProtocolError as e:
            fail(f"{LIVE_RUN} {name}: {e}")
        expected = twin_cases[label]["next"].replace(check_live.SEED_BASE, base[:7])
        expected = expected.replace(check_live.SEED_WORKTREE, repo)
        if "head" in state:
            expected = expected.replace(state["head"], head[:7])
        if list(got) != [expected, via]:
            fail(f"{LIVE_RUN} {name}: over the seeded repo the resume table gives {got[0]!r} [{got[1]}], but its "
                 f"static twin {label} gives {expected!r} [{via}]")
        live_repos += 1
        if node:
            script = json.loads(read(os.path.join(repo, "package.json"))).get("scripts", {}).get("test")
            if not script:
                fail(f"{LIVE_RUN} {name}: the fixture's package.json has no test script")
            test = subprocess.run(["sh", "-c", script], cwd=repo, capture_output=True, text=True, timeout=300)
            if test.returncode != 0:
                fail(f"{LIVE_RUN} {name}: npm test's script ({script}) fails on the tree --setup-only builds, so the "
                     f"live scenario would start broken:\n{(test.stdout + test.stderr)[-1500:]}")
            live_tests += 1
        # A scenario whose premise needs its own environment (S5's browser,
        # S5b's missing one, S6b's clock) prints the preflight a live run
        # executes before it spends: run it here as printed. S6b's needs only
        # sh and date; S5's and S5b's need Playwright's Chromium, so they run
        # where it starts.
        preflight = re.search(r"^  preflight:\n    \(cd (.+) &&\n     (.+) \)$", setup.stdout, re.MULTILINE)
        if preflight:
            if os.path.exists(os.path.join(repo, *check_live.BROWSER_CHECK[1].split("/"))):
                if browser is None:
                    probe = subprocess.run(list(check_live.BROWSER_CHECK) + ["--probe"], cwd=repo,
                                           capture_output=True, text=True, timeout=120) if node else None
                    browser = bool(probe) and probe.returncode == 0
                if not browser:
                    preflights_skipped.append(name)
                    continue
            run = subprocess.run(["bash", "-c", f"cd {preflight.group(1)} && {preflight.group(2)}"],
                                 capture_output=True, text=True, timeout=300)
            if run.returncode != 0:
                fail(f"{LIVE_RUN} {name}: the preflight --setup-only prints fails, so the live scenario's premise does "
                     f"not hold:\n{(run.stdout + run.stderr)[-1500:]}")
            preflights_run.append(name)

guard = re.search(r"first run `([^`]+)`\. If it prints a line other than `Next: none`, change nothing and report "
                  r"`ARCHIVE REFUSED: open run` followed by that line\.", read(MECH))
if not guard:
    fail(f"{MECH}: no open-run guard reading \"first run `<command>`. If it prints a line other than `Next: none`, "
         f"change nothing and report `ARCHIVE REFUSED: open run` followed by that line.\"")
guard_shells = [sh for sh in ("sh", "dash", "bash") if shutil.which(sh)]
guard_checked = 0
with tempfile.TemporaryDirectory() as tmp:
    for log in logs:
        shutil.copyfile(log, os.path.join(tmp, "COMPUTE_SQUAD_LOG.md"))
        lines = [(n, t) for n, t in enumerate(read(log).splitlines(), 1)]
        _, source = resume_next.new_run(lines)
        for shell in guard_shells:
            run = subprocess.run([shell, "-c", guard.group(1)], cwd=tmp, capture_output=True, text=True, timeout=60)
            printed = run.stdout.strip()
            refuses = bool(printed) and printed != "Next: none"
            guard_checked += 1
            if run.stderr or refuses != (source == "new run: refuse"):
                fail(f"{MECH}'s open-run guard under {shell} over {log} printed {printed!r}"
                     f"{' and ' + run.stderr.strip() if run.stderr else ''}; the one-active-run rule gives {source!r}")

print(
    f"PASS: check 8: {RESUME_MODEL} reads the {len(resume_rows)} rows of {RESUME_TABLE} and gives the expected next "
    f"action for {sum(len(c) for c in resume_cases.values())} resume cases over {len(resume_cases)} fixture logs, "
    f"covering every row, step, and check on logs that lint clean and the static twins of "
    f"{', '.join(t[0] for t in RESUME_TWINS)}; {LIVE_RUN} --list, --dry-run, and --setup-only work for its "
    f"{live_repos} scenarios without calling claude, and each repo --setup-only builds gives its twin's state and "
    f"next action"
    + (f", with npm test's script passing in all {live_tests}" if live_tests else " (node is not installed, so their "
       "npm test did not run)")
    + (f"; the preflights of {', '.join(preflights_run)} hold as --setup-only prints them" if preflights_run else "")
    + (f" ({', '.join(preflights_skipped)} not run: Playwright's Chromium does not start here)"
       if preflights_skipped else "")
    + f"; the live S5 rule accepts and rejects the {judged_outcomes} outcomes its seed lists as they state"
    + f"; the live {', '.join(live_rule_checks)} rules, which read the hook log and the ledger, give the "
    f"{live_cases} cases in {LIVE_RULES} their stated values, and every claude call --dry-run prints carries "
    f"the hook log in its --settings, whose command writes one record per call and prints nothing under "
    f"{', '.join(hook_shells)}"
    + f"; squad-mech's open-run guard agrees with the one-active-run rule "
    f"over every fixture log ({guard_checked} runs under {', '.join(guard_shells)})"
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
# Over the live seeds in tests/fixtures/logs/ that tests/live/run.sh uses
# (8b reads them from run.sh --list, and each needs a verdict here), every
# executor is denied for s1 (S1 and S8), s2b, s4, and run-parked (S6b) and
# allowed for s2, s2c, s3, s5, s5b, s6a, s7b, and s9. The hook and the plan's
# Attempt: line name the same revision
# (finding 9): a plan whose Attempt: line is wrong does not move the hook's
# count, and over the fixtures with a (cont.) plan or two revisions, a grant
# for the latest plan's Attempt: number allows and a grant for any other
# revision denies.
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
PLAN_ATTEMPT_2 = PLAN.replace("\n\nTasks.", "\nAgent: squad-pm (m)\nAttempt: 2\n\nTasks.")
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
    ("r2 over one plan whose Attempt: line reads 2", GOAL + status("none") + PLAN_ATTEMPT_2 + status(R2), "deny"),
    ("r1 over one plan whose Attempt: line reads 2", GOAL + status("none") + PLAN_ATTEMPT_2 + status(R1), "allow"),
    ("a Grant line outside a Status entry", GOAL + status("none") + PLAN.replace("Tasks.", "Tasks.\nGrant: " + ALL), "deny"),
    ("a grant Decision with no Status after it", GOAL + status("none") + PLAN + DECISION, "deny"),
    ("a later Status that revokes", GOAL + status(ALL) + PLAN + status("none"), "deny"),
    ("a later Status that grants", GOAL + status("none") + PLAN + status(ALL), "allow"),
]
SEED_VERDICTS = [("s1", "deny"), ("s2", "allow"), ("s2b", "deny"), ("s2c", "allow"), ("s3", "allow"),
                 ("s4", "deny"), ("s5", "allow"), ("s5b", "allow"), ("s6a", "allow"), ("run-parked", "deny"),
                 ("s7b", "allow"), ("s9", "allow")]
unjudged = sorted(set(seed for _, seed, _ in scenarios) - set(seed for seed, _ in SEED_VERDICTS))
if unjudged:
    fail(f"check 8c needs the grant hook's verdict over every live seed {LIVE_RUN} uses; none for {unjudged!r}")
ATTEMPT_SEEDS = ["plan-cont", "fail-reruns", "s2b"]
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
    # empty log, S2b's grant for r1 under plan r2, and S4's Grant: none deny,
    # S2's r1 WO-1 grant allows. S2c allows too: its zero spawns rest on the
    # work-order scope of a grant, which this hook does not check, so 8b
    # covers S2c. S3's r1 WO-1 grant allows before the base check, which is
    # 8b's, and S7b's allows too: the three-FAIL stop is the main session's,
    # so 8b covers it. S5's r1 grant, and S5b's and S6a's full-mode grants,
    # allow: S5 and S6a spawn no executor because their next action is ACCEPT
    # and the high-stakes review (8b), and S5b's stop is Recon's needs-human:
    # blocker, which this hook then holds (check_live.py asserts it). S6b's
    # parked plan-mode log denies. S9's r1 WO-1 grant allows: it spawns no
    # executor because its next action is the audit (8b).
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
    # The hook's revision is the latest plan's Attempt: number.
    for seed in ATTEMPT_SEEDS:
        seed_text = read(FIXTURES + seed + ".log.md")
        plan_attempts = re.findall(r"^## PM — Plan\nTimestamp: [^\n]*\nAgent: [^\n]*\nAttempt: ([0-9]+)$", seed_text, re.M)
        if not plan_attempts:
            fail(f"check 8c: {FIXTURES}{seed}.log.md has no ## PM — Plan entry with an Attempt: line")
        latest = int(plan_attempts[-1])
        for revision in range(1, latest + 2):
            grant = f"r{revision} all, per Decision 2026-09-01T09:07:00Z"
            expected = "allow" if revision == latest else "deny"
            with open(log, "w", encoding="utf-8") as handle:
                handle.write(seed_text.rstrip("\n") + "\n\n" + status(grant))
            for shell in shells:
                got = gate(shell, payload("compute-squad:" + executors[0], repo), tmp)
                checked += 1
                if got != expected:
                    fail(f"{GATE} under {shell}: {FIXTURES}{seed}.log.md, whose latest plan reads 'Attempt: "
                         f"{latest}', with a grant for r{revision}: expected {expected}, got {got}")
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
    f"{', '.join(f'{seed} {verdict}' for seed, verdict in SEED_VERDICTS)}; allowed only for the latest plan's "
    f"Attempt: number over {', '.join(ATTEMPT_SEEDS)}; {', '.join(executors + held)} held while a "
    f"needs-human: blocker has no ## Decision after it; and {HOLD_EXEMPT} always allowed"
)

# ---- 8d: the archive command and the closing archive (findings 3, 11, and
# 26). The command in SKILL.md's Hard rules, and the PM's form of it, run in
# temp dirs under sh (and dash and bash where installed). On a plain log the
# copy equals the log, the PM's form ends it with the Archive target: line it
# printed, and the log is left empty. When a shim corrupts the destination
# then runs real cmp, the command exits nonzero, the copy is written, and the log keeps
# its sha256, apart from the PM form's intent line: it clears only after cmp.
# When a date shim makes the name collide
# with an existing archive, or the archive directory cannot be written, the
# command exits nonzero and truncates nothing: every file keeps its sha256,
# apart from the PM form's intent line when only the copy fails. Then
# squad-mech's close guard, taken from its body, runs over every fixture log
# and the example log's entries: it allows the closing archive exactly where
# the latest ## High-stakes review reads Result: upheld, and there the
# command's copy holds the whole log, review entry included, and the log is
# left empty; the example log, whose review is upheld, must be among those
# closed. Last, the live seeds' twins: S6a's seed, which ends in a
# high-stakes PASS, is refused, and closed with the review in the copy once a
# Status, the review from SKILL.md's template filled in as upheld, and a
# Status are appended (a log that must lint clean); over S6b's seed the
# open-run guard allows Stage 1, and under the date shim, with an archive
# already at the name, the command exits nonzero and changes no file.
import hashlib  # noqa: E402
import check_logs  # noqa: E402  (tests/ is on sys.path since 8b)

ARCHIVE_RULE = "- Every archive copy is written by this command and nothing else"
skill_lines = read("skills/compute-squad/SKILL.md").splitlines()
rule_at = next((i for i, line in enumerate(skill_lines) if line.startswith(ARCHIVE_RULE)), None)
if rule_at is None:
    fail(f"skills/compute-squad/SKILL.md: no Hard-rules bullet starting {ARCHIVE_RULE!r}")
fence_at = next(i for i in range(rule_at + 1, len(skill_lines)) if skill_lines[i].strip())
if skill_lines[fence_at:fence_at + 1] != ["```bash"] or skill_lines[fence_at + 3:fence_at + 4] != ["```"]:
    fail("skills/compute-squad/SKILL.md: the archive command must be a two-line ```bash block right after its rule")
archive_first, archive_second = skill_lines[fence_at + 1:fence_at + 3]
pm_prefix = re.search(r"The PM's form inserts `([^`]+)` at the start of the second line", skill_lines[rule_at])
if not pm_prefix:
    fail("skills/compute-squad/SKILL.md: the archive rule no longer names the PM's prefix")
ARCHIVE_FORMS = {
    "squad-mech": archive_first + "\n" + archive_second + "\n",
    "PM": archive_first + "\n" + pm_prefix.group(1) + archive_second + "\n",
}
close = re.search(r"When told to close a run, first run `([^`]+)`\. If it does not print exactly `([^`]+)`, change "
                  r"nothing", read(MECH))
if not close:
    fail(f"{MECH}: no close guard reading \"When told to close a run, first run `<command>`. If it does not print "
         f"exactly `<line>`, change nothing\"")
close_guard, close_line = close.group(1), close.group(2)
if close_line != "Result: upheld":
    fail(f"{MECH}: the close guard must wait for 'Result: upheld', not {close_line!r}")
ARCHIVED = re.compile(r"archived and cleared: (compute-squad-archive/COMPUTE_SQUAD_LOG_\d{4}-\d{2}-\d{2}_\d{6}_(\S+)\.md)")
FIXED_STAMP = "2026-01-02_030405"
archive_shells = [sh for sh in ("sh", "dash", "bash") if shutil.which(sh)]
if "sh" not in archive_shells:
    fail("check 8d needs sh, which runs the archive command on every host")


def tree_hashes(root):
    """{relative path: sha256, or 'dir'} for everything under root."""
    found = {}
    for top, dirs, files in os.walk(root):
        for name in dirs:
            found[os.path.relpath(os.path.join(top, name), root)] = "dir"
        for name in files:
            path = os.path.join(top, name)
            with open(path, "rb") as handle:
                found[os.path.relpath(path, root)] = hashlib.sha256(handle.read()).hexdigest()
    return found


def run_shell(shell, script, cwd, path_prefix=None):
    env = dict(os.environ)
    if path_prefix:
        env["PATH"] = path_prefix + os.pathsep + env.get("PATH", "")
    return subprocess.run([shell, "-c", script], cwd=cwd, capture_output=True, text=True, env=env, timeout=60)


def fresh_dir(parent, name, log_text):
    root = os.path.join(parent, name)
    os.makedirs(root)
    with open(os.path.join(root, "COMPUTE_SQUAD_LOG.md"), "w", encoding="utf-8") as handle:
        handle.write(log_text)
    return root


SAMPLE = read(FIXTURES + "review-upheld.log.md")
sample_run = re.search(r"^Run: (\S+)$", SAMPLE, re.MULTILINE).group(1)
archive_runs = 0
with tempfile.TemporaryDirectory() as tmp:
    shim = os.path.join(tmp, "shim")
    os.makedirs(shim)
    with open(os.path.join(shim, "date"), "w", encoding="utf-8") as handle:
        handle.write(f"#!/bin/sh\necho {FIXED_STAMP}\n")
    os.chmod(os.path.join(shim, "date"), 0o755)
    cmp_shim = os.path.join(tmp, "cmp-shim")
    os.makedirs(cmp_shim)
    with open(os.path.join(cmp_shim, "cmp"), "w", encoding="utf-8") as handle:
        handle.write("#!/bin/sh\nfor copy in compute-squad-archive/*.md; do printf '\\ncorrupted copy\\n' >> \"$copy\"; done\n"
                     + "exec " + shlex.quote(shutil.which("cmp")) + ' "$@"\n')
    os.chmod(os.path.join(cmp_shim, "cmp"), 0o755)
    cmp_kept = 0
    collided = f"compute-squad-archive/COMPUTE_SQUAD_LOG_{FIXED_STAMP}_{sample_run}.md"
    for shell in archive_shells:
        for form, command in ARCHIVE_FORMS.items():
            label = f"the {form} archive command under {shell}"
            # A plain log: an exact copy, then an empty log.
            root = fresh_dir(tmp, f"{shell}-{form}-plain", SAMPLE)
            run = run_shell(shell, command, root)
            archive_runs += 1
            printed = ARCHIVED.fullmatch(run.stdout.strip())
            if run.returncode != 0 or not printed or printed.group(2) != sample_run:
                fail(f"{label} on a plain log exited {run.returncode} and printed {run.stdout.strip()!r} "
                     f"{run.stderr.strip()!r}; expected 'archived and cleared: <archive named for {sample_run}>'")
            copy = read(os.path.join(root, printed.group(1)))
            wanted = SAMPLE + (f"Archive target: {printed.group(1)}\n" if form == "PM" else "")
            if copy != wanted:
                fail(f"{label}: the archive copy is not the log" + (" ending with its Archive target: line" if form == "PM" else ""))
            if os.path.getsize(os.path.join(root, "COMPUTE_SQUAD_LOG.md")) != 0:
                fail(f"{label}: the active log is not empty after 'archived and cleared:'")
            # A corrupted destination checked by real cmp: wrong operands must not pass.
            # the command exits nonzero and clears nothing. The log keeps its
            # sha256 (the PM form's Archive target: line apart), and the only
            # new file is the copy.
            root = fresh_dir(tmp, f"{shell}-{form}-cmp", SAMPLE)
            run = run_shell(shell, command, root, path_prefix=cmp_shim)
            archive_runs += 1
            log_now = read(os.path.join(root, "COMPUTE_SQUAD_LOG.md"))
            kept = log_now == SAMPLE or (
                form == "PM" and re.fullmatch(re.escape(SAMPLE) + r"Archive target: \S+\n", log_now) is not None)
            left = sorted(tree_hashes(root))
            copies = [p for p in left if p.startswith("compute-squad-archive" + os.sep)]
            if run.returncode == 0 or "archived and cleared" in run.stdout or not kept or len(copies) != 1 \
                    or set(left) != {"COMPUTE_SQUAD_LOG.md", "compute-squad-archive"} | set(copies):
                fail(f"{label}: when cmp fails it must exit nonzero, print no 'archived and cleared', and leave the log "
                     f"as it was" + (" apart from its Archive target: line" if form == "PM" else "") + f"; it exited "
                     f"{run.returncode}, printed {run.stdout.strip()!r}, and left {left!r} with the log "
                     + ("kept" if kept else "changed"))
            cmp_kept += 1
            # A name collision, forced by the date shim: nothing changes.
            root = fresh_dir(tmp, f"{shell}-{form}-collision", SAMPLE)
            os.makedirs(os.path.join(root, "compute-squad-archive"))
            with open(os.path.join(root, collided), "w", encoding="utf-8") as handle:
                handle.write("an earlier run's archive\n")
            before = tree_hashes(root)
            run = run_shell(shell, command, root, path_prefix=shim)
            archive_runs += 1
            if run.returncode == 0 or "archived and cleared" in run.stdout or not run.stderr.strip() or tree_hashes(root) != before:
                fail(f"{label}: over an existing {collided} it must exit nonzero and change no file; it exited "
                     f"{run.returncode} and printed {run.stdout.strip()!r}")
            # An archive directory that cannot be written: a file stands in
            # its place, and, when not running as root, a read-only directory.
            blockers = ["file"] + (["read-only"] if os.geteuid() != 0 else [])
            for blocker in blockers:
                root = fresh_dir(tmp, f"{shell}-{form}-{blocker}", SAMPLE)
                archive_dir = os.path.join(root, "compute-squad-archive")
                if blocker == "file":
                    with open(archive_dir, "w", encoding="utf-8") as handle:
                        handle.write("not a directory\n")
                else:
                    os.makedirs(archive_dir)
                    os.chmod(archive_dir, 0o555)
                before = tree_hashes(root)
                run = run_shell(shell, command, root)
                archive_runs += 1
                if blocker != "file":
                    os.chmod(archive_dir, 0o755)
                after = tree_hashes(root)
                log_now = read(os.path.join(root, "COMPUTE_SQUAD_LOG.md"))
                intent = re.fullmatch(re.escape(SAMPLE) + r"Archive target: \S+\n", log_now)
                if form == "PM" and intent:
                    after["COMPUTE_SQUAD_LOG.md"] = before["COMPUTE_SQUAD_LOG.md"]
                if run.returncode == 0 or "archived and cleared" in run.stdout or after != before:
                    fail(f"{label}: with an unwritable archive directory ({blocker}) it must exit nonzero and truncate "
                         f"nothing; it exited {run.returncode} and printed {run.stdout.strip()!r}")

    # The closing archive: squad-mech's close guard, then its command.
    close_logs = [(log, read(log)) for log in logs]
    example_entries = "".join(text + "\n" for _, text in check_logs.read_log("docs/example-log.md", True))
    close_logs.append(("docs/example-log.md (its entries)", example_entries))
    closed = refused = example_closes = 0
    for name, text in close_logs:
        _, entries = check_logs.split_entries(list(enumerate(text.splitlines(), 1)))
        reviews = [e for e in entries if e["heading"] == check_logs.REVIEW_HEADING]
        latest = next((x[len("Result: "):] for _, x in reviews[-1]["body"] if x.startswith("Result: ")), None) \
            if reviews else None
        for shell in archive_shells:
            root = fresh_dir(tmp, f"close-{closed + refused}-{shell}", text)
            before = tree_hashes(root)
            guard = run_shell(shell, close_guard, root)
            allows = guard.stdout.rstrip("\n") == close_line
            if guard.stderr or tree_hashes(root) != before or allows != (latest == "upheld"):
                fail(f"{MECH}'s close guard under {shell} over {name} printed {guard.stdout.strip()!r} "
                     f"{guard.stderr.strip()!r}; the latest {check_logs.REVIEW_HEADING} reads {latest!r}, and only "
                     f"'upheld' allows the closing archive")
            if not allows:
                refused += 1
                continue
            run = run_shell(shell, ARCHIVE_FORMS["squad-mech"], root)
            printed = ARCHIVED.fullmatch(run.stdout.strip())
            copy = read(os.path.join(root, printed.group(1))) if printed else ""
            if run.returncode != 0 or copy != text or check_logs.REVIEW_HEADING not in copy.splitlines():
                fail(f"the closing archive under {shell} over {name} exited {run.returncode}; its copy must be the "
                     f"whole log, {check_logs.REVIEW_HEADING} entry included")
            if os.path.getsize(os.path.join(root, "COMPUTE_SQUAD_LOG.md")) != 0:
                fail(f"the closing archive under {shell} over {name} left the active log non-empty")
            closed += 1
            example_closes += name == close_logs[-1][0]

    # S6a's static twin (section 6): its live seed ends in a high-stakes
    # PASS, so the close guard refuses it. Appended to it, what S6a's main
    # session appends: a ## Status, the review from SKILL.md's template filled
    # in as upheld, and the ## Status after it. That log lints clean, the
    # guard allows it, and the closing archive's copy is the whole log,
    # review included, with the active log left empty.
    s6a_seed = read(FIXTURES + "s6a.log.md")
    s6a_entries = check_logs.split_entries(list(enumerate(s6a_seed.splitlines(), 1)))[1]
    seed_status = [text for _, text in [e for e in s6a_entries if e["heading"] == "## Status"][-1]["body"]]
    seed_tested = next(text for e in s6a_entries if e["heading"] == "## PM — PASS"
                       for _, text in e["body"] if text.startswith("Tested: "))

    def s6a_status(stamp, following):
        lines = ["## Status"]
        for text in seed_status:
            if text.startswith("Timestamp: "):
                text = "Timestamp: " + stamp
            elif text.startswith("Next: "):
                text = "Next: " + following
            lines.append(text)
        return "\n".join(lines).rstrip("\n") + "\n"

    review_at = next((i for i in range(len(skill_lines) - 1)
                      if skill_lines[i] == "```markdown" and skill_lines[i + 1] == check_logs.REVIEW_HEADING), None)
    if review_at is None:
        fail(f"skills/compute-squad/SKILL.md: no ```markdown block opening with {check_logs.REVIEW_HEADING}")
    review_values = {"Timestamp": "2026-09-15T10:36:40Z", "Agent": "main session (claude-fable-5-1)",
                     "Result": "upheld", "Tested": seed_tested[len("Tested: "):]}
    review_items = {
        "Checked": ["- `npm test` -> exit 0; tests 8, pass 8, fail 0"],
        "Risks": ["- auth: a refused request tells another account or an anonymous caller that the account exists | "
                  "test (a): the refused response deep-equals the first, and the diff adds no log call"],
        "Decisions after lock": ["- none"],
    }
    review = [check_logs.REVIEW_HEADING]
    for text in skill_lines[review_at + 2:]:
        if text == "```":
            break
        key, _, value = text.partition(": ")
        if text.startswith("- "):
            continue
        if text.endswith(":") and text[:-1] in review_items:
            review += [text] + review_items[text[:-1]]
        elif key == "Rerun":
            continue   # an upheld review has no Rerun: line
        elif key in review_values:
            review.append(f"{key}: {review_values[key]}")
        else:
            fail(f"skills/compute-squad/SKILL.md: the {check_logs.REVIEW_HEADING} template line {text!r} is new to "
                 f"check 8d's S6a twin; teach it a value")
    reviewed = "\n".join([
        s6a_seed.rstrip("\n"), "", s6a_status("2026-09-15T10:31:12Z", "main-session high-stakes review").rstrip("\n"),
        "", "\n".join(review), "", s6a_status("2026-09-15T10:36:48Z", "spawn squad-mech for the closing archive"),
    ])
    count, problems = check_logs.lint(list(enumerate(reviewed.splitlines(), 1)), check_logs.load_protocol(SKILL))
    if problems:
        fail("check 8d's S6a twin: the s6a seed with a Status, an upheld review, and a Status appended does not lint "
             "clean: " + "; ".join(f"line {line} [{rule}] {message}" for line, rule, message in problems[:5]))
    s6a_closed = 0
    for shell in archive_shells:
        for text, allowed in ((s6a_seed, False), (reviewed, True)):
            root = fresh_dir(tmp, f"s6a-{shell}-{allowed}", text)
            guard_run = run_shell(shell, close_guard, root)
            if (guard_run.stdout.rstrip("\n") == close_line) != allowed:
                fail(f"{MECH}'s close guard under {shell} " + ("refused" if allowed else "allowed")
                     + " the S6a log " + ("after" if allowed else "before") + f" its upheld review; it printed "
                     f"{guard_run.stdout.strip()!r}")
            if not allowed:
                continue
            run = run_shell(shell, ARCHIVE_FORMS["squad-mech"], root)
            printed = ARCHIVED.fullmatch(run.stdout.strip())
            copy = read(os.path.join(root, printed.group(1))) if printed else ""
            if run.returncode != 0 or copy != text or os.path.getsize(os.path.join(root, "COMPUTE_SQUAD_LOG.md")) != 0:
                fail(f"S6a's closing archive under {shell} exited {run.returncode}; its copy must be the whole log, "
                     f"review included, and the active log must be left empty")
            s6a_closed += 1

    # S6b's static twin (section 6, finding 11): over its live seed,
    # run-parked, squad-mech's open-run guard lets Stage 1 archive the parked
    # run, and under a date shim with an archive already at the name the
    # command gives that log, the command exits nonzero and changes no file.
    s6b_seed = read(FIXTURES + "run-parked.log.md")
    open_guard = re.search(r"first run `([^`]+)`\. If it prints a line other than `Next: none`", read(MECH)).group(1)
    s6b_run = re.search(r"^Run: (\S+)$", s6b_seed, re.MULTILINE).group(1)
    s6b_target = f"compute-squad-archive/COMPUTE_SQUAD_LOG_{FIXED_STAMP}_{s6b_run}.md"
    s6b_refused = 0
    for shell in archive_shells:
        root = fresh_dir(tmp, f"s6b-{shell}", s6b_seed)
        guard_run = run_shell(shell, open_guard, root)
        if guard_run.stdout.strip() != "Next: none":
            fail(f"{MECH}'s open-run guard under {shell} over S6b's seed printed {guard_run.stdout.strip()!r}; the parked "
                 f"run reads 'Next: none', so Stage 1 archives it")
        os.makedirs(os.path.join(root, "compute-squad-archive"))
        with open(os.path.join(root, s6b_target), "w", encoding="utf-8") as handle:
            handle.write(s6b_seed.split("\n\n", 1)[0] + "\n")
        before = tree_hashes(root)
        run = run_shell(shell, ARCHIVE_FORMS["squad-mech"], root, path_prefix=shim)
        if run.returncode == 0 or "archived and cleared" in run.stdout or tree_hashes(root) != before:
            fail(f"squad-mech's archive command under {shell} over S6b's seed, with {s6b_target} already there, must "
                 f"exit nonzero and change no file; it exited {run.returncode} and printed {run.stdout.strip()!r}")
        s6b_refused += 1
example_closed = check_logs.split_entries(list(enumerate(example_entries.splitlines(), 1)))[1]
if example_closes != len(archive_shells):
    fail(f"docs/example-log.md: its closing archive ran under {example_closes} of {len(archive_shells)} shells; the "
         f"example's latest {check_logs.REVIEW_HEADING} must read Result: upheld, so squad-mech's close guard allows it")
if [e["heading"] for e in example_closed[-2:]] != [check_logs.REVIEW_HEADING, "## Status"]:
    fail(f"docs/example-log.md: the closing archive copies a log that ends with the upheld {check_logs.REVIEW_HEADING} "
         f"and the ## Status after it; its last two entries are {[e['heading'] for e in example_closed[-2:]]!r}")
if not closed or not refused:
    fail(f"check 8d needs a fixture whose latest review is upheld and one where the close guard refuses; "
         f"closed {closed}, refused {refused}")

print(
    f"PASS: check 8: the archive command and the PM's form copied exactly and cleared only after cmp (a failing cmp "
    f"shim kept the log in {cmp_kept} runs), and changed nothing on a name collision or an unwritable archive "
    f"directory ({archive_runs} runs under {', '.join(archive_shells)}); squad-mech's close guard allowed the closing archive only after an upheld "
    f"{check_logs.REVIEW_HEADING} ({closed} closing archives, each holding the review entry, the example log's "
    f"included, and {refused} refusals); S6a's seed is refused, then closed with its review in the copy once the review "
    f"from SKILL.md's template is appended ({s6a_closed} runs), and S6b's seed passes the open-run guard but its "
    f"colliding archive changes no file ({s6b_refused} runs)"
)

# ---- 8e: codex/update.sh with stubs. The updater runs with
# tests/stubs/codex standing in for both git and codex (it acts as the name
# it is called by and records every call), in a temp CODEX_HOME seeded with
# the five retired agents, a stale squad-pm.toml, a stale profile, files that
# belong to the user, and the remote compute-squad@compute-squad plugin that
# earlier releases installed. The stub catalog lists the release pins, three
# models to choose (stub-top, stub-mid, stub-low), one hidden and one
# retired model. The scenarios run in order on one CODEX_HOME and are named
# in the PASS line: the refusals before anything is chosen (--review-models
# or no saved choices without a terminal, a dirty checkout, a failed plugin
# list, another installed copy of the plugin); the chooser (Enter keeps the
# release defaults, labelled as such; each rejection with its reason; `no`
# and end of input cancel); first setup; routine updates (same catalog, a
# failed or unreadable catalog, a leftover build.new, a held lock); two
# overlapping updates (a review while a scheduled update installs, and a
# scheduled update while a review waits for answers), driven in lockstep by
# the stub's pause point, where the second must stop at the lock with the
# saved choices byte for byte; the catalog fingerprint; a changed catalog
# without and with a terminal;
# unreadable saved choices; and a saved model the catalog retires or drops.
# The source (the stub git answers rev-parse from STUB_GIT_* variables): by
# default main tracking origin/main is confirmed before the pull and HEAD must
# equal origin/main after it; --source-sha installs an approved commit from
# any branch without a pull. Source drift (another branch, another or no
# upstream, a local commit, a checkout not at the approved commit) stops
# before any codex call. --check must report a match, then name on its own
# each of a stale main skill, a stale referenced file, a hook without its
# executable bit, an extra cached file, a changed agent, a missing profile, a
# second copy of the plugin, a drifted approved commit, and uncommitted
# changes, while leaving CODEX_HOME byte for byte, this checkout's status,
# and every git and codex call read-only. An install the stub lands with the
# wrong content must fail without the success line.
# Every install must put the plugin, agents, and profiles from one build that
# carries the saved choices, check them against a fresh render, remove the
# remote plugin, prune the retired agents, and leave the user's files and
# this checkout as they were. Every
# cancelled, refused, or stopped run must leave CODEX_HOME byte for byte as
# it was and make no codex plugin call beyond `plugin list`. Every run has a
# timeout. Last, codex/build-agents.py --validate-catalog runs on its own
# against stub catalogs, one per remaining rule.
import pty  # noqa: E402
import signal  # noqa: E402
import termios  # noqa: E402

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

# The release pins: every model and effort the committed TOMLs and profiles
# name. The validator cases below use them.
pinned = {}
for text in [read(p).split("developer_instructions", 1)[0] for p in agent_tomls] + list(profiles.values()):
    model = re.search(r'^model\s*=\s*"([^"]+)"', text, re.MULTILINE)
    effort = re.search(r'^model_reasoning_effort\s*=\s*"([^"]+)"', text, re.MULTILINE)
    if not model or not effort:
        fail(f"a codex/agents TOML or codex/profiles.toml table has no model or effort line:\n{text}")
    pinned.setdefault(model.group(1), set()).add(effort.group(1))

STUB_EFFORTS = ("low", "medium", "high", "xhigh", "max")
PAST = "2000-01-01T00:00:00Z"


def stub_entry(model, efforts=None, visibility="list", upgrade=None, **extra):
    entry = {
        "slug": model,
        "visibility": visibility,
        "supported_reasoning_levels": [{"effort": e} for e in sorted(efforts or pinned.get(model, {"medium"}))],
        "upgrade": upgrade,
    }
    entry.update(extra)
    return entry


def stub_catalog(models, extra=()):
    entries = [stub_entry(model) for model in models] + list(extra)
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


def changed_paths(before, after):
    return sorted(p for p in set(before) | set(after) if before.get(p, 0) != after.get(p, 0))


CHOOSE = [stub_entry(m, STUB_EFFORTS) for m in ("stub-top", "stub-mid", "stub-low")]
HIDDEN = stub_entry("stub-hidden", STUB_EFFORTS, visibility="hide")
RETIRING = stub_entry("stub-retired", STUB_EFFORTS, upgrade={"model": None, "retirement_at": PAST})
BASE_ENTRIES = [stub_entry(m) for m in sorted(pinned)] + CHOOSE + [HIDDEN, RETIRING]
CHOSEN = {"top": ("stub-top", "max"), "mid": ("stub-mid", "xhigh"), "bottom": ("stub-low", "max")}
MAIN_EFFORT = "high"
REPO = os.getcwd()
real_git = shutil.which("git")
repo_status = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, timeout=120).stdout


def write_catalog(path, entries):
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"models": entries}, f, indent=2)


with tempfile.TemporaryDirectory() as tmp:
    bin_dir = os.path.join(tmp, "bin")
    codex_home = os.path.join(tmp, "codex-home")
    agents_dir = os.path.join(codex_home, "agents")
    stub_state = os.path.join(tmp, "stub-state")
    stub_log = os.path.join(tmp, "stub-calls.txt")
    catalog_path = os.path.join(tmp, "catalog.json")
    choices_path = os.path.join(codex_home, "compute-squad", "choices.conf")
    build_dir = os.path.join(codex_home, "compute-squad", "build")
    remote_cache = os.path.join(codex_home, "plugins", "cache", "compute-squad", "compute-squad")
    for d in (bin_dir, agents_dir, os.path.join(tmp, "home"), os.path.join(stub_state, "installed"),
              os.path.join(remote_cache, "4.4.0")):
        os.makedirs(d)
    for tool in ("git", "codex"):
        shutil.copyfile("tests/stubs/codex", os.path.join(bin_dir, tool))
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
    with open(os.path.join(remote_cache, "4.4.0", "SKILL.md"), "w", encoding="utf-8") as f:
        f.write("remote release copy\n")
    with open(os.path.join(stub_state, "installed", "compute-squad@compute-squad"), "w", encoding="utf-8") as f:
        f.write("4.4.0\n")

    env = dict(
        os.environ,
        HOME=os.path.join(tmp, "home"),
        CODEX_HOME=codex_home,
        GIT_BIN=os.path.join(bin_dir, "git"),
        CODEX_BIN=os.path.join(bin_dir, "codex"),
        STUB_LOG=stub_log,
        STUB_CATALOG=catalog_path,
        STUB_STATE=stub_state,
        STUB_REAL_GIT=real_git or "git",
    )
    env.pop("STUB_GIT_STATUS", None)

    runs = []

    def start_update(label, args=(), terminal=False, extra_env=None, log=None):
        """Start codex/update.sh in its own session, its output going to
        files, so a check can start a second update while this one runs. With
        terminal, its stdin is a pty the answers are typed into later."""
        log = log or stub_log
        if os.path.exists(log):
            os.remove(log)
        runs.append(label)
        out_path = os.path.join(tmp, f"run-{len(runs)}.out")
        err_path = os.path.join(tmp, f"run-{len(runs)}.err")
        master = None
        if terminal:
            master, stdin = pty.openpty()
            attrs = termios.tcgetattr(stdin)
            attrs[3] &= ~termios.ECHO
            termios.tcsetattr(stdin, termios.TCSANOW, attrs)
        else:
            stdin = subprocess.DEVNULL
        with open(out_path, "w", encoding="utf-8") as out_f, open(err_path, "w", encoding="utf-8") as err_f:
            proc = subprocess.Popen(["bash", "codex/update.sh", *args], env=dict(env, STUB_LOG=log, **(extra_env or {})),
                                    stdin=stdin, stdout=out_f, stderr=err_f, start_new_session=True)
        if master is not None:
            os.close(stdin)
        return {"label": label, "proc": proc, "master": master, "out": out_path, "err": err_path, "log": log}

    def finish_update(run, answers=None):
        """Type the answers, if any, and wait for the run. A timeout kills the
        updater and every process it started (a chooser waiting for input
        would otherwise hang this check)."""
        try:
            if answers is not None:
                os.write(run["master"], answers.encode("utf-8"))
            run["proc"].wait(timeout=120)
        except subprocess.TimeoutExpired:
            os.killpg(run["proc"].pid, signal.SIGKILL)
            run["proc"].wait()
            fail(f"codex/update.sh ({run['label']}) did not finish within 120 seconds:\n"
                 f"{read(run['out'])}{read(run['err'])}")
        finally:
            if run["master"] is not None:
                os.close(run["master"])
        calls = read(run["log"]).splitlines() if os.path.exists(run["log"]) else []
        return run["proc"].returncode, read(run["out"]), read(run["err"]), calls

    def run_update(label, args=(), answers=None, extra_env=None):
        """Run codex/update.sh; answers, when given, are typed on a terminal."""
        return finish_update(start_update(label, args, answers is not None, extra_env), answers)

    def wait_for(what, ready, run):
        """Wait until ready() holds while run is still going."""
        deadline = time.monotonic() + 60
        while not ready():
            if run["proc"].poll() is not None or time.monotonic() > deadline:
                if run["proc"].poll() is None:
                    os.killpg(run["proc"].pid, signal.SIGKILL)
                    run["proc"].wait()
                fail(f"codex/update.sh ({run['label']}): waited for {what}; it exited {run['proc'].returncode}:\n"
                     f"{read(run['out'])}{read(run['err'])}")
            time.sleep(0.05)

    def expect(label, cond, what, rc, out, err, calls):
        if not cond:
            fail(f"codex/update.sh ({label}): {what}; it exited {rc}, calls {calls!r}:\n{out}{err}")

    def expect_untouched(label, before, rc, out, err, calls):
        after = snapshot(codex_home)
        expect(label, after == before, f"CODEX_HOME changed: {changed_paths(before, after)!r}", rc, out, err, calls)
        mutating = [c for c in calls if c.startswith("codex plugin") and c != "codex plugin list --json"]
        expect(label, not mutating, f"it made codex plugin calls {mutating!r}", rc, out, err, calls)

    def git_call(call):
        """A stub git call on this repo, as the words after its -C option."""
        match = re.fullmatch(r"git -C (\S+) (.*)", call)
        if not match or os.path.realpath(match.group(1)) != os.path.realpath(REPO):
            return None
        return match.group(2)

    # The default source: main tracking origin/main is checked before the
    # pull, and HEAD must equal origin/main after it; the checkout's cleanliness
    # is read last. Every read passes --no-optional-locks, so it never writes
    # the index.
    DEFAULT_SOURCE = [
        "--no-optional-locks rev-parse --abbrev-ref HEAD",
        "--no-optional-locks rev-parse --abbrev-ref --symbolic-full-name @{upstream}",
        "pull --ff-only",
        "--no-optional-locks rev-parse HEAD",
        "--no-optional-locks rev-parse @{upstream}",
        "--no-optional-locks status --porcelain --untracked-files=no",
    ]

    def expect_default_source(label, rc, out, err, calls):
        git_calls = [git_call(c) for c in calls if c.startswith("git ")]
        expect(label, git_calls[:len(DEFAULT_SOURCE)] == DEFAULT_SOURCE,
               f"its first git calls on this repo should be {DEFAULT_SOURCE!r}", rc, out, err, calls)

    def saved_choices():
        text = read(choices_path)
        tiers = dict((m.group(1), (m.group(2), m.group(3))) for m in re.finditer(
            r"^(top|mid|bottom)\s+(\S+)\s+(\S+)$", text, re.MULTILINE))
        main = re.search(r"^main_effort (\S+)$", text, re.MULTILINE)
        fingerprint = re.search(r"^catalog ([0-9a-f]{64})$", text, re.MULTILINE)
        return text, tiers, main and main.group(1), fingerprint and fingerprint.group(1)

    def catalog_status():
        run = subprocess.run([sys.executable, "codex/build-agents.py", "--catalog-status", catalog_path, choices_path],
                             capture_output=True, text=True, timeout=120)
        if run.returncode != 0:
            fail(f"codex/build-agents.py --catalog-status exited {run.returncode}:\n{run.stdout}{run.stderr}")
        return run.stdout.strip()

    def expect_installed(label, rc, out, err, calls):
        """The plugin, agents, and profiles all come from the one build, which
        carries the saved choices, and the remote plugin is gone."""
        _text, tiers, main, _fp = saved_choices()
        version = json.loads(read(".codex-plugin/plugin.json"))["version"]
        cache = os.path.join(codex_home, "plugins", "cache", "compute-squad-local", "compute-squad", version)
        built = os.path.join(build_dir, "plugins", "compute-squad")
        expect(label, os.path.isdir(cache) and snapshot(cache) == snapshot(built),
               "the cached plugin should equal the rendered build's plugin", rc, out, err, calls)
        payload = sorted(tracked_files(".codex-plugin", "skills"))
        executables = [line.split("\t", 1)[1] for line in subprocess.run(
            ["git", "ls-files", "-s", "--", "skills"], capture_output=True, text=True, timeout=120
        ).stdout.splitlines() if line.startswith("100755 ")]
        not_executable = [p for p in executables if not os.access(os.path.join(cache, p), os.X_OK)]
        expect(label, executables and not not_executable, f"the cached plugin should keep the exec bit on "
               f"{executables!r}; it does not on {not_executable!r}", rc, out, err, calls)
        expect(label, sorted(p for p in snapshot(built) if not p.endswith("/")) == payload,
               f"the build's plugin should hold exactly the tracked {payload!r}", rc, out, err, calls)
        skill = read(os.path.join(cache, "skills", "compute-squad", "SKILL.md"))
        manifest = json.loads(subprocess.run([sys.executable, "codex/build-agents.py", "--parse-manifest", "models.conf"],
                                             capture_output=True, text=True, timeout=120).stdout)
        rungs_line = "Rungs (Claude alias, Codex ID): " + "; ".join(
            f"{rung} `{manifest['rungs'][rung]['claude']}`, `{tiers[rung][0]}`" for rung in ("top", "mid", "bottom")
        ) + "."
        expect(label, rungs_line in skill.splitlines() and "chose on" in skill,
               f"the cached skill's routing block should read {rungs_line!r} and say the models were chosen",
               rc, out, err, calls)
        roles = manifest["roles"]
        for path in agent_tomls:
            name = os.path.basename(path)
            installed = os.path.join(agents_dir, name)
            role = roles[name[:-len(".toml")]]
            model, effort = tiers[role["codex_rung"]]
            expect(label, os.path.exists(installed) and read(installed) == read(os.path.join(build_dir, "agents", name)),
                   f"CODEX_HOME/agents/{name} should equal the build's copy", rc, out, err, calls)
            body = read(installed).split("developer_instructions", 1)[0]
            expect(label, f'model = "{model}"\n' in body and f'model_reasoning_effort = "{effort}"\n' in body,
                   f"CODEX_HOME/agents/{name} should pin {model} at {effort}", rc, out, err, calls)
            expect(label, read(installed).split("developer_instructions", 1)[1] == read(path).split(
                "developer_instructions", 1)[1], f"CODEX_HOME/agents/{name} should keep the release body",
                rc, out, err, calls)
        for name in profiles:
            role = {"compute-squad": "strategy", "compute-squad-pm": "squad-pm",
                    "compute-squad-execution": "squad-executor",
                    "compute-squad-mechanical": "squad-executor-mechanical"}[name]
            model = tiers[roles[role]["codex_rung"]][0]
            effort = main if role == "strategy" else tiers[roles[role]["codex_rung"]][1]
            want = f'model = "{model}"\nmodel_reasoning_effort = "{effort}"\n'
            path = os.path.join(codex_home, f"{name}.config.toml")
            expect(label, os.path.exists(path) and read(path) == want, f"CODEX_HOME/{name}.config.toml should hold {want!r}",
                   rc, out, err, calls)
        left = [name for name in RETIRED if os.path.exists(os.path.join(agents_dir, name))]
        expect(label, not left, f"it left retired agents {left!r}", rc, out, err, calls)
        installed_agents = sorted(os.listdir(agents_dir))
        wanted = sorted([os.path.basename(p) for p in agent_tomls] + ["my-reviewer.toml"])
        expect(label, installed_agents == wanted, f"CODEX_HOME/agents holds {installed_agents!r}, not {wanted!r}",
               rc, out, err, calls)
        plugins = sorted(os.listdir(os.path.join(stub_state, "installed")))
        expect(label, plugins == ["compute-squad@compute-squad-local"] and not os.path.exists(remote_cache),
               f"only compute-squad@compute-squad-local should stay installed; found {plugins!r}", rc, out, err, calls)
        for path, content in user_files.items():
            expect(label, read(path) == content, f"it changed the user's file {os.path.relpath(path, codex_home)}",
                   rc, out, err, calls)
        now_status = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, timeout=120).stdout
        expect(label, now_status == repo_status, "it changed this checkout's git status", rc, out, err, calls)
        expect(label, "Start a new Codex session." in out, "it should end by asking for a new Codex session",
               rc, out, err, calls)
        expect(label, "check: OK" in out and out.index("check: OK") < out.index("Start a new Codex session."),
               "it should check the install against the source before it reports success", rc, out, err, calls)

    typed_choices = "stub-top\nmax\nstub-mid\nxhigh\nstub-low\nmax\nhigh\n"
    write_catalog(catalog_path, BASE_ENTRIES)
    ran = []
    release = json.loads(subprocess.run([sys.executable, "codex/build-agents.py", "--parse-manifest", "models.conf"],
                                        capture_output=True, text=True, timeout=120).stdout)
    release_tiers = {}
    for rung in ("top", "mid", "bottom"):
        effort = next(row["codex_effort"] for role, row in release["roles"].items()
                      if role != "strategy" and row["codex_rung"] == rung)
        release_tiers[rung] = (release["rungs"][rung]["codex"], effort)
    release_main = release["roles"]["strategy"]["codex_effort"]

    # --review-models needs a terminal; an unknown argument is refused.
    before = snapshot(codex_home)
    rc, out, err, calls = run_update("--review-models without a terminal", ["--review-models"])
    expect("--review-models without a terminal", rc == 2 and "needs a terminal" in err and not calls,
           "it should exit 2 before any call", rc, out, err, calls)
    expect_untouched("--review-models without a terminal", before, rc, out, err, calls)
    for label, args in (("an unknown argument", ["--status"]), ("--check with --review-models", ["--check", "--review-models"]),
                        ("a malformed --source-sha", ["--source-sha", "abc123"]), ("--source-sha with no commit", ["--source-sha"]),
                        ("--source-sha twice", ["--source-sha", "1" * 40, "--source-sha", "1" * 40])):
        rc, out, err, calls = run_update(label, args)
        expect(label, rc == 2 and "usage:" in err and not calls, "it should exit 2 with the usage line and no call",
               rc, out, err, calls)
    ran.append("--review-models without a terminal exits 2")

    # The setup gap.
    rc, out, err, calls = run_update("no saved choices, no terminal")
    expect("no saved choices, no terminal", rc == 3 and "setup gap: no Codex model choices saved" in err
           and "--review-models" in err, "it should exit 3 with the setup-gap line", rc, out, err, calls)
    expect_default_source("no saved choices, no terminal", rc, out, err, calls)
    expect_untouched("no saved choices, no terminal", before, rc, out, err, calls)
    ran.append("no choices and no terminal exits 3")

    # A dirty checkout.
    rc, out, err, calls = run_update("a dirty checkout", answers=typed_choices + "yes\n",
                                     extra_env={"STUB_GIT_STATUS": " M README.md\n"})
    expect("a dirty checkout", rc == 1 and "uncommitted changes" in err
           and [git_call(c) for c in calls] == DEFAULT_SOURCE,
           "it should stop after selecting the source and a git status that ignores untracked files",
           rc, out, err, calls)
    expect_untouched("a dirty checkout", before, rc, out, err, calls)
    ran.append("a dirty checkout stops")

    # A plugin list Codex cannot produce stops before anything changes.
    rc, out, err, calls = run_update("a failed plugin list", answers=typed_choices + "yes\n",
                                     extra_env={"STUB_FAIL_PLUGIN_LIST": "1"})
    expect("a failed plugin list", rc == 1 and "codex plugin list --json failed" in err
           and "listing is availability" not in out, "it should stop before choosing", rc, out, err, calls)
    expect_untouched("a failed plugin list", before, rc, out, err, calls)
    ran.append("a failed plugin list stops")

    # Another installed copy of the plugin would load a second skill.
    personal = os.path.join(stub_state, "installed", "compute-squad@personal")
    with open(personal, "w", encoding="utf-8") as f:
        f.write("4.5.0\n")
    rc, out, err, calls = run_update("another installed copy", answers=typed_choices + "yes\n")
    expect("another installed copy", rc == 1 and "codex plugin remove compute-squad@personal" in err
           and "listing is availability" not in out, "it should stop before choosing and name the remove command",
           rc, out, err, calls)
    expect_untouched("another installed copy", before, rc, out, err, calls)
    os.remove(personal)
    ran.append("another installed copy stops")

    # Enter on every prompt keeps the release pins, labelled as such; nothing
    # is picked for the user. `no` cancels.
    rc, out, err, calls = run_update("Enter keeps the release defaults", answers="\n" * 7 + "no\n")
    for rung, (model, effort) in release_tiers.items():
        expect("Enter keeps the release defaults", f"{rung} tier model [{model}, release default]" in out
               and f"  {rung}: unchanged ({model} {effort})" in out,
               f"the {rung} tier should offer and keep the release pin {model} {effort}", rc, out, err, calls)
    expect("Enter keeps the release defaults", f"main session effort: unchanged ({release_main})" in out
           and rc == 1 and "cancelled; nothing changed" in out and not os.path.exists(choices_path),
           "the main session should keep the release effort, and `no` should cancel", rc, out, err, calls)
    expect_untouched("Enter keeps the release defaults", before, rc, out, err, calls)
    ran.append("Enter keeps the release defaults")

    # Rejections, then `no` at the final prompt.
    rejections = (
        ("stub-nosuch\n", "stub-nosuch is not in this account's model catalog"),
        ("stub-hidden\n", "stub-hidden is hidden in the catalog"),
        ("stub-retired\n", f"stub-retired was retired at {PAST}"),
    )
    answers = "".join(a for a, _ in rejections) + "stub-top\nultra\nmax\nstub-top\nstub-mid\nxhigh\nstub-low\nmax\nhigh\nno\n"
    rc, out, err, calls = run_update("rejections, then no", answers=answers)
    for _answer, reason in rejections + (
        ("", "stub-top does not support reasoning effort 'ultra'"),
        ("", "stub-top is already the top tier's model"),
    ):
        expect("rejections, then no", f"rejected: {reason}" in out, f"it should reject with {reason!r}",
               rc, out, err, calls)
    expect("rejections, then no", "listing is availability, not a recommendation" in out,
           "the chooser should head its list as availability", rc, out, err, calls)
    expect("rejections, then no", rc == 1 and "cancelled; nothing changed" in out and not os.path.exists(choices_path),
           "`no` should cancel with nothing saved", rc, out, err, calls)
    expect_untouched("rejections, then no", before, rc, out, err, calls)
    ran.append("unknown, hidden, and retired models, an unsupported effort, and a taken model are rejected")

    # End of input at the final prompt.
    rc, out, err, calls = run_update("end of input", answers=typed_choices + "\x04")
    expect("end of input", rc == 1 and "cancelled; nothing changed" in out and not os.path.exists(choices_path),
           "end of input should cancel with nothing saved", rc, out, err, calls)
    expect_untouched("end of input", before, rc, out, err, calls)
    ran.append("end of input cancels")

    # First setup.
    rc, out, err, calls = run_update("first setup", answers=typed_choices + "yes\n")
    expect("first setup", rc == 0, "it should succeed", rc, out, err, calls)
    expect_default_source("first setup", rc, out, err, calls)
    want_calls = [
        "codex plugin list --json",
        "codex debug models",
        f"codex plugin marketplace add {build_dir}",
        "codex plugin add compute-squad@compute-squad-local",
        "codex plugin remove compute-squad@compute-squad",
        "codex plugin list --json",
    ]
    expect("first setup", [c for c in calls if c.startswith("codex")] == want_calls,
           f"its codex calls should be {want_calls!r}", rc, out, err, calls)
    first_text, tiers, main, fingerprint = saved_choices()
    expect("first setup", tiers == CHOSEN and main == MAIN_EFFORT, f"it saved {tiers!r} and {main!r}",
           rc, out, err, calls)
    expect("first setup", catalog_status() == "current", "the saved fingerprint should match the catalog",
           rc, out, err, calls)
    expect_installed("first setup", rc, out, err, calls)
    sync = subprocess.run([sys.executable, "codex/build-agents.py", "--check"], capture_output=True, text=True,
                          timeout=120)
    expect("first setup", sync.returncode == 0, f"build-agents.py --check should still pass:\n{sync.stdout}",
           rc, out, err, calls)
    ran.append("first setup saves the choices and installs one build")

    # A routine update with the same catalog asks and warns nothing, even on a
    # terminal, and clears a build.new an interrupted run left.
    os.makedirs(build_dir + ".new")
    with open(os.path.join(build_dir + ".new", "leftover"), "w", encoding="utf-8") as f:
        f.write("from an interrupted run\n")
    rc, out, err, calls = run_update("a routine update", answers="N\n")
    expect("a routine update", not os.path.exists(build_dir + ".new"), "it should clear the leftover build.new",
           rc, out, err, calls)
    expect("a routine update", rc == 0 and "Review them now" not in out and "listing is availability" not in out
           and "catalog changed" not in err, "it should succeed without asking or warning", rc, out, err, calls)
    expect("a routine update", read(choices_path) == first_text, "the choices should stay byte for byte",
           rc, out, err, calls)
    expect_installed("a routine update", rc, out, err, calls)
    ran.append("a routine update asks nothing and keeps the choices")

    # The source an update installs from, and the read-only check. The stub
    # git's HEAD is forty 1s unless a scenario sets STUB_GIT_HEAD.
    stub_head, other_sha = "1" * 40, "2" * 40

    git_index = subprocess.run(["git", "rev-parse", "--git-path", "index"], capture_output=True, text=True,
                               timeout=120).stdout.strip()

    def stat_snapshot(root, extra=()):
        """Every entry's type, size, mode, and mtime in nanoseconds, the root
        included: creating and removing even a temporary entry changes its
        directory's mtime, so a write that cleans up after itself still shows."""
        state = {}
        for path in [root, *extra]:
            info = os.stat(path)
            state[path] = (info.st_mode, info.st_size, info.st_mtime_ns)
        for dirpath, dirnames, filenames in os.walk(root):
            for name in dirnames + filenames:
                info = os.lstat(os.path.join(dirpath, name))
                state[os.path.join(dirpath, name)] = (info.st_mode, info.st_size, info.st_mtime_ns)
        return state

    def run_check(label, args=(), extra_env=None):
        """--check must only read: every entry of CODEX_HOME and this
        checkout's git index keep their content, mode, and mtime, and it makes
        no pull or other git write and no codex call but plugin list."""
        before = snapshot(codex_home)
        before_stat = stat_snapshot(codex_home, [git_index])
        rc, out, err, calls = run_update(label, ["--check", *args], extra_env=extra_env)
        expect(label, snapshot(codex_home) == before,
               f"--check changed CODEX_HOME: {changed_paths(before, snapshot(codex_home))!r}", rc, out, err, calls)
        after_stat = stat_snapshot(codex_home, [git_index])
        touched = sorted(p for p in set(before_stat) | set(after_stat) if before_stat.get(p) != after_stat.get(p))
        expect(label, not touched, f"--check wrote, even if only for a moment, in {touched!r}", rc, out, err, calls)
        writes = [c for c in calls if c.startswith("git ")
                  and not re.match(r"(--no-optional-locks (rev-parse|status) |ls-files )", git_call(c) or "")]
        codex_calls = [c for c in calls if c.startswith("codex ")]
        expect(label, not writes and codex_calls == ["codex plugin list --json"],
               f"--check may only read: git calls {writes!r} and codex calls {codex_calls!r} are not reads",
               rc, out, err, calls)
        now_status = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, timeout=120).stdout
        expect(label, now_status == repo_status, "--check changed this checkout's git status", rc, out, err, calls)
        return rc, out, err, calls

    rc, out, err, calls = run_check("--check on a matching install")
    expect("--check on a matching install", rc == 0 and out.rstrip().endswith("check: OK") and "MISMATCH" not in out
           and "FAILED" not in out and f"main at {stub_head}" in out,
           "it should name the source and end on check: OK", rc, out, err, calls)
    ran.append("--check reports a matching install and changes nothing")

    # Each kind of difference alone: --check exits 1, names exactly that
    # difference, and changes nothing. CODEX_HOME and the stub's plugin state
    # are restored after each one.
    version = json.loads(read(".codex-plugin/plugin.json"))["version"]
    skill = os.path.join(codex_home, "plugins", "cache", "compute-squad-local", "compute-squad", version,
                         "skills", "compute-squad")

    def append(path, text="a stale line\n"):
        with open(path, "a", encoding="utf-8") as f:
            f.write(text)

    hook = os.path.join(skill, "hooks", "grant-gate.sh")
    differences = (
        ("a stale main skill", lambda: append(os.path.join(skill, "SKILL.md")), (), {},
         os.path.join(skill, "SKILL.md") + ": differs from the source"),
        ("a stale referenced file", lambda: append(os.path.join(skill, "references", "resume.md")), (), {},
         os.path.join(skill, "references", "resume.md") + ": differs from the source"),
        ("a hook that lost its executable bit", lambda: os.chmod(hook, 0o644), (), {},
         hook + ": executable bit differs from the source"),
        ("an extra file in the cached skill", lambda: append(os.path.join(skill, "references", "old-notes.md")), (), {},
         os.path.join(skill, "references", "old-notes.md") + ": extra"),
        ("a changed agent", lambda: append(os.path.join(agents_dir, "squad-pm.toml")), (), {},
         os.path.join(agents_dir, "squad-pm.toml") + ": differs from the source"),
        ("a missing profile", lambda: os.remove(os.path.join(codex_home, "compute-squad-pm.config.toml")), (), {},
         os.path.join(codex_home, "compute-squad-pm.config.toml") + ": missing"),
        ("a second copy of the plugin",
         lambda: append(os.path.join(stub_state, "installed", "compute-squad@compute-squad"), "4.4.0\n"), (), {},
         "compute-squad@compute-squad is also installed and enabled"),
        ("an approved commit the checkout has drifted from", lambda: None, ("--source-sha", other_sha), {},
         f"HEAD is {stub_head}, not the approved {other_sha}"),
        ("uncommitted changes in the checkout", lambda: None, (), {"STUB_GIT_STATUS": " M README.md\n"},
         "has uncommitted changes"),
        ("an update lock left behind", lambda: os.mkdir(os.path.join(codex_home, "compute-squad.lock")), (), {},
         "compute-squad.lock exists"),
    )
    pristine_home, pristine_state = os.path.join(tmp, "pristine-home"), os.path.join(tmp, "pristine-state")
    shutil.copytree(codex_home, pristine_home, symlinks=True)
    shutil.copytree(stub_state, pristine_state, symlinks=True)
    for label, damage, args, extra, named in differences:
        damage()
        rc, out, err, calls = run_check(f"--check with {label}", args, extra)
        found = [line for line in out.splitlines() if line.startswith("check: MISMATCH")]
        verdict = [line for line in out.splitlines() if line.startswith(("check: OK", "check: FAILED"))]
        expect(f"--check with {label}", rc == 1 and len(found) == 1 and named in found[0]
               and verdict == [verdict[-1]] and verdict[-1].startswith("check: FAILED")
               and out.rstrip().endswith(verdict[-1]),
               f"it should exit 1, name only {named!r}, and end on one check: FAILED line", rc, out, err, calls)
        for live, pristine in ((codex_home, pristine_home), (stub_state, pristine_state)):
            shutil.rmtree(live)
            shutil.copytree(pristine, live, symlinks=True)
    ran.append("--check names, on its own, " + ", ".join(label for label, *_ in differences))

    # An approved local commit installs from any branch, with no upstream and
    # no pull, and --review-models works with it.
    approved = {"STUB_GIT_BRANCH": "wo-2-review", "STUB_GIT_UPSTREAM": ""}
    rc, out, err, calls = run_update("an approved local source", ["--source-sha", stub_head], extra_env=approved)
    git_calls = [git_call(c) for c in calls if c.startswith("git ")]
    expect("an approved local source", rc == 0 and "pull --ff-only" not in git_calls
           and git_calls[:2] == ["--no-optional-locks rev-parse HEAD",
                                 "--no-optional-locks status --porcelain --untracked-files=no"],
           "it should read HEAD and the status, never pull, and install", rc, out, err, calls)
    expect_installed("an approved local source", rc, out, err, calls)
    rc, out, err, calls = run_update("a review of an approved local source", ["--review-models", "--source-sha", stub_head],
                                     answers="\n" * 7 + "yes\n", extra_env=approved)
    _text, tiers, main, _fp = saved_choices()
    expect("a review of an approved local source", rc == 0 and "listing is availability" in out and tiers == CHOSEN
           and main == MAIN_EFFORT, "it should ask, keep the entered values, and install", rc, out, err, calls)
    expect_installed("a review of an approved local source", rc, out, err, calls)
    with open(choices_path, "w", encoding="utf-8") as f:
        f.write(first_text)
    ran.append("an approved local source installs without a pull, with or without --review-models")

    # Source drift stops before any codex call; only the default source pulls,
    # and only once main tracking origin/main is confirmed.
    drift = (
        ("an approved commit the checkout is not at", ["--source-sha", other_sha], {}, f"not the approved {other_sha}", False),
        ("a checkout on another branch", [], {"STUB_GIT_BRANCH": "wo-2-review"}, "on wo-2-review tracking origin/main", False),
        ("a checkout tracking another remote", [], {"STUB_GIT_UPSTREAM": "fork/main"}, "on main tracking fork/main", False),
        ("a checkout with no upstream", [], {"STUB_GIT_UPSTREAM": ""}, "on main tracking nothing", False),
        ("a checkout not at origin/main after the pull", [], {"STUB_GIT_UPSTREAM_HEAD": other_sha},
         f"is at {stub_head}, not origin/main, after the pull", True),
    )
    for label, args, extra, message, pulled in drift:
        before = snapshot(codex_home)
        rc, out, err, calls = run_update(label, args, extra_env=extra)
        git_calls = [git_call(c) for c in calls if c.startswith("git ")]
        expect(label, rc == 1 and message in err and ("pull --ff-only" in git_calls) == pulled
               and not any(c.startswith("codex") for c in calls),
               f"it should stop before any codex call{' after' if pulled else ' without'} pulling", rc, out, err, calls)
        expect_untouched(label, before, rc, out, err, calls)
    ran.append("source drift stops before installing (" + "; ".join(label for label, *_ in drift) + ")")

    # An install that lands content the source lacks fails and never reports
    # success; the next update repairs it.
    rc, out, err, calls = run_update("an install that lands the wrong content", extra_env={"STUB_CORRUPT_INSTALL": "1"})
    expect("an install that lands the wrong content", rc == 1
           and os.path.join(skill, "references", "resume.md") + ": differs from the source" in out
           and "does not match the source" in err and "installed from" not in out
           and "Start a new Codex session." not in out, "it should name the difference and exit 1 without success",
           rc, out, err, calls)
    rc, out, err, calls = run_update("the update after a wrong install")
    expect("the update after a wrong install", rc == 0, "it should succeed", rc, out, err, calls)
    expect_installed("the update after a wrong install", rc, out, err, calls)
    ran.append("an install that lands the wrong content fails without reporting success")

    # A routine update whose `codex debug models` fails warns and installs
    # the saved choices.
    rc, out, err, calls = run_update("a failed catalog", extra_env={"STUB_CATALOG": os.path.join(tmp, "missing.json")})
    expect("a failed catalog", rc == 0 and "were not checked against the catalog" in err
           and read(choices_path) == first_text, "it should warn and install the saved choices", rc, out, err, calls)
    expect_installed("a failed catalog", rc, out, err, calls)
    ran.append("a failed catalog read warns and installs the saved choices")

    # A catalog in a format this updater does not read warns the same way.
    write_catalog(catalog_path, [])
    with open(catalog_path, "w", encoding="utf-8") as f:
        json.dump({"data": BASE_ENTRIES}, f)
    rc, out, err, calls = run_update("an unreadable catalog format")
    expect("an unreadable catalog format", rc == 0 and "catalog format this updater does not read" in err
           and read(choices_path) == first_text, "it should warn and install the saved choices", rc, out, err, calls)
    expect_installed("an unreadable catalog format", rc, out, err, calls)
    write_catalog(catalog_path, BASE_ENTRIES)
    ran.append("an unreadable catalog format warns and installs the saved choices")

    # A second update while one holds the lock installs nothing.
    lock = os.path.join(codex_home, "compute-squad.lock")
    os.makedirs(lock)
    before = snapshot(codex_home)
    rc, out, err, calls = run_update("a held lock")
    expect("a held lock", rc == 1 and "another update is running" in err, "it should stop", rc, out, err, calls)
    expect_untouched("a held lock", before, rc, out, err, calls)
    os.rmdir(lock)
    ran.append("a held lock stops")

    # The lock covers every write of the saved choices through validation,
    # rendering, and installation, so a review and a scheduled update never
    # interleave. First a scheduled update, paused by the stub inside
    # `codex plugin add` while it installs the build rendered from the saved
    # choices: a review that would change them stops at the lock before it
    # asks anything, the choices stay byte for byte, and the scheduled update
    # finishes with them.
    pause = os.path.join(tmp, "pause")
    os.makedirs(pause)
    other_log = os.path.join(tmp, "stub-calls-other.txt")
    new_mid = "stub-top\nmax\nstub-mid\nmax\nstub-low\nmax\nhigh\nyes\n"
    scheduled = start_update("a scheduled update installing", extra_env={"STUB_PAUSE_DIR": pause}, log=other_log)
    wait_for("the stub to pause it inside codex plugin add", lambda: os.path.exists(os.path.join(pause, "paused")),
             scheduled)
    before = snapshot(codex_home)
    rc, out, err, calls = run_update("a review during a scheduled install", ["--review-models"], answers=new_mid)
    expect("a review during a scheduled install", rc == 1 and "another update is running" in err
           and "listing is availability" not in out and read(choices_path) == first_text,
           "it should stop at the lock before asking, with the saved choices byte for byte", rc, out, err, calls)
    expect_untouched("a review during a scheduled install", before, rc, out, err, calls)
    with open(os.path.join(pause, "go"), "w", encoding="utf-8"):
        pass
    rc, out, err, calls = finish_update(scheduled)
    expect("a scheduled update installing", rc == 0 and read(choices_path) == first_text and not os.path.exists(lock),
           "it should finish with the saved choices and release the lock", rc, out, err, calls)
    expect_installed("a scheduled update installing", rc, out, err, calls)
    ran.append("a review cannot save choices while a scheduled update installs")

    # Then a review waiting at the chooser holds the lock: a scheduled update
    # stops at it and changes nothing, and the review saves and installs its
    # new choices.
    review = start_update("a review waiting for answers", ["--review-models"], terminal=True, log=other_log)
    wait_for("the chooser to ask for the top tier's model", lambda: "top tier model [" in read(review["out"]), review)
    if not os.path.isdir(lock):
        os.killpg(review["proc"].pid, signal.SIGKILL)
        review["proc"].wait()
        fail("codex/update.sh (a review waiting for answers): it should hold the update lock while it asks, so no "
             "other update can install from choices it is about to replace")
    before = snapshot(codex_home)
    rc, out, err, calls = run_update("a scheduled update during a review")
    expect("a scheduled update during a review", rc == 1 and "another update is running" in err,
           "it should stop at the lock", rc, out, err, calls)
    expect_untouched("a scheduled update during a review", before, rc, out, err, calls)
    rc, out, err, calls = finish_update(review, new_mid)
    _text, tiers, main, _fp = saved_choices()
    expect("a review waiting for answers", rc == 0 and tiers == dict(CHOSEN, mid=("stub-mid", "max"))
           and main == MAIN_EFFORT and not os.path.exists(lock),
           "it should save and install its new choices and release the lock", rc, out, err, calls)
    expect_installed("a review waiting for answers", rc, out, err, calls)
    with open(choices_path, "w", encoding="utf-8") as f:
        f.write(first_text)
    ran.append("a scheduled update cannot install while a review holds the lock")

    # What the fingerprint ignores and what it notices. An odd entry for a
    # model nobody chose does not block the status.
    write_catalog(catalog_path, list(reversed(BASE_ENTRIES)))
    shuffled = catalog_status()
    write_catalog(catalog_path, [dict(e, display_name="renamed", priority=9) for e in BASE_ENTRIES])
    relabelled = catalog_status()
    write_catalog(catalog_path, BASE_ENTRIES + [stub_entry("stub-new", STUB_EFFORTS)])
    added = catalog_status()
    odd = {"slug": "stub-odd", "visibility": "list"}
    write_catalog(catalog_path, BASE_ENTRIES + [stub_entry("stub-new", STUB_EFFORTS), odd])
    with_odd = catalog_status()
    write_catalog(catalog_path, BASE_ENTRIES + [stub_entry("stub-new", STUB_EFFORTS)])
    if (shuffled, relabelled, added, with_odd) != ("current", "current", "changed", "changed"):
        fail(f"the catalog fingerprint should ignore order and unrelated metadata, notice a new model, and read an "
             f"entry with missing keys; --catalog-status gave {shuffled}, {relabelled}, {added}, {with_odd}")
    ran.append("the fingerprint ignores order and metadata")

    # A changed catalog with no terminal.
    rc, out, err, calls = run_update("a changed catalog, no terminal")
    expect("a changed catalog, no terminal", rc == 0 and "catalog changed since your choices were saved" in err
           and "--review-models" in err, "it should warn and install", rc, out, err, calls)
    expect("a changed catalog, no terminal", read(choices_path) == first_text, "the choices should stay",
           rc, out, err, calls)
    expect_installed("a changed catalog, no terminal", rc, out, err, calls)
    ran.append("a changed catalog warns under a scheduler")

    # A changed catalog on a terminal: N, then y.
    rc, out, err, calls = run_update("a changed catalog, N", answers="N\n")
    expect("a changed catalog, N", rc == 0 and "Review them now? [y/N]" in out and "listing is availability" not in out
           and read(choices_path) == first_text, "N should keep the choices", rc, out, err, calls)
    rc, out, err, calls = run_update("a changed catalog, y", answers="y\n" + "\n" * 7 + "yes\n")
    _text, tiers, main, new_fingerprint = saved_choices()
    expect("a changed catalog, y", rc == 0 and "listing is availability" in out and "[stub-top, saved]" in out
           and tiers == CHOSEN and main == MAIN_EFFORT and new_fingerprint != fingerprint
           and catalog_status() == "current", "y should run the chooser, keep the entered values, and save the new "
           "fingerprint", rc, out, err, calls)
    expect_installed("a changed catalog, y", rc, out, err, calls)
    ran.append("a changed catalog on a terminal: N keeps, y reviews")

    # Unreadable saved choices stop a routine update with the way out, and
    # --review-models shows the release defaults in their place.
    good_text = read(choices_path)
    with open(choices_path, "w", encoding="utf-8") as f:
        f.write(good_text.replace("stub-mid", "stub-top"))
    before = snapshot(codex_home)
    rc, out, err, calls = run_update("unreadable choices")
    expect("unreadable choices", rc == 1 and "each tier needs its own model" in err and "--review-models" in err,
           "it should stop and give the review command", rc, out, err, calls)
    expect_untouched("unreadable choices", before, rc, out, err, calls)
    rc, out, err, calls = run_update("unreadable choices, review", ["--review-models"], answers="\n" * 7 + "no\n")
    expect("unreadable choices, review", rc == 1 and "cannot be read" in out and "release default" in out,
           "the review should show the release defaults in place of the unreadable file", rc, out, err, calls)
    expect_untouched("unreadable choices, review", before, rc, out, err, calls)
    with open(choices_path, "w", encoding="utf-8") as f:
        f.write(good_text)
    ran.append("unreadable choices stop and can be reviewed")

    # A saved model the catalog retires, then drops.
    for label, entries in (
        ("a retired saved model", [e for e in BASE_ENTRIES if e["slug"] != "stub-mid"]
         + [stub_entry("stub-mid", STUB_EFFORTS, upgrade={"model": None, "retirement_at": PAST})]),
        ("a saved model the catalog dropped", [e for e in BASE_ENTRIES if e["slug"] != "stub-mid"]),
    ):
        write_catalog(catalog_path, entries)
        before = snapshot(codex_home)
        rc, out, err, calls = run_update(label)
        expect(label, rc == 1 and "stub-mid" in err and "--review-models" in err,
               "it should stop, name stub-mid, and give the review command", rc, out, err, calls)
        expect_untouched(label, before, rc, out, err, calls)
    ran.append("a saved model the catalog retires or drops stops")


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
    f"PASS: check 8: codex/update.sh with stub git and codex ran {len(ran)} scenarios ({'; '.join(ran)}); every "
    f"install put the plugin, the {len(agent_tomls)} agents, and {len(profiles)} profiles from one build that carries "
    f"the saved choices, removed the remote plugin, pruned the retired agents ({', '.join(RETIRED)}), and left the "
    f"user's files and this checkout untouched, and every stop left CODEX_HOME unchanged; --validate-catalog "
    f"handles {len(validator_cases)} more stub catalogs ({', '.join(case[0] for case in validator_cases)}) as "
    f"specified, with and without --strict"
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
# prints the run's last line for each subagent, a continued one included, and
# then its last main line.
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
        # The end-of-run command prints this run's last line for each
        # subagent, in the order each first stopped, then its last main line.
        # A subagent continued with SendMessage (finding 18) stops again under
        # the same agent_id, and its later line is a running total that
        # repeats the earlier one's tokens (measured on Claude Code 2.1.282),
        # so the records above, which all carry the fixture's agent_id, print
        # as one; two more agents follow, one of them continued.
        with open(os.path.join(repo, LEDGER_TARGET), "a", encoding="utf-8") as handle:
            handle.write(json.dumps(dict(main_rec(OLD_RUN), output=1), separators=(",", ":")) + "\n")
            for agent_id, output in (("b1c2d3e4f5a6b7c8d", 5), ("c2d3e4f5a6b7c8d9e", 7), ("b1c2d3e4f5a6b7c8d", 9)):
                handle.write(json.dumps(dict(rec(agent_fixture, RUN, "squad-helper", agent_id), output=output),
                                        separators=(",", ":")) + "\n")
        lines = read(os.path.join(repo, LEDGER_TARGET)).splitlines()
        mine = [line for line in lines if f'"run":"{RUN}"' in line]
        last = {}
        for line in mine:
            last.setdefault(json.loads(line)["agent_id"], []).append(line)
        want = [runs[-1] for agent_id, runs in last.items() if agent_id != "main"] + [last["main"][-1]]
        if len(want) != 4 or len(last["b1c2d3e4f5a6b7c8d"]) != 2:
            fail("check 8f's end-of-run case needs three subagents, one of them continued, and a main line")
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

python3 tests/test_review_regressions.py
echo "verify.sh: all checks passed"
