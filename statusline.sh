#!/bin/bash
# Model on the left; cost · ctx % · 5h % · 7d % right-aligned
export LC_ALL=en_US.UTF-8
{ read -r model; read -r line; } < <(jq -r '
  def pct(p): "\(p // 0 | floor)%";
  .model.display_name,
  ([ "$" + ((.cost.total_cost_usd // 0) * 100 | round / 100 | tostring),
     "ctx " + pct(.context_window.used_percentage),
     (if .rate_limits.five_hour then "5h " + pct(.rate_limits.five_hour.used_percentage) else empty end),
     (if .rate_limits.seven_day then "7d " + pct(.rate_limits.seven_day.used_percentage) else empty end)
   ] | join(" · "))')
# ponytail: width from the controlling tty, then $COLUMNS; falls back to 2 spaces if neither exists
cols=$( { stty size </dev/tty | cut -d" " -f2; } 2>/dev/null ); cols=${cols:-$COLUMNS}
pad=$(( ${cols:-0} - ${#model} - ${#line} - 4 ))  # 4 = Claude Code's own left indent + margin
(( pad < 2 )) && pad=2
printf '%s%*s%s' "$model" "$pad" '' "$line"
