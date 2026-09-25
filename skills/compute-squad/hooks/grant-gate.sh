#!/bin/sh
# compute-squad grant gate, Claude Code PreToolUse on the Agent tool.
# Silent exit allows. Denies an executor spawn unless the latest ## Status
# in COMPUTE_SQUAD_LOG.md grants the current plan revision. Denies a
# squad-recon, squad-pm, squad-helper, or executor spawn while a needs-human:
# BLOCKER in the log has no ## Decision after it.
input=$(cat)
reader="$(dirname "$0")/json-field.awk"
field() { printf '%s' "$input" | LC_ALL=C awk -v key="$1" -f "$reader"; }
agent=$(field subagent_type)
case "${agent#compute-squad:}" in
  squad-executor|squad-executor-mechanical|squad-executor-complex) executor=yes ;;
  squad-recon|squad-pm|squad-helper) executor=no ;;
  *) exit 0 ;;
esac
cwd=$(field cwd)
root=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null || printf '%s' "${cwd:-.}")
log="$root/COMPUTE_SQUAD_LOG.md"
deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"compute-squad: %s"}}\n' "$1"
  exit 0
}
if [ "$executor" = yes ]; then
  grant=$(awk '/^## /{s=($0=="## Status"); if(s) g=""} s && /^Grant: /{g=$0} END{print g}' "$log" 2>/dev/null)
  # The current revision r<N> is the count of plan headings without (cont.),
  # the number the latest plan writes on its Attempt: line. A mislabeled
  # Attempt: line cannot move it.
  plans=$(grep -c '^## PM — Plan$' "$log" 2>/dev/null)
  case "$grant" in
    "Grant: all revisions"*) ;;
    "Grant: r${plans:-0} "*) [ "${plans:-0}" -gt 0 ] || grant= ;;
    *) grant= ;;
  esac
  [ -n "$grant" ] || deny 'the latest ## Status in COMPUTE_SQUAD_LOG.md grants no execution for the current plan revision. Record the user grant as a ## Decision and a ## Status first, or stop: a plan-mode run ends here.'
fi
# A BLOCKER: line opens a needs-human stop when the first non-blank line after
# it is its needs-human: item; a ## Decision heading closes every open one.
open=$(awk '/^## Decision$/{h=0} p && NF{p=0; if(/^- needs-human:/) h=1} /^BLOCKER:[[:space:]]*$/{p=1} END{print h+0}' "$log" 2>/dev/null)
[ "$open" != 1 ] || deny "needs-human blocker unresolved: record the user's decision before spawning a stage. A needs-human: BLOCKER in COMPUTE_SQUAD_LOG.md has no ## Decision after it."
exit 0
