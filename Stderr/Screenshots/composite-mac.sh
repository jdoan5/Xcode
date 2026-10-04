#!/bin/bash
# Turns hand-captured Mac window shots in raw-mac/ into App Store images.
# Needs no special permission - this is pure image processing, unlike the capture.
#
#   1. Run mac-shots-guide.sh, or open the Mac app yourself.
#   2. Shape the window to roughly 16:10 (about 1600x1000), then Shift-Cmd-4,
#      Space, click the window. Do NOT maximise on a wide display: the canvas is
#      2560x1600 and a 2.6:1 window letterboxes into a strip with tiny text.
#      An undersized capture cannot be rescued afterwards either.
#   3. Put the files in raw-mac/ as 01-wall.png, 02-trap.png, 03-refused.png,
#      04-search.png, then run this.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p raw-mac marketing-mac
shopt -s nullglob
FILES=(raw-mac/*.png)
[ ${#FILES[@]} -gt 0 ] || { echo "raw-mac/ is empty - capture the windows first."; exit 1; }
FAIL=0
for f in "${FILES[@]}"; do
  swift composite.swift "$f" "marketing-mac/$(basename "$f")" 2560 1600 0B0E12 || FAIL=1
done
for f in marketing-mac/*.png; do
  sips -g hasAlpha "$f" 2>/dev/null | grep -q "hasAlpha: yes" && { echo "ALPHA LEFT IN $f"; FAIL=1; }
done
[ $FAIL -eq 0 ] && echo "done - marketing-mac/ is 2560x1600 and ready." \
                || { echo; echo "Some shots were refused for being too small. Re-capture with the window maximised."; exit 1; }
