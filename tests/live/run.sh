#!/usr/bin/env bash
# Live tier of the Compute Squad regression set (report section 6).
#
# Runs the orchestrating session headless (claude -p), with this checkout
# loaded as the plugin, on a copy of tests/fixtures/repo-reset/, then checks
# what the session did with tests/live/check_live.py. It spends model tokens:
# about $1 to $2.50 per scenario with a top-rung main session. CI never
# runs it: scripts/verify.sh does not call it, and it refuses to call a model
# when CI is set. Run it by hand before a release, three repeats per scenario.
#
# Usage: tests/live/run.sh [options] <scenario>... | all
#   --list                 print the scenarios and exit
#   --dry-run              print each scenario's setup and claude commands; call no model
#   --setup-only           build and seed each scenario repo, print the claude
#                          commands, and keep the repo; call no model
#   --model <alias>        main-session model (default: the host's default)
#   --repeat <n>           run each scenario n times (default 1)
#   --max-budget-usd <x>   pass --max-budget-usd to every claude call
#   --out <dir>            write results here (default: a new temp dir)
# Environment: CLAUDE_BIN (default claude), PYTHON (default python3).
#
# Each scenario:
#   1. copies tests/fixtures/repo-reset/ into a temp dir: the password-reset
#      fixture that mirrors docs/example-log.md, whose npm test passes;
#   2. runs git init and commits the copy as base A;
#   3. writes the seed log tests/fixtures/logs/<seed>.log.md as
#      COMPUTE_SQUAD_LOG.md with base A and the repo path in place of the
#      seed's placeholders, writes the archive copy a seeded PASS entry names,
#      and excludes the log and compute-squad-archive/ from git status. S2c
#      also applies tests/live/repo-reset-wo1.patch, the work its seed's
#      Executor entry reports;
#   4. runs each turn's prompt (a second turn resumes the first turn's
#      session) and checks subagent_stats.by_type, permission_denials, the
#      usage ledger against modelUsage, the log's new entries, the product
#      tree against A, and the archive files' sha256. A scenario stops at its
#      first failing turn, so a broken run does not keep spending.
# Results, one directory per scenario run, stay in --out: each turn's
# prompt command, claude JSON and stderr, state snapshot, and assertion output.
set -u -o pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
FIXTURE="$ROOT/tests/fixtures/repo-reset"
SEEDS="$ROOT/tests/fixtures/logs"
CHECK="$HERE/check_live.py"
CLAUDE_BIN=${CLAUDE_BIN:-claude}
PYTHON=${PYTHON:-python3}
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

# The <cooldown goal> of section 6: docs/example-log.md's goal and criteria.
GOAL='Add a 60-second resend cooldown to the password-reset email endpoint, per-account. Acceptance criteria: a second reset request for the same account within 60 seconds of the first sends no new email and creates no new token row; a request 60 seconds or more after that account got its newest token creates a new token and sends the email as normal; no response or log reveals whether an account exists; npm test passes. Out of scope: per-IP throttling and admin-triggered resets.'
APPROVE='Plan approved; keep it shelved.'
RESUME='Resume the squad run.'

SCENARIOS=(s1 s1n s2 s2b s2c)

# scenario <name>: sets DESC, SEED, PATCH, PROMPTS and CHECKS (one per turn).
scenario() {
  PATCH=
  case $1 in
    s1)
      DESC='S1: /squad plan, then "plan approved": mech, recon and pm only, no product edits, a plan-approved Decision, no grant'
      SEED=s1
      PROMPTS=("/squad plan $GOAL" "$APPROVE")
      CHECKS=(s1-plan s1-approve) ;;
    s1n)
      DESC='S1, natural-language variant (finding 1): the same run asked for in plain words'
      SEED=s1
      PROMPTS=("Use the compute squad to plan this change, then shelve the plan; do not implement it yet. $GOAL" "$APPROVE")
      CHECKS=(s1-plan s1-approve) ;;
    s2)
      DESC='S2: the log grants r1 WO-1; resuming runs one executor at the classified rung and one PM, and no WO-2'
      SEED=s2
      PROMPTS=("$RESUME")
      CHECKS=(s2) ;;
    s2b)
      DESC='S2b: the grant names r1 but the log ends at plan r2; resuming spawns no executor'
      SEED=s2b
      PROMPTS=("$RESUME")
      CHECKS=(s2b) ;;
    s2c)
      DESC='S2c: WO-1 already has a PASS and the grant covers WO-1 alone; resuming spawns nothing'
      SEED=s2c
      PATCH="$HERE/repo-reset-wo1.patch"
      PROMPTS=("$RESUME")
      CHECKS=(s2c) ;;
    *) return 1 ;;
  esac
}

die() { printf 'run.sh: %s\n' "$1" >&2; exit 2; }

usage() {
  sed -n '/^# Usage:/,/^# Environment:/p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

MODE=live MODEL= REPEAT=1 BUDGET= OUT=
selected=()
while [ $# -gt 0 ]; do
  case $1 in
    --list) MODE=list ;;
    --dry-run) MODE=dry ;;
    --setup-only) MODE=setup ;;
    --model) [ $# -ge 2 ] || usage; MODEL=$2; shift ;;
    --repeat) [ $# -ge 2 ] || usage; REPEAT=$2; shift ;;
    --max-budget-usd) [ $# -ge 2 ] || usage; BUDGET=$2; shift ;;
    --out) [ $# -ge 2 ] || usage; OUT=$2; shift ;;
    -h|--help) usage 0 ;;
    all) selected+=("${SCENARIOS[@]}") ;;
    -*) usage ;;
    *) scenario "$1" || die "unknown scenario '$1'; --list shows them"; selected+=("$1") ;;
  esac
  shift
done

if [ "$MODE" = list ]; then
  for name in "${SCENARIOS[@]}"; do
    scenario "$name"
    printf '%-4s %s\n     seed tests/fixtures/logs/%s.log.md; turns: %s\n' "$name" "$DESC" "$SEED" "${CHECKS[*]}"
  done
  exit 0
fi
[ ${#selected[@]} -gt 0 ] || usage
case $REPEAT in ''|*[!0-9]*|0) die "--repeat takes a whole number of at least 1" ;; esac

if [ "$MODE" = live ] && [ -n "${CI:-}" ]; then
  die "the live tier spends model tokens and never runs in CI (CI is set); use --dry-run or --list"
fi
for tool in git "$PYTHON"; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is required"
done
[ -d "$FIXTURE" ] && [ -f "$CHECK" ] || die "missing $FIXTURE or $CHECK"
for name in "${selected[@]}"; do
  scenario "$name"
  [ -f "$SEEDS/$SEED.log.md" ] || die "missing seed tests/fixtures/logs/$SEED.log.md"
  [ -z "$PATCH" ] || [ -f "$PATCH" ] || die "missing $PATCH"
done
if [ "$MODE" != dry ]; then
  command -v node >/dev/null 2>&1 || die "node is required: the fixture's npm test runs node --test"
fi
if [ "$MODE" = live ]; then
  command -v "$CLAUDE_BIN" >/dev/null 2>&1 || die "$CLAUDE_BIN not found; set CLAUDE_BIN"
fi

if [ "$MODE" = dry ]; then
  OUT=${OUT:-<out>}
else
  if [ -z "$OUT" ]; then
    OUT=$(mktemp -d "${TMPDIR:-/tmp}/compute-squad-live.XXXXXX") || die "mktemp failed"
  fi
  # A scenario repo inside this checkout would read its files and settings.
  case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
  case "$OUT/" in "$ROOT"/*) die "--out must be outside $ROOT" ;; esac
  mkdir -p "$OUT" || die "cannot create $OUT"
  OUT=$(cd "$OUT" && pwd -P)
  case "$OUT/" in "$(cd "$ROOT" && pwd -P)"/*) die "--out must be outside $ROOT" ;; esac
fi

# step <command...>: run it, or print it under --dry-run.
step() {
  if [ "$MODE" = dry ]; then
    printf '    '; printf '%q ' "$@"; printf '\n'
  else
    "$@"
  fi
}

# claude_cmd <prompt> <session or empty>: the section 6 invocation, in CMD.
# Task joins Agent in --allowedTools because Claude Code 2.1.282 names the
# spawn tool Task. Skill must stay: under -p that CLI passes "/squad ..." to
# the model as text, and the model loads the plugin command through the Skill
# tool. --model and --max-budget-usd are added only when given.
claude_cmd() {
  CMD=("$CLAUDE_BIN" -p "$1" --output-format json --plugin-dir "$ROOT"
    --settings '{"enabledPlugins":{"compute-squad@compute-squad":false}}'
    --permission-mode acceptEdits)
  [ -z "$MODEL" ] || CMD+=(--model "$MODEL")
  [ -z "$BUDGET" ] || CMD+=(--max-budget-usd "$BUDGET")
  [ -z "$2" ] || CMD+=(--resume "$2")
  CMD+=(--allowedTools Agent Task Read Write Edit Bash Grep Glob Skill)
}

# A claude session started from inside another Claude Code session inherits
# that session's ID and writes into its transcript; start each run clean.
run_claude() {
  (cd "$1" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_REMOTE_SESSION_ID -u CLAUDE_CODE_CHILD_SESSION \
    "${CMD[@]}" >"$2.json" 2>"$2.err")
}

run_scenario() {
  local name=$1 rep=$2 dir repo base session= i turn check rc=0
  scenario "$name"
  dir="$OUT/$name-$rep"
  repo="$dir/repo"
  printf '\n== %s (run %s of %s)\n   %s\n' "$name" "$rep" "$REPEAT" "$DESC"
  if [ "$MODE" = dry ]; then
    printf '  setup:\n'
  else
    mkdir -p "$repo" || return 2
  fi
  step cp -a "$FIXTURE/." "$repo/" || return 2
  step git -C "$repo" -c init.defaultBranch=main init -q || return 2
  step git -C "$repo" add -A || return 2
  step git -C "$repo" -c user.name=compute-squad-live -c user.email=live@example.invalid \
    -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m 'base A: tests/fixtures/repo-reset' || return 2
  if [ "$MODE" = dry ]; then
    base='<A>'
  else
    base=$(git -C "$repo" rev-parse HEAD) || return 2
  fi
  step "$PYTHON" "$CHECK" seed "$SEEDS/$SEED.log.md" "$repo" "$base" || return 2
  if [ -n "$PATCH" ]; then
    step git -C "$repo" apply "$PATCH" || return 2
  fi
  if [ "$MODE" = setup ]; then
    "$PYTHON" "$ROOT/tests/check_logs.py" "$repo/COMPUTE_SQUAD_LOG.md" | sed 's/^/  /' || return 1
  fi

  for i in "${!PROMPTS[@]}"; do
    turn=$((i + 1))
    check=${CHECKS[$i]}
    if [ "$MODE" = live ]; then
      claude_cmd "${PROMPTS[$i]}" "$session"
    else
      claude_cmd "${PROMPTS[$i]}" "$([ "$turn" -gt 1 ] && printf '<session_id from turn 1>')"
    fi
    printf '  turn %s, check %s:\n    (cd %q &&\n     ' "$turn" "$check" "$repo"
    printf '%q ' "${CMD[@]}"; printf ')\n'
    [ "$MODE" = live ] || continue

    printf '%q ' "${CMD[@]}" >"$dir/turn$turn.cmd"
    "$PYTHON" "$CHECK" snapshot "$repo" "$base" "$dir/turn$turn.state.json" >/dev/null || return 2
    run_claude "$repo" "$dir/turn$turn"
    printf '    claude exited %s\n' "$?"
    "$PYTHON" "$CHECK" verify "$check" "$repo" "$base" "$dir/turn$turn.state.json" "$dir/turn$turn.json" \
      --summary "$OUT/summary.tsv" --label "$name#$rep turn $turn" | tee "$dir/turn$turn.check.txt" | sed 's/^/    /'
    rc=$?
    [ "$rc" -eq 0 ] || { printf '    stopping %s here; later turns skipped\n' "$name"; return "$rc"; }
    session=$("$PYTHON" -c 'import json, sys; print(json.load(open(sys.argv[1])).get("session_id") or "")' \
      "$dir/turn$turn.json" 2>/dev/null)
    if [ -z "$session" ] && [ "$turn" -lt ${#PROMPTS[@]} ]; then
      printf '    no session_id in turn %s; later turns skipped\n' "$turn"
      return 1
    fi
  done
  [ "$MODE" != setup ] || printf '  repo kept at %s\n' "$repo"
  return 0
}

status=0
for name in "${selected[@]}"; do
  rep=1
  while [ "$rep" -le "$REPEAT" ]; do
    run_scenario "$name" "$rep"
    rc=$?
    [ "$rc" -le "$status" ] || status=$rc
    rep=$((rep + 1))
  done
done

if [ "$MODE" = live ] && [ -f "$OUT/summary.tsv" ]; then
  printf '\n'
  awk -F'\t' '{ printf "%-4s %-26s %s  $%.2f\n", $3, $1, $2, $4; cost += $4; if ($3 != "PASS") failed++ }
    END { printf "%d turns checked, %d failed, $%.2f spent\n", NR, failed, cost }' "$OUT/summary.tsv"
fi
[ "$MODE" = dry ] || printf 'results: %s\n' "$OUT"
exit "$status"
