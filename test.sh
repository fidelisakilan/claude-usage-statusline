#!/bin/bash
# Checks each pet mood resolves as expected. Run: ./test.sh  (run before 6am and "sleepy" wins some cases)
cd "$(dirname "$0")"
T=$(mktemp); sid=test-$$; d=/tmp/claude-statusline/$sid; fail=0; now=$(date +%s)
trap 'rm -rf "$T" "$d"' EXIT
run() { # expected-face  jq-overrides  [transcript-age-seconds]
  ts=$(( now - ${3:-0} )); touch -d "@$ts" "$T" 2>/dev/null || touch -t "$(date -r $ts +%Y%m%d%H%M.%S)" "$T"  # GNU || BSD
  got=$(jq -nc --arg t "$T" --arg sid "$sid" "{session_id:\$sid, transcript_path:\$t, model:{display_name:\"Opus 5.5 (1M context)\"},
    cost:{total_cost_usd:1, total_duration_ms:0, total_lines_added:0, total_lines_removed:0},
    context_window:{used_percentage:10}, rate_limits:{five_hour:{used_percentage:30, resets_at:($now+9999)}, seven_day:{used_percentage:30}}} | $2" \
    | COLUMNS=120 ./statusline.sh | sed 's/\x1b\[[0-9;]*m//g' | grep -o '([^)]*)\(zz\| x[0-9]*\)\?' | head -1)
  [[ $got == "$1" ]] && echo "ok    $1" || { echo "FAIL  want $1  got $got  ($2)"; fail=1; }
}
run '(^‿^)' '.rate_limits.five_hour.used_percentage=5'
run '(◕‿◕)' '.'
run '(◕‿◕)' '.rate_limits.five_hour.used_percentage=50'
run '(≖_≖)' '.rate_limits.five_hour.used_percentage=65'
run '(°▃°)' '.rate_limits.five_hour.used_percentage=80'
run '(╥_╥)' '.rate_limits.five_hour.used_percentage=95'
run '(x_x)' '.rate_limits.five_hour.used_percentage=100'
run '(x_x)' '.rate_limits.seven_day.used_percentage=100'
run '(ಠ_ಠ)' '.rate_limits.seven_day.used_percentage=92'
run '(◉Д◉)' '.context_window.used_percentage=92'
run '(◔_◔)' ".rate_limits.five_hour.used_percentage=95 | .rate_limits.five_hour.resets_at=$((now+600))"
run '($‿$)' '.cost.total_cost_usd=12'
run '($▃$)' '.cost.total_cost_usd=60'
run '($Д$)' '.cost.total_cost_usd=120'
run '(>▃<)' '.cost.total_lines_removed=400 | .cost.total_lines_added=100'
run '(>Д<)' '.cost.total_lines_removed=1200 | .cost.total_lines_added=100'
run '(⌐■_■)' '.cost.total_lines_added=600'
run '(⌐■‿■)' '.cost.total_lines_added=2500'
run '(-o-)' '.cost.total_duration_ms=18000000'
run '(-_-)zz' '.' 700
run '(◕‿◕)' '.transcript_path="/nonexistent/new-session.jsonl"'  # new session, no transcript yet: awake
run '(x_x)' '.rate_limits.five_hour.used_percentage=100' 700
run '(◕‿◕)' 'del(.rate_limits) | .context_window.used_percentage=50'
# busy: hooks mark it; face animates (so check the mood family, not an exact frame)
echo "{\"session_id\":\"$sid\"}" | ./statusline.sh busy
[[ -e $d/busy ]] && echo "ok    busy flag set" || { echo "FAIL  busy flag"; fail=1; }
echo "{\"session_id\":\"$sid\"}" | ./statusline.sh idle
[[ ! -e $d/busy ]] && echo "ok    busy flag cleared" || { echo "FAIL  idle"; fail=1; }
# Esc-interrupt: Stop never fires, but the transcript ends with the interrupt note, so the flag is dropped
echo "{\"session_id\":\"$sid\"}" | ./statusline.sh busy
echo '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}' > "$T"
jq -nc --arg t "$T" --arg sid "$sid" '{session_id:$sid, transcript_path:$t, model:{display_name:"Opus"}, cost:{total_cost_usd:1}, context_window:{used_percentage:10}, rate_limits:{five_hour:{used_percentage:30}}}' | ./statusline.sh >/dev/null
[[ ! -e $d/busy ]] && echo "ok    interrupt clears busy" || { echo "FAIL  interrupt left busy set"; fail=1; }
echo "{\"session_id\":\"$sid\"}" | ./statusline.sh busy
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"working"}]}}' > "$T"
jq -nc --arg t "$T" --arg sid "$sid" '{session_id:$sid, transcript_path:$t, model:{display_name:"Opus"}, cost:{total_cost_usd:1}, context_window:{used_percentage:10}, rate_limits:{five_hour:{used_percentage:30}}}' | ./statusline.sh >/dev/null
[[ -e $d/busy ]] && echo "ok    normal work keeps busy" || { echo "FAIL  busy dropped while working"; fail=1; }
echo "{\"session_id\":\"$sid\"}" | ./statusline.sh idle; : > "$T"
# agents: two start, boss face with count; one stops by id, one without id
echo "{\"session_id\":\"$sid\",\"agent_id\":\"a1\"}" | ./statusline.sh agent-start
echo "{\"session_id\":\"$sid\",\"agent_id\":\"a2\"}" | ./statusline.sh agent-start
got=$(jq -nc --arg t "$T" --arg sid "$sid" '{session_id:$sid, transcript_path:$t, model:{display_name:"Opus"}, cost:{total_cost_usd:1}, context_window:{used_percentage:10}, rate_limits:{five_hour:{used_percentage:30}}}' | ./statusline.sh | sed 's/\x1b\[[0-9;]*m//g')
[[ $got == *"(¬"*" x2 ·"* || $got == *"(-‿-) x2 ·"* ]] && echo "ok    boss x2" || { echo "FAIL  boss x2: $got"; fail=1; }
echo "{\"session_id\":\"$sid\",\"agent_id\":\"a1\"}" | ./statusline.sh agent-stop
echo "{\"session_id\":\"$sid\"}" | ./statusline.sh agent-stop
n=$(ls "$d/agents" | wc -l | tr -d ' '); [[ $n == 0 ]] && echo "ok    agents back to 0" || { echo "FAIL  agents left: $n"; fail=1; }
exit $fail
