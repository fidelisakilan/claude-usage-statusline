#!/bin/bash
# tokamon, a pet for the Claude Code status line: model on the left; pet face · cost · ctx % · 5h % · 7d % right-aligned.
# Hooks call `statusline.sh busy|idle|agent-start|agent-stop` so the pet knows when Claude
# is working and how many subagents are running (see README).
# UTF-8 so ${#var} counts characters, not bytes; macOS lacks C.UTF-8, many Linux images lack en_US.UTF-8
[[ $OSTYPE == darwin* ]] && export LC_ALL=en_US.UTF-8 || export LC_ALL=C.UTF-8
if [[ $1 ]]; then
  IFS=$'\t' read -r sid aid < <(jq -r '[.session_id, .agent_id // ""] | @tsv')
  d=/tmp/claude-statusline/$sid; mkdir -p "$d/agents"
  case $1 in
    busy) touch "$d/busy" ;;
    idle) rm -f "$d/busy" ;;
    agent-start) touch "$d/agents/${aid:-$RANDOM$RANDOM}" ;;
    agent-stop) if [[ -n $aid && -e $d/agents/$aid ]]; then rm -f "$d/agents/$aid"
                else ls -t "$d/agents" | tail -1 | xargs -I{} rm -f "$d/agents/{}"; fi ;;  # no id: drop oldest
  esac
  exit
fi
input=$(cat)
IFS=$'\t' read -r sid t < <(jq -r '[.session_id, .transcript_path // ""] | @tsv' <<<"$input")
d=/tmp/claude-statusline/$sid; now=$(date +%s)
# Linux || macOS (GNU stat -f means something else) || no transcript yet: a brand-new session, so "just now"
mtime=$(stat -c %Y "$t" 2>/dev/null || stat -f %m "$t" 2>/dev/null || echo "$now")
# ponytail: an agent whose stop event is missed lingers at most 30 min
agents=$(find "$d/agents" -type f -mmin -30 2>/dev/null | wc -l | tr -d ' ')
# Stop doesn't fire on Esc-interrupt, but the transcript's last entry becomes "[Request interrupted by user]"
[[ -e $d/busy ]] && tail -n 1 "$t" 2>/dev/null | jq -e 'select(.type == "user") | .message.content
  | (if type == "array" then .[0].text else . end) // "" | startswith("[Request interrupted by user")' >/dev/null 2>&1 \
  && rm -f "$d/busy"
# ponytail: busy also needs transcript activity in the last 60s, a backstop for anything else that skips Stop
busy=false; { [[ -e $d/busy ]] && (( now - mtime < 60 )); } || (( agents > 0 )) && busy=true
{ read -r model; read -r face; read -r color; read -r line; } < <(jq -r \
  --argjson busy $busy --argjson age $(( now - mtime )) --argjson agents "$agents" '
  def pct(p): "\(p // 0 | floor)%";
  (.rate_limits.five_hour.used_percentage // .context_window.used_percentage // 0 | floor) as $p |
  (.rate_limits.seven_day.used_percentage // 0 | floor) as $w |
  (.context_window.used_percentage // 0 | floor) as $ctx |
  (.cost.total_cost_usd // 0) as $usd |
  (.cost.total_lines_added // 0) as $add | (.cost.total_lines_removed // 0) as $del |
  ((.cost.total_duration_ms // 0) / 3600000) as $hrs |
  (now | localtime | .[3]) as $hour |
  (((.rate_limits.five_hour.resets_at // 0) - now) / 60 | floor) as $left |
  # animate only while busy: one frame per 1s refresh; frame 0 is each mood'"'"'s resting face
  (now | floor) as $t | (if $busy then $t % 6 else 0 end) as $f |
  # first match wins
  (if $p >= 100 or $w >= 100 then ["(☓‿‿☓)"]                                                 # dead
   elif ($busy | not) and $age >= 600 then ["(-zz-)"]                                        # asleep (10 min idle)
   elif $ctx >= 90 then ["(@▃▃@)","(@__@)","(@_@ )","( @_@)","(@▃▃@)","(@__@)"]             # stuffed
   elif $p >= 60 and $left > 0 and $left <= 20 then ["(◔‿‿◔)","(◔‿‿◔)","(◔__◔)","(◔_◔ )","(◕‿‿◕)","(◔‿‿◔)"]  # almost free
   elif $p >= 90 then ["(╥☁╥ )","(╥☁╥ )","( ╥☁╥)","(╥☁╥ )","(╥☁╥ )","(╥☁╥ )"]             # crying
   elif $w >= 90 then ["(ಠ_ಠ )","(ಠ_ಠ )","( ಠ_ಠ)","(ಠ_ಠ )","(ಠ▃▃ಠ)","(ಠ_ಠ )"]             # grim
   elif $p >= 75 then ["(°▃▃°)","(°▃▃°)","( ⚆_⚆)","(☉_☉ )","(°▃▃°)","(°▃▃°)"]             # alarmed
   elif $agents > 0 then ["(ಠ‿‿ಠ)","(ಠ‿‿ಠ)","( ಠ‿ಠ)","(ಠ‿ಠ )","(ಠ‿‿ಠ)","(-‿‿-)"]           # boss
   elif $busy and $t % 120 == 119 then ["(⌐■_■)"]                                             # easter egg
   elif $usd >= 50 then ["($▃▃$)","($▃▃$)","($__$)","($▃▃$)","( $▃$)","($▃$ )"]              # whale
   elif $usd >= 10 then ["($‿‿$)","($‿‿$)","( $‿$)","($‿$ )","($‿‿$)","($▃▃$)"]              # rich
   elif $del >= 300 and $del > $add then ["(>▃▃<)","(>▃▃<)","(>__<)","(>▃▃<)","( >▃<)","(>▃< )"]  # demolition
   elif $add >= 500 then ["(⌐■_■)","(⌐■_■)","(⌐■‿■)","(⌐■_■)","(⌐■_■)","(⌐■‿■)"]            # builder
   elif $hrs >= 4 or $hour < 6 then ["(-__-)","(-__-)","(-oo-)","(-__-)","(-__-)","(-oo-)"]  # sleepy
   elif $p >= 60 then ["(≖__≖)","(≖__≖)","(-__-)","(≖__≖)","(≖_≖ )","( ≖_≖)"]               # bored
   elif $p >= 45 then ["(•‿‿•)","( ⚆_⚆)","(☉_☉ )","(•‿‿•)","(•‿‿•)","(-‿‿-)"]               # neutral
   elif $p >= 15 then ["(◕‿‿◕)","(◕‿‿◕)","( ◕‿◕)","(◕‿◕ )","(◕‿‿◕)","(-‿‿-)"]               # happy
   else ["(ᵔ◡◡ᵔ)","(ᵔ◡◡ᵔ)","( ◕‿◕)","(◕‿◕ )","(ᵔ◡◡ᵔ)","(⌐■_■)"] end) as $frames |          # giddy
  (.model.display_name | sub(" \\(.*\\)$"; "")),  # "Opus 5.5 (1M context)" → "Opus 5.5"
  $frames[$f % ($frames | length)] + (if $agents > 0 then " x\($agents)" else "" end),
  (if $p >= 90 then 31 elif $p >= 75 then 91 elif $p >= 60 then 33 else 32 end),
  ([ ((.cost.total_cost_usd // 0) * 100 | round) as $c | "$\($c / 100 | floor).\($c % 100 / 10 | floor)\($c % 10)",
     "ctx " + pct(.context_window.used_percentage),
     (if .rate_limits.five_hour then "5h " + pct(.rate_limits.five_hour.used_percentage) else empty end),
     (if .rate_limits.seven_day then "7d " + pct(.rate_limits.seven_day.used_percentage) else empty end)
   ] | join(" · "))' <<<"$input")
# ponytail: width from the controlling tty, then $COLUMNS; falls back to 2 spaces if neither exists
cols=$( { stty size </dev/tty | cut -d" " -f2; } 2>/dev/null ); cols=${cols:-$COLUMNS}
pad=$(( ${cols:-0} - ${#model} - ${#face} - 3 - ${#line} - 4 ))  # 4 = Claude Code's own left indent + margin
(( pad < 2 )) && pad=2
printf '%s%*s\e[%sm%s\e[0m · %s' "$model" "$pad" '' "$color" "$face" "$line"
