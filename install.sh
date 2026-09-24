#!/bin/bash
# Installs tokamon: copies statusline.sh to ~/.claude and merges the status line + hooks
# into ~/.claude/settings.json (backed up first). Safe to re-run. `install.sh uninstall` reverses it.
#   curl -fsSL https://raw.githubusercontent.com/fidelisakilan/tokamon/main/install.sh | bash
set -euo pipefail
command -v jq >/dev/null || { echo "tokamon needs jq: brew install jq (or apt install jq)" >&2; exit 1; }
dir=~/.claude; script=$dir/statusline.sh; settings=$dir/settings.json
cmd="~/.claude/statusline.sh"
mkdir -p "$dir"; [[ -f $settings ]] || echo '{}' > "$settings"
jq empty "$settings" 2>/dev/null || { echo "$settings isn't valid JSON; fix it and re-run." >&2; exit 1; }
cp "$settings" "$settings.bak"

if [[ ${1:-} == uninstall ]]; then
  jq --arg c "$cmd" '
    (if .statusLine.command == $c then del(.statusLine) else . end)
    | .hooks |= (if . then with_entries(.value |= (map(.hooks |= map(select(.command | startswith($c + " ") | not)))
                                                  | map(select(.hooks | length > 0))))
                 | with_entries(select(.value | length > 0)) else . end)
    | if .hooks == {} then del(.hooks) else . end' "$settings.bak" > "$settings.new"
  mv "$settings.new" "$settings"
  rm -f "$script"
  echo "tokamon uninstalled. Previous settings saved to $settings.bak"; exit
fi

src=$(dirname "${BASH_SOURCE[0]:-}")/statusline.sh
if [[ -f $src ]]; then cp "$src" "$script"   # running from a clone
else curl -fsSL https://raw.githubusercontent.com/fidelisakilan/tokamon/main/statusline.sh -o "$script"; fi
chmod +x "$script"

old=$(jq -r '.statusLine.command // empty' "$settings.bak")
[[ -n $old && $old != "$cmd" ]] && echo "Replacing your existing status line ($old)."
jq --arg c "$cmd" '
  def hook(ev; arg): ($c + " " + arg) as $h
    | .hooks[ev] = ((.hooks[ev] // []) | if any(.[].hooks[]?; .command == $h) then . else . + [{hooks: [{type: "command", command: $h}]}] end);
  .statusLine = {type: "command", command: $c, refreshInterval: 1}
  | hook("UserPromptSubmit"; "busy") | hook("Stop"; "idle")
  | hook("SubagentStart"; "agent-start") | hook("SubagentStop"; "agent-stop")' "$settings.bak" > "$settings.new"
mv "$settings.new" "$settings"  # only replace settings once jq succeeded
echo "tokamon installed. It hatches on the next redraw. Previous settings saved to $settings.bak"
