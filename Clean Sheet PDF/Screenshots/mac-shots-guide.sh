#!/bin/bash
# Walks you through capturing the four Mac screenshots by hand.
#
# The capture itself has to be manual: taking a screenshot programmatically
# needs Screen Recording permission, which not every environment has. This does
# everything either side of it — builds the Mac app, opens it on the right
# screen, and waits while you press Shift-Cmd-4 then Space and click the window.
#
# Run from the Screenshots/ directory:  bash mac-shots-guide.sh
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p raw-mac

DD="/tmp/cleansheet-mac-guide"
echo "== building the Mac app =="
xcodebuild -project ../CleanSheet.xcodeproj -scheme CleanSheet \
  -destination 'platform=macOS,variant=Mac Catalyst' -configuration Debug \
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build >/dev/null || { echo "build failed"; exit 1; }
APP=$(find "$DD" -name "CleanSheet.app" -path "*maccatalyst*" | head -1)
[ -n "$APP" ] || { echo "could not find the built app"; exit 1; }
echo "   built: $APP"
echo

step () {   # step <number> <name> <what you should see> [launch args...]
  local N="$1" NAME="$2" SEE="$3"; shift 3
  pkill -f "maccatalyst/CleanSheet.app" 2>/dev/null; sleep 1
  open "$APP" --args --seed-sample "$@"
  sleep 4
  echo "-------------------------------------------------------------"
  echo " SHOT $N — $NAME"
  echo " You should be looking at: $SEE"
  echo
  echo " 1. Drag the window corner to make it as LARGE as it will go."
  echo "    An undersized capture cannot be rescued afterwards."
  echo " 2. Press Shift-Cmd-4, then Space, then click the window."
  echo " 3. Drag the file from your Desktop into:"
  echo "      $(pwd)/raw-mac/$N-$NAME.png"
  echo
  read -r -p " Press Return when that file is in place... " _
}

step 01 library "the document list, with Employment Agreement in it"
step 02 reader  "the contract open and readable"          --open-first
step 03 redact  "the Redact screen with two black bars already drawn" --redact
step 04 privacy "the Settings screen listing the privacy claims"      --settings

pkill -f "maccatalyst/CleanSheet.app" 2>/dev/null
echo
echo "== compositing =="
bash composite-mac.sh
