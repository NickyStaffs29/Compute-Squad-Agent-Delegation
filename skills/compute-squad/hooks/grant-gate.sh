#!/bin/sh
# compute-squad grant gate, Claude Code PreToolUse on the Agent tool.
# Silent exit allows. Denies an executor spawn unless the latest ## Status
# in COMPUTE_SQUAD_LOG.md grants the current plan revision and the work order
# it names, backed by an earlier ## Decision of Type grant. Denies a
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
  # Fields count only as whole lines of their own entry, which runs from its
  # exact heading to the next line starting "## ". The latest ## Status holds
  # one Grant: line. "all revisions, full-mode request" grants every
  # revision. Otherwise it reads "r<N> <G>, per Decision <T>": N is the count
  # of plan headings without (cont.), so a mislabeled Attempt: line cannot
  # move it; the same Status holds one "Plan: r<N>, work order <P>"; exactly
  # one ## Decision in the log has the line Timestamp: T, and it comes before
  # that Status with one Timestamp:, one "Type: grant", and one
  # "Covers: r<N>, work order <D>". D is G or all, and G is P or all.
  verdict=$(LC_ALL=C awk '
    { line[NR] = $0 }
    function body_end(i) { for (i++; i <= NR && substr(line[i], 1, 3) != "## "; i++) ; return i }
    END {
      for (s = NR; s > 0 && line[s] != "## Status"; s--) ;
      if (s == 0) { print "grant"; exit }
      grants = plans = 0; e = body_end(s)
      for (i = s + 1; i < e; i++) {
        if (substr(line[i], 1, 7) == "Grant: ") { grants++; g = line[i] }
        if (substr(line[i], 1, 6) == "Plan: ") { plans++; p = line[i] }
      }
      if (grants != 1) { print "grant"; exit }
      if (g == "Grant: all revisions, full-mode request") { print "ok"; exit }
      if (g !~ /^Grant: r[1-9][0-9]* [^[:space:],]+, per Decision [^[:space:]]+$/) { print "grant"; exit }
      split(g, w, " "); n = substr(w[2], 2); scope = substr(w[3], 1, length(w[3]) - 1); t = w[6]
      count = 0
      for (i = 1; i <= NR; i++) if (line[i] == "## PM — Plan") count++
      if (n != count "") { print "grant"; exit }
      if (plans != 1 || p !~ /^Plan: r[1-9][0-9]*, work order [^[:space:],<>]+$/) { print "plan"; exit }
      split(p, w, " "); if (w[2] != "r" n ",") { print "plan"; exit }
      target = w[5]
      found = 0
      for (i = 1; i <= NR; i++) {
        if (line[i] != "## Decision") continue
        hit = stamps = types = covers = 0; type = cover = ""; e = body_end(i)
        for (j = i + 1; j < e; j++) {
          if (substr(line[j], 1, 11) == "Timestamp: ") { stamps++; if (line[j] == "Timestamp: " t) hit = 1 }
          if (substr(line[j], 1, 6) == "Type: ") { types++; type = line[j] }
          if (substr(line[j], 1, 8) == "Covers: ") { covers++; cover = line[j] }
        }
        if (!hit) continue
        found++; at = i; ok = (stamps == 1 && types == 1 && covers == 1 && type == "Type: grant")
        decided = cover
      }
      if (found != 1 || at > s || !ok) { print "decision"; exit }
      if (decided !~ /^Covers: r[1-9][0-9]*, work order [^[:space:],]+$/) { print "decision"; exit }
      split(decided, w, " "); if (w[2] != "r" n ",") { print "decision"; exit }
      if ((w[5] != scope && w[5] != "all") || (scope != target && scope != "all")) { print "scope"; exit }
      print "ok"
    }' "$log" 2>/dev/null)
  case "$verdict" in
    ok) ;;
    plan) deny 'the latest ## Status in COMPUTE_SQUAD_LOG.md names no single concrete Plan: line for the plan revision its Grant: covers. Record the governing revision and work order on a ## Status first, or stop.' ;;
    decision) deny 'the Grant: in the latest ## Status in COMPUTE_SQUAD_LOG.md cites no single earlier ## Decision of Type grant for its plan revision. Record the user grant as a ## Decision and a ## Status that cites its Timestamp first, or stop.' ;;
    scope) deny 'the ## Decision that the latest ## Status in COMPUTE_SQUAD_LOG.md cites does not cover the work order its Grant: and Plan: name. Record a grant for that work order first, or stop.' ;;
    *) deny 'the latest ## Status in COMPUTE_SQUAD_LOG.md grants no execution for the current plan revision. Record the user grant as a ## Decision and a ## Status first, or stop: a plan-mode run ends here.' ;;
  esac
fi
# A BLOCKER: line opens a needs-human stop when the first non-blank line after
# it is its needs-human: item; a ## Decision heading closes every open one.
open=$(awk '/^## Decision$/{h=0} p && NF{p=0; if(/^- needs-human:/) h=1} /^BLOCKER:[[:space:]]*$/{p=1} END{print h+0}' "$log" 2>/dev/null)
[ "$open" != 1 ] || deny "needs-human blocker unresolved: record the user's decision before spawning a stage. A needs-human: BLOCKER in COMPUTE_SQUAD_LOG.md has no ## Decision after it."
exit 0
