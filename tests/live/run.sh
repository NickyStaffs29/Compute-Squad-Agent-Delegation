#!/usr/bin/env bash
# Live tier of the Compute Squad regression set (report section 6).
#
# Runs the orchestrating session headless (claude -p), with this checkout
# loaded as the plugin, on a copy of a fixture repo (tests/fixtures/repo-reset/,
# or tests/fixtures/repo-ui/ for S5 and S5b), then checks what the session did
# with tests/live/check_live.py. It spends model tokens:
# about $1 to $2.50 per scenario with a top-rung main session. CI never
# runs a scenario live: scripts/verify.sh (check 8b) calls this script only
# with --list, --dry-run, and --setup-only, which call no model, and it
# refuses to call a model when CI is set. Check 8b holds every scenario's
# seeded repo to the next action its static twin gives, and runs each
# preflight --setup-only prints. Run the live
# scenarios by hand before a release, three repeats per scenario. S5 needs
# Playwright (in the fixture's node_modules or the global npm root) with its
# Chromium; S5b hides that Chromium from the session. S8's token budget is the
# estimate for a top-rung main session, so run it without --model or with the
# top rung's alias. S9 runs five finders and up to ten skeptics.
#
# Usage: tests/live/run.sh [options] <scenario>... | all
#   --list                 print the scenarios, their seeds and patches, and exit
#   --dry-run              print each scenario's setup, preflight, and claude
#                          commands; call no model
#   --setup-only           build and seed each scenario repo, print the preflight
#                          and claude commands, and keep the repo; run no test
#                          and call no model
#   --model <alias>        main-session model (default: the host's default)
#   --repeat <n>           run each scenario n times (default 1)
#   --max-budget-usd <x>   pass --max-budget-usd to every claude call
#   --out <dir>            write results here (default: a new temp dir)
# Environment: CLAUDE_BIN (default claude), PYTHON (default python3).
#
# Each scenario:
#   1. copies its fixture repo into a temp dir: tests/fixtures/repo-reset/, the
#      password-reset fixture that mirrors docs/example-log.md, or, for S5 and
#      S5b, tests/fixtures/repo-ui/, a pricing page whose unit tests pass and
#      whose browser check (npm run check:overflow) reports a 624px table
#      overflowing a 390px viewport; npm test passes in both;
#   2. runs git init and commits the copy as base A;
#   3. writes the seed log tests/fixtures/logs/<seed>.log.md as
#      COMPUTE_SQUAD_LOG.md with base A and the repo path in place of the
#      seed's placeholders, writes the archive copy a seeded PASS entry names,
#      and excludes the log and compute-squad-archive/ from git status. S2c
#      and S6a also apply tests/live/repo-reset-wo1.patch, and S5
#      tests/live/repo-ui-note.patch, the work the seed's Executor entry
#      reports, without committing it, and S9 applies
#      tests/live/repo-reset-audit.patch, WO-1 with about 30 planted
#      defects for its audit to find. S3a, S3b, S4, and S4b then apply their
#      scenario's patches and commit them, so HEAD moves past the seed's Base:
#      (commit B for S3, the external implementation C for S4), and a prompt's
#      <C> becomes that commit's short SHA. S5b makes an empty browser
#      directory and sets PLAYWRIGHT_BROWSERS_PATH to it for the claude call.
#      S6b runs check_live.py collide, which writes a date that always reports
#      one second and an earlier archive at the name the archive command gives
#      the seeded log at that second, and puts that date first on the claude
#      call's PATH. Before a live call, S5, S5b, and S6b run check_live.py
#      preflight under the call's environment, which stops the scenario
#      without spending when its premise does not hold;
#   4. runs each turn's prompt (a second turn resumes the first turn's
#      session) and checks subagent_stats.by_type, permission_denials, the
#      usage ledger against modelUsage, the log's new entries, the product
#      tree against A, and the archive files' sha256. Each claude call also
#      gets, through --settings, a PreToolUse hook with no matcher that
#      appends every tool call, the main session's and each subagent's, to a
#      hook log (check_live.py toollog; it prints nothing and always exits 0).
#      S8 reads it for the Stage 0 bound and the spawn pointer, and S9 for
#      its skeptic spawns. A
#      scenario stops at its first failing turn, so a broken run does not
#      keep spending.
# Results, one directory per scenario run, stay in --out: each turn's
# prompt command, claude JSON and stderr, hook log, state snapshot, and
# assertion output.
set -u -o pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
FIXTURES="$ROOT/tests/fixtures"
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
# Section 6's words for S5 and S6a.
CONTINUE='Continue the squad run.'
CONTINUE_SHORT='Continue.'

SCENARIOS=(s1 s1n s2 s2b s2c s2o s3a s3b s4 s4b s5 s5b s6a s6b s7b s8 s9)
# Environment assignments for a scenario's preflight and claude calls, set by
# run_scenario from SETUP.
RUN_ENV=()

# scenario <name>: sets DESC, REPO, SEED, PATCH, COMMIT, COMMIT_MSG, SETUP,
# PREFLIGHT, PROMPTS and CHECKS (one per turn). REPO names the fixture under
# tests/fixtures/. PATCH is applied and left uncommitted; COMMIT's patches are
# applied and committed as one commit after the seed. SETUP is no-browser
# (S5b), date-shim (S6b), or empty. PREFLIGHT runs check_live.py preflight
# with the first turn's check before a live call.
scenario() {
  REPO=repo-reset
  PATCH=
  COMMIT=()
  COMMIT_MSG=
  SETUP=
  PREFLIGHT=
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
    s5)
      DESC='S5: the Executor calls a failing browser check pre-existing while unit tests pass; resuming spawns one PM, which does not PASS: AC2 reads not met, or not met: pre-existing with a needs-human: blocker to waive or re-scope it'
      REPO=repo-ui
      SEED=s5
      PATCH="$HERE/repo-ui-note.patch"
      PREFLIGHT=1
      PROMPTS=("$CONTINUE")
      CHECKS=(s5) ;;
    s5b)
      DESC='S5b: S5 with no browser for its check; resuming spawns Recon, whose Checks: block names the missing browser and whose needs-human: blocker stops the run before any plan'
      REPO=repo-ui
      SEED=s5b
      SETUP=no-browser
      PREFLIGHT=1
      PROMPTS=("$CONTINUE")
      CHECKS=(s5b) ;;
    s6a)
      DESC='S6a: the log ends in a high-stakes PASS; the main session appends its high-stakes review before any spawn, then one squad-mech closing archive holds the log, review included, and empties it'
      SEED=s6a
      PATCH="$HERE/repo-reset-wo1.patch"
      PROMPTS=("$CONTINUE_SHORT")
      CHECKS=(s6a) ;;
    s6b)
      DESC='S6b: a date shim makes the Stage 1 archive name collide with an existing archive; /squad with a new goal over the parked log gets ARCHIVE FAILED, and the old archive and the log keep their sha256'
      SEED=run-parked
      SETUP=date-shim
      PREFLIGHT=1
      PROMPTS=("/squad $OTHER_GOAL")
      CHECKS=(s6b) ;;
    s7b)
      DESC='S7b: three FAILs are logged; resuming spawns nothing, appends nothing, and names the three-FAIL stop'
      SEED=s7b
      PROMPTS=("$RESUME")
      CHECKS=(s7b) ;;
    s8)
      DESC='S8 (WO-3f): the reference run, /squad <goal> on an empty log, to a PASS: before its first squad-recon spawn the main session reads no product source and runs no test, every stage spawn prompt is the five-line pointer (hook log), and its billed input and output stay within 756,000 and 12,400 tokens'
      SEED=s1
      PROMPTS=("/squad $GOAL")
      CHECKS=(s8) ;;
    s9)
      DESC='S9 (WO-3f): the WO-1 change carries about 30 planted defects and the log says run the audit, then stop before acceptance; resuming runs the finders, at most 10 skeptics, and one ## Audit Findings entry whose other findings read UNREVIEWED'
      SEED=s9
      PATCH="$HERE/repo-reset-audit.patch"
      PROMPTS=("$RESUME")
      CHECKS=(s9) ;;
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
    [ "$REPO" = repo-reset ] || setup=", on tests/fixtures/$REPO"
    [ -z "$PATCH" ] || setup="$setup, then applies ${PATCH#"$ROOT"/} uncommitted"
    if [ ${#COMMIT[@]} -gt 0 ]; then
      setup="$setup, then commits"
      for patch in "${COMMIT[@]}"; do
        setup="$setup ${patch#"$ROOT"/}"
      done
      setup="$setup as '$COMMIT_MSG'"
    fi
    case $SETUP in
      no-browser) setup="$setup, with PLAYWRIGHT_BROWSERS_PATH set to an empty directory" ;;
      date-shim) setup="$setup, with a date shim fixing the clock and an archive already at the name it gives the log" ;;
    esac
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
[ -f "$CHECK" ] || die "missing $CHECK"
for name in "${selected[@]}"; do
  scenario "$name"
  [ -d "$FIXTURES/$REPO" ] || die "missing $FIXTURES/$REPO"
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

# settings_json <hook log>: the --settings value. It turns off an installed
# copy of the plugin, so only this checkout loads (--plugin-dir), and adds the
# hook log: a PreToolUse hook with no matcher that runs check_live.py toollog
# on every tool call. The hook's output goes nowhere and a failure exits 0, so
# it never blocks or changes a call.
settings_json() {
  "$PYTHON" - "$CHECK" "$1" <<'PYEOF'
import json, shlex, sys
check, log = sys.argv[1:3]
hook = " ".join(shlex.quote(part) for part in (sys.executable, check, "toollog", log)) + " >/dev/null 2>&1 || true"
print(json.dumps({"enabledPlugins": {"compute-squad@compute-squad": False},
                  "hooks": {"PreToolUse": [{"hooks": [{"type": "command", "command": hook}]}]}},
                 separators=(",", ":")))
PYEOF
}

# claude_cmd <prompt> <session or empty> <hook log>: the section 6
# invocation, in CMD, with the hook log in its --settings.
# Task joins Agent in --allowedTools because Claude Code 2.1.282 names the
# spawn tool Task. Skill must stay: under -p that CLI passes "/squad ..." to
# the model as text, and the model loads the plugin command through the Skill
# tool. --model and --max-budget-usd are added only when given.
claude_cmd() {
  local settings
  settings=$(settings_json "$3") || die "cannot build the --settings value with $PYTHON"
  CMD=()
  [ ${#RUN_ENV[@]} -eq 0 ] || CMD=(env "${RUN_ENV[@]}")
  CMD+=("$CLAUDE_BIN" -p "$1" --output-format json --plugin-dir "$ROOT"
    --settings "$settings"
    --permission-mode acceptEdits)
  [ -z "$MODEL" ] || CMD+=(--model "$MODEL")
  [ -z "$BUDGET" ] || CMD+=(--max-budget-usd "$BUDGET")
  [ -z "$2" ] || CMD+=(--resume "$2")
  CMD+=(--allowedTools Agent Task Read Write Edit Bash Grep Glob Skill)
}

# A claude session started from inside another Claude Code session inherits
# that session's ID and writes into its transcript; start each run clean.
# When the scenario sets RUN_ENV, CMD opens with env and those assignments.
run_claude() {
  (cd "$1" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_REMOTE_SESSION_ID -u CLAUDE_CODE_CHILD_SESSION \
    "${CMD[@]}" >"$2.json" 2>"$2.err")
}

run_scenario() {
  local name=$1 rep=$2 dir repo base head session= i turn check prompt patch tools rc=0
  scenario "$name"
  dir="$OUT/$name-$rep"
  repo="$dir/repo"
  RUN_ENV=()
  printf '\n== %s (run %s of %s)\n   %s\n' "$name" "$rep" "$REPEAT" "$DESC"
  if [ "$MODE" = dry ]; then
    printf '  setup:\n'
  else
    mkdir -p "$repo" || return 2
  fi
  step cp -a "$FIXTURES/$REPO/." "$repo/" || return 2
  step git -C "$repo" -c init.defaultBranch=main init -q || return 2
  step git -C "$repo" add -A || return 2
  step git -C "$repo" -c user.name=compute-squad-live -c user.email=live@example.invalid \
    -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m "base A: tests/fixtures/$REPO" || return 2
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
  case $SETUP in
    no-browser)
      step mkdir -p "$dir/no-browsers" || return 2
      RUN_ENV=("PLAYWRIGHT_BROWSERS_PATH=$dir/no-browsers") ;;
    date-shim)
      step "$PYTHON" "$CHECK" collide "$repo" "$dir/shim" || return 2
      RUN_ENV=("PATH=$dir/shim:$PATH") ;;
  esac
  if [ "$MODE" = setup ]; then
    "$PYTHON" "$ROOT/tests/check_logs.py" "$repo/COMPUTE_SQUAD_LOG.md" | sed 's/^/  /' || return 1
  fi
  if [ -n "$PREFLIGHT" ]; then
    printf '  preflight:\n    (cd %q &&\n     ' "$repo"
    [ ${#RUN_ENV[@]} -eq 0 ] || printf 'env '
    printf '%q ' ${RUN_ENV[@]+"${RUN_ENV[@]}"} "$PYTHON" "$CHECK" preflight "${CHECKS[0]}" "$repo"; printf ')\n'
    if [ "$MODE" = live ]; then
      (cd "$repo" && env ${RUN_ENV[@]+"${RUN_ENV[@]}"} "$PYTHON" "$CHECK" preflight "${CHECKS[0]}" "$repo") | sed 's/^/    /'
      [ "${PIPESTATUS[0]}" -eq 0 ] || { printf '    the premise of %s does not hold here; nothing spent\n' "$name"; return 2; }
    fi
  fi

  for i in "${!PROMPTS[@]}"; do
    turn=$((i + 1))
    check=${CHECKS[$i]}
    prompt=${PROMPTS[$i]//<C>/$head}
    tools="$dir/turn$turn.tools.jsonl"
    if [ "$MODE" = live ]; then
      claude_cmd "$prompt" "$session" "$tools"
    else
      claude_cmd "$prompt" "$([ "$turn" -gt 1 ] && printf '<session_id from turn 1>')" "$tools"
    fi
    printf '  turn %s, check %s:\n    (cd %q &&\n     ' "$turn" "$check" "$repo"
    printf '%q ' "${CMD[@]}"; printf ')\n'
    [ "$MODE" = live ] || continue

    printf '%q ' "${CMD[@]}" >"$dir/turn$turn.cmd"
    "$PYTHON" "$CHECK" snapshot "$repo" "$base" "$dir/turn$turn.state.json" >/dev/null || return 2
    run_claude "$repo" "$dir/turn$turn"
    printf '    claude exited %s\n' "$?"
    "$PYTHON" "$CHECK" verify "$check" "$repo" "$base" "$dir/turn$turn.state.json" "$dir/turn$turn.json" \
      --tools "$tools" --summary "$OUT/summary.tsv" --label "$name#$rep turn $turn" \
      | tee "$dir/turn$turn.check.txt" | sed 's/^/    /'
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
