#!/bin/sh
# compute-squad usage ledger, Claude Code SubagentStop and Stop hooks.
# Appends one JSON line at each stop of a squad run's subagent (one continued
# with SendMessage stops more than once, each line a running total), and a
# cumulative line for the main session, to compute-squad-archive/usage.jsonl.
# Prints nothing; exits 0.
input=$(cat)
# field reads a key's first string value. SubagentStop lists running agents,
# with their own agent_type, in background_tasks after the top-level fields
# (Claude Code 2.1.282); if a host moved those fields first, the ledger would
# name the wrong agent, which the live tier's ledger check would catch.
# The byte \001 never appears raw in JSON, so it marks where the value starts.
soh=$(printf '\001')
field() { printf '%s' "$input" | sed -n "s/\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/$soh\1/; s/.*$soh//p"; }
event=$(field hook_event_name); agent=$(field agent_type); sess=$(field session_id); cwd=$(field cwd)
root=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null || printf '%s' "${cwd:-.}")
ledger="$root/compute-squad-archive/usage.jsonl"
case "$event" in
  SubagentStop) case "$agent" in compute-squad:*) ;; *) [ -s "$root/COMPUTE_SQUAD_LOG.md" ] || exit 0 ;; esac ;;
  Stop) grep -q "\"session\":\"$sess\"" "$ledger" 2>/dev/null || exit 0 ;;
  *) exit 0 ;;
esac
run=$(grep '^Run: ' "$root/COMPUTE_SQUAD_LOG.md" 2>/dev/null | tail -n 1)
last=$(ls -t "$root"/compute-squad-archive/COMPUTE_SQUAD_LOG_*.md 2>/dev/null | head -n 1)
[ -n "$run" ] || [ -z "$last" ] || run=$(grep '^Run: ' "$last" | tail -n 1)
mkdir -p "$root/compute-squad-archive" || exit 0
# The host queues transcript writes and flushes them every 100 ms, so the
# last message can reach the transcript after the event fires. While the last
# assistant record still ends in a tool call, or has no stop reason yet, wait
# for it, at most five seconds.
open_turn() {
  turn=$(grep '"type":"assistant"' "$1" 2>/dev/null | tail -n 1)
  case "$turn" in
    '') return 1 ;;
    *'"stop_reason":"tool_use"'*) return 0 ;;
    *'"stop_reason":"'*) return 1 ;;
    *) return 0 ;;
  esac
}
if [ "$event" = Stop ]; then pending=$(field transcript_path); else pending=$(field agent_transcript_path); fi
tries=0
while [ "$tries" -lt 5 ] && open_turn "$pending"; do sleep 1; tries=$((tries + 1)); done
record() { [ -r "$3" ] || return 0; awk -v run="${run#Run: }" -v sess="$sess" -v agent="$1" -v id="$2" '
function num(k, s) { if (!match($0, "\"" k "\":[0-9]+")) return 0; s = substr($0, RSTART, RLENGTH); sub(/.*:/, "", s); return s + 0 }
function str(k) { if (!match($0, "\"" k "\":\"[^\"]*\"")) return ""; return substr($0, RSTART + length(k) + 4, RLENGTH - length(k) - 5) }
function sec(t, y, m) { y = substr(t, 1, 4) + 0; m = substr(t, 6, 2) + 0; if (m < 3) { y--; m += 12 }
  return (365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + substr(t, 9, 2)) * 86400 + substr(t, 12, 2) * 3600 + substr(t, 15, 2) * 60 + substr(t, 18, 2) }
{ t = str("timestamp"); if (t != "") { if (first == "") first = t; final = t } }
/"type":"assistant"/ && /"usage":/ {
  if (!match($0, /"id":"msg_[^"]*"/)) next; k = substr($0, RSTART + 6, RLENGTH - 7)
  if (!(k in out)) n++
  inp[k] = num("input_tokens"); cw[k] = num("cache_creation_input_tokens"); c1[k] = num("ephemeral_1h_input_tokens")
  cr[k] = num("cache_read_input_tokens"); out[k] = num("output_tokens")
  m = str("model"); if (m != "" && !(m in seen)) { seen[m] = 1; models = models (models == "" ? "" : ",") m }
  if (/"name":"Bash"/ && index($0, ">> COMPUTE_SQUAD_LOG.md") && match($0, /EOF.?\\n## [^\\"]*/)) {
    h = substr($0, RSTART, RLENGTH); sub(/^[^#]*/, "", h); heads = heads (heads == "" ? "" : "; ") h } }
END { if (n == 0) exit
  for (k in out) { a += inp[k]; b += cw[k]; c += c1[k]; d += cr[k]; e += out[k] }
  printf "{\"v\":1,\"run\":\"%s\",\"session\":\"%s\",\"agent\":\"%s\",\"agent_id\":\"%s\",\"models\":\"%s\",\"started\":\"%s\",\"stopped\":\"%s\",\"elapsed_s\":%d,\"calls\":%d,\"input\":%d,\"cache_write\":%d,\"cache_write_1h\":%d,\"cache_read\":%d,\"output\":%d,\"entries\":\"%s\"}\n", run, sess, agent, id, models, first, final, sec(final) - sec(first), n, a, b, c, d, e, heads }
' "$3" >> "$ledger" 2>/dev/null; }
[ "$event" = Stop ] || record "${agent#compute-squad:}" "$(field agent_id)" "$(field agent_transcript_path)"
record main main "$(field transcript_path)"
exit 0
