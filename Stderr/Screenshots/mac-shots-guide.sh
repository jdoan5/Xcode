#!/bin/bash
# Walks you through the four Mac screenshots.
# The capture itself must be manual: taking a screenshot programmatically needs
# Screen Recording permission, which is not available in every environment. This
# does everything either side of it.
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p raw-mac
DD="/tmp/stderr-mac-guide"
echo "== building the Mac app =="
xcodebuild -project ../Stderr.xcodeproj -scheme Stderr \
  -destination 'platform=macOS,variant=Mac Catalyst' -configuration Debug \
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build >/dev/null || { echo "build failed"; exit 1; }
APP=$(find "$DD" -name "Stderr.app" -path "*maccatalyst*" | head -1)
[ -n "$APP" ] || { echo "could not find the built app"; exit 1; }

step () {  # step <n> <name> <what you should see> [args...]
  local N="$1" NAME="$2" SEE="$3"; shift 3
  pkill -f "maccatalyst/Stderr.app" 2>/dev/null; sleep 1
  open "$APP" ${@:+--args "$@"}
  sleep 4
  echo "-------------------------------------------------------------"
  echo " SHOT $N - $NAME"
  echo " You should see: $SEE"
  echo
  echo " 1. Shape the window to roughly 16:10 - about 1600x1000 - and NOT full"
  echo "    width. The App Store canvas is 2560x1600, so an ultra-wide window"
  echo "    letterboxes into a thin strip and the text comes out tiny."
  echo " 2. Shift-Cmd-4, then Space, then click the window."
  echo " 3. Put the file at:  $(pwd)/raw-mac/$N-$NAME.png"
  echo
  read -r -p " Press Return when that file is in place... " _
}

step 01 wall    "the grid of captured outputs, with the symptom sidebar"
step 02 trap    "one entry: IT PRINTED, the program, the beliefs" --trap java.casting.q1
step 03 refused "only the programs that refused to run"           --refused
step 04 search  "a pasted compiler message finding its entry"     --search "cannot find symbol"

pkill -f "maccatalyst/Stderr.app" 2>/dev/null
echo; echo "== compositing =="; bash composite-mac.sh
