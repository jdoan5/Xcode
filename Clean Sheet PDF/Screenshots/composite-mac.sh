#!/bin/bash
# Turns hand-captured window shots in raw-mac/ into Mac App Store images in
# marketing-mac/. Needs no special permission — this is pure image processing,
# unlike the capture itself.
#
#   1. Open the Mac app, then press Shift-Cmd-4 then Space and click its window.
#      The shot lands on your Desktop. Make the window as large as it will go
#      first: an undersized capture cannot be rescued later.
#   2. Move the files into raw-mac/ and name them 01-something.png, 02-... .
#   3. bash composite-mac.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p raw-mac marketing-mac
shopt -s nullglob
FILES=(raw-mac/*.png)
if [ ${#FILES[@]} -eq 0 ]; then
  echo "raw-mac/ is empty — capture the windows first (see the header)."
  exit 1
fi
FAIL=0
for f in "${FILES[@]}"; do
  swift composite.swift "$f" "marketing-mac/$(basename "$f")" 2560 1600 1A69BD || FAIL=1
done
# composite.swift already writes opaque output, but assert it rather than
# trusting it: an alpha channel is rejected by App Store Connect with an error
# that talks about dimensions instead.
for f in marketing-mac/*.png; do
  sips -g hasAlpha "$f" 2>/dev/null | grep -q "hasAlpha: yes" && { echo "ALPHA LEFT IN $f"; FAIL=1; }
done
[ $FAIL -eq 0 ] && echo "done — marketing-mac/ is ready to upload." \
                || { echo; echo "One or more shots were refused for being too small. Re-capture those with the window maximised."; exit 1; }
