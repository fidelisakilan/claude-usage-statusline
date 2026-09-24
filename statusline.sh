#!/bin/bash
# Model on the left; mood face · cost · ctx % · 5h % · 7d % right-aligned
export LC_ALL=en_US.UTF-8
{ read -r model; read -r face; read -r color; read -r line; } < <(jq -r '
  def pct(p): "\(p // 0 | floor)%";
  # pwnagotchi-style face: mood follows 5h usage (context use if no plan limits);
  # each mood has 6 idle frames (glance, blink) stepped once per 2s refresh
  (.rate_limits.five_hour.used_percentage // .context_window.used_percentage // 0 | floor) as $p |
  ((now / 2 | floor) % 6) as $f |
  (if $p >= 100 then ["(☓‿‿☓)","(☓‿‿☓)","(☓‿‿☓)","(☓‿‿☓)","(☓‿‿☓)","(☓‿‿☓)"]
   elif $p >= 90 then ["(╥☁╥ )","(╥☁╥ )","( ╥☁╥)","(╥☁╥ )","(╥☁╥ )","(╥☁╥ )"]
   elif $p >= 75 then ["(°▃▃°)","(°▃▃°)","( ⚆_⚆)","(☉_☉ )","(°▃▃°)","(°▃▃°)"]
   elif $p >= 60 then ["(-__-)","(-__-)","(≖__≖)","(-__-)","(≖__≖)","(-__-)"]
   elif $p >= 45 then ["(•‿‿•)","( ⚆_⚆)","(☉_☉ )","(•‿‿•)","(•‿‿•)","(-‿‿-)"]
   elif $p >= 15 then ["(◕‿‿◕)","(◕‿‿◕)","( ◕‿◕)","(◕‿◕ )","(◕‿‿◕)","(-‿‿-)"]
   else ["(ᵔ◡◡ᵔ)","(ᵔ◡◡ᵔ)","( ◕‿◕)","(◕‿◕ )","(ᵔ◡◡ᵔ)","(⌐■_■)"] end) as $frames |
  (.model.display_name | sub(" \\(.*\\)$"; "")),  # "Opus 5.5 (1M context)" → "Opus 5.5"
  $frames[$f],
  (if $p >= 90 then 31 elif $p >= 75 then 91 elif $p >= 60 then 33 else 32 end),
  ([ "$" + ((.cost.total_cost_usd // 0) * 100 | round / 100 | tostring),
     "ctx " + pct(.context_window.used_percentage),
     (if .rate_limits.five_hour then "5h " + pct(.rate_limits.five_hour.used_percentage) else empty end),
     (if .rate_limits.seven_day then "7d " + pct(.rate_limits.seven_day.used_percentage) else empty end)
   ] | join(" · "))')
# ponytail: width from the controlling tty, then $COLUMNS; falls back to 2 spaces if neither exists
cols=$( { stty size </dev/tty | cut -d" " -f2; } 2>/dev/null ); cols=${cols:-$COLUMNS}
pad=$(( ${cols:-0} - ${#model} - ${#face} - 1 - ${#line} - 4 ))  # 4 = Claude Code's own left indent + margin
(( pad < 2 )) && pad=2
printf '%s%*s\e[%sm%s\e[0m %s' "$model" "$pad" '' "$color" "$face" "$line"
