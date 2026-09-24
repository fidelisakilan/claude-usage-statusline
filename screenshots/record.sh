#!/bin/bash
# Records screenshots/dark-moving.gif: opens gallery.sh moving in Ghostty, grabs six one-second frames.
# macOS only; the terminal running this needs Screen Recording permission. Needs Pillow for the GIF.
cd "$(dirname "$0")"
open -na Ghostty --args --window-decoration=none --window-padding-x=14 --window-padding-y=10 \
  --title=tokamon-gallery --command="bash $PWD/gallery.sh moving"; sleep 3
wid=$(swift - <<'SWIFT'
import CoreGraphics
for w in CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
  where (w["kCGWindowName"] as? String) == "tokamon-gallery" { print(w["kCGWindowNumber"] as! Int) }
SWIFT
)
[[ $wid ]] || { echo "no tokamon-gallery window"; exit 1; }
for i in 0 1 2 3 4 5; do screencapture -x -o -l "$wid" "/tmp/tokamon-$i.png"; sleep 1; done
python3 - <<'PY'
from PIL import Image
ims = [Image.open(f'/tmp/tokamon-{i}.png').convert('RGB').crop((0, 24, 560, 856)) for i in range(6)]
ims[0].save('dark-moving.gif', save_all=True, append_images=ims[1:], duration=1000, loop=0)
PY
osascript -e 'tell application "System Events" to tell process "Ghostty" to click button 1 of (first window whose name is "tokamon-gallery")' 2>/dev/null
echo "wrote $PWD/dark-moving.gif"
