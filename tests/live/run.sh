#!/usr/bin/env bash
# Live tier of the Compute Squad regression set (report section 6).
#
# Runs the orchestrating session headless (claude -p), with this checkout
# loaded as the plugin, on a copy of tests/fixtures/repo-reset/, then checks
# what the session did with tests/live/check_live.py. It spends model tokens:
# about $1 to $2.50 per scenario with a top-rung main session. CI never
# runs a scenario live: scripts/verify.sh (check 8b) calls this script only
# with --list, --dry-run, and --setup-only, which call no model, and it
# refuses to call a model when CI is set. Check 8b holds every scenario's
# seeded repo to the next action its static twin gives. Run the live
# scenarios by hand before a release, three repeats per scenario.
#
# Usage: tests/live/run.sh [options] <scenario>... | all
#   --list                 print the scenarios, their seeds and patches, and exit
#   --dry-run              print each scenario's setup and claude commands; call no model
#   --setup-only           build and seed each scenario repo, print the claude
#                          commands, and keep the repo; run no test and call no model
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
#      Executor entry reports, without committing it. S3a, S3b, S4, and S4b
#      then apply their scenario's patches and commit them, so HEAD moves
#      past the seed's Base: (commit B for S3, the external implementation C
#      for S4), and a prompt's <C> becomes that commit's short SHA;
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
# A second goal for the one-active-run scenario (finding 11).
OTHER_GOAL='Add an X-Request-Id header to every API response. Acceptance criteria: every response carries an X-Request-Id header; npm test passes.'
ACCEPT_C='The external implementation of WO-1 is commit <C>. Accept it.'

SCENARIOS=(s1 s1n s2 s2b s2c s2o s3a s3b s4 s4b s7b)

# scenario <name>: sets DESC, SEED, PATCH, COMMIT, COMMIT_MSG, PROMPTS and
# CHECKS (one per turn). PATCH is applied and left uncommitted; COMMIT's
# patches are applied and committed as one commit after the seed.
scenario() {
  PATCH=
  COMMIT=()
  COMMIT_MSG=
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
    s2o)
      DESC='Second run (finding 11): /squad with another goal over the open S2 run spawns nothing, archives nothing, and leaves the log as it was'
      SEED=s2
      PROMPTS=("/squad $OTHER_GOAL")
      CHECKS=(s2o) ;;
    s3a)
      DESC='S3a: commit B edits src/server/db/store.js, which the plan names; resuming re-maps it and writes plan r2, and no executor runs without a new grant'
      SEED=s3
      COMMIT=("$HERE/repo-reset-b-store.patch")
      COMMIT_MSG='commit B: store.js gains deleteResetTokens'
      PROMPTS=("$RESUME")
      CHECKS=(s3a) ;;
    s3b)
      DESC='S3b: commit B adds docs/notes.md, which the plan does not name; resuming records the new Base and runs one executor, with no Recon'
      SEED=s3
      COMMIT=("$HERE/repo-reset-b-notes.patch")
      COMMIT_MSG='commit B: docs/notes.md'
      PROMPTS=("$RESUME")
      CHECKS=(s3b) ;;
    s4)
      DESC='S4: WO-1 was implemented outside the squad as commit C; accepting it spawns only the PM, which passes WO-1 and leaves WO-2 open'
      SEED=s4
      COMMIT=("$HERE/repo-reset-wo1.patch")
      COMMIT_MSG='commit C: WO-1, implemented outside the squad'
      PROMPTS=("$ACCEPT_C")
      CHECKS=(s4) ;;
    s4b)
      DESC='S4b: commit C also adds the WO-2 event code to src/server/log.js; the PM fails WO-1 on scope'
      SEED=s4
      COMMIT=("$HERE/repo-reset-wo1.patch" "$HERE/repo-reset-wo2-event.patch")
      COMMIT_MSG='commit C: WO-1 plus a WO-2 event code'
      PROMPTS=("$ACCEPT_C")
      CHECKS=(s4b) ;;
    s7b)
      DESC='S7b: three FAILs are logged; resuming spawns nothing, appends nothing, and names the three-FAIL stop'
      SEED=s7b
      PROMPTS=("$RESUME")
      CHECKS=(s7b) ;;
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
    setup=
    [ -z "$PATCH" ] || setup=", then applies ${PATCH#"$ROOT"/} uncommitted"
    if [ ${#COMMIT[@]} -gt 0 ]; then
      setup="$setup, then commits"
      for patch in "${COMMIT[@]}"; do
        setup="$setup ${patch#"$ROOT"/}"
      done
      setup="$setup as '$COMMIT_MSG'"
    fi
    printf '%-4s %s\n     seed tests/fixtures/logs/%s.log.md%s; turns: %s\n' "$name" "$DESC" "$SEED" "$setup" "${CHECKS[*]}"
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
  for patch in ${COMMIT[@]+"${COMMIT[@]}"}; do
    [ -f "$patch" ] || die "missing $patch"
  done
done
# --setup-only runs no test and calls no model, so only a live run needs node
# (the stages run the fixture's npm test) and the claude CLI.
if [ "$MODE" = live ]; then
  command -v node >/dev/null 2>&1 || die "node is required: the fixture's npm test runs node --test"
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
  local name=$1 rep=$2 dir repo base head session= i turn check prompt patch rc=0
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
  head='<C>'
  if [ ${#COMMIT[@]} -gt 0 ]; then
    for patch in "${COMMIT[@]}"; do
      step git -C "$repo" apply "$patch" || return 2
    done
    step git -C "$repo" add -A || return 2
    step git -C "$repo" -c user.name=compute-squad-live -c user.email=live@example.invalid \
      -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m "$COMMIT_MSG" || return 2
    [ "$MODE" = dry ] || head=$(git -C "$repo" rev-parse --short=7 HEAD) || return 2
  fi
  if [ "$MODE" = setup ]; then
    "$PYTHON" "$ROOT/tests/check_logs.py" "$repo/COMPUTE_SQUAD_LOG.md" | sed 's/^/  /' || return 1
  fi

  for i in "${!PROMPTS[@]}"; do
    turn=$((i + 1))
    check=${CHECKS[$i]}
    prompt=${PROMPTS[$i]//<C>/$head}
    if [ "$MODE" = live ]; then
      claude_cmd "$prompt" "$session"
    else
      claude_cmd "$prompt" "$([ "$turn" -gt 1 ] && printf '<session_id from turn 1>')"
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
