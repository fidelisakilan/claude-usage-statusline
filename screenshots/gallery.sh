#!/bin/bash
# Renders every mood's face from the real statusline.sh, redrawn each second, for screenshots.
# Usage: gallery.sh static|moving   (moving = as if Claude is working)
cd "$(dirname "$0")/.."; export LC_ALL=en_US.UTF-8 COLUMNS=0  # 0 = no right-align, so faces line up
mode=${1:-static}; now=$(date +%s); base=/tmp/claude-statusline
rows=(
  "fresh|.rate_limits.five_hour.used_percentage=5"
  "happy|."
  "meh|.rate_limits.five_hour.used_percentage=65"
  "yawning|.cost.total_duration_ms=18000000"
  "builder|.cost.total_lines_added=600"
  "architect|.cost.total_lines_added=2500"
  "demolition|.cost.total_lines_removed=400"
  "wrecking ball|.cost.total_lines_removed=1200"
  "rich|.cost.total_cost_usd=12.40"
  "whale|.cost.total_cost_usd=63.10"
  "bonfire|.cost.total_cost_usd=140.25"
  "boss|."
  "worried|.rate_limits.five_hour.used_percentage=80"
  "grim|.rate_limits.seven_day.used_percentage=93"
  "crying|.rate_limits.five_hour.used_percentage=95"
  "clock-watching|.rate_limits.five_hour.used_percentage=92 | .rate_limits.five_hour.resets_at=(now+600)"
  "stuffed|.context_window.used_percentage=93"
  "asleep|."
  "dead|.rate_limits.five_hour.used_percentage=100"
)
setup() { # i name -> session dir with busy flag / agents / transcript age
  local d=$base/gallery-$1; rm -rf "$d"; mkdir -p "$d/agents"; touch "$d/transcript"
  [[ $2 == asleep ]] && touch -t "$(date -r $((now-700)) +%Y%m%d%H%M.%S)" "$d/transcript"
  [[ $mode == moving && $2 != asleep ]] && touch "$d/busy"
  [[ $2 == boss ]] && touch "$d/agents/a1" "$d/agents/a2"
}
for i in "${!rows[@]}"; do setup $i "${rows[i]%%|*}"; done
trap 'rm -rf $base/gallery-*' EXIT
printf '\e[?25l'; clear
while :; do
  out=$'\e[H\n'
  for i in "${!rows[@]}"; do
    name=${rows[i]%%|*}; f=${rows[i]#*|}; d=$base/gallery-$i
    [[ -e $d/busy ]] && touch "$d/transcript"
    line=$(jq -nc --arg sid gallery-$i --arg t "$d/transcript" "{session_id:\$sid, transcript_path:\$t,
      model:{display_name:\"Opus 5.5 (1M context)\"}, cost:{total_cost_usd:2.52, total_duration_ms:0, total_lines_added:0, total_lines_removed:0},
      context_window:{used_percentage:12}, rate_limits:{five_hour:{used_percentage:30, resets_at:(now+9999)}, seven_day:{used_percentage:30}}} | $f" \
      | perl -MPOSIX -e "setsid; exec @ARGV" ./statusline.sh \
      | sed $'s/^[^\e]*\e\\[2m[^\e]*\e\\[0m //; s/\(\e\\[0m\\).*/\\1/')  # drop model and dim mood, keep the coloured face
    out+=$(printf '  \e[2m%-14s\e[0m %s\e[K' "$name" "$line")$'\n'
  done
  printf '%s' "$out"  # draw the whole frame at once
  sleep "$(printf '0.%03d' $(( 999 - 10#$(date +%N | cut -c1-3) )))"  # redraw on each second boundary
done
