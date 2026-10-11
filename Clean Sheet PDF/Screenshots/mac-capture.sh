#!/bin/bash
# macOS (Mac Catalyst) App Store screenshot capture for Clean Sheet PDF.
# Launches the Mac app once per screen, captures its window, and composites each
# onto an exact 2560x1600 canvas — a valid Mac App Store size — on the brand blue.
#
# REQUIRES SCREEN RECORDING PERMISSION for whatever runs this (Terminal, iTerm,
# or the editor's shell). Without it CGWindowListCopyWindowInfo returns no window
# names at all and the script cannot find the window — it will say so and stop
# rather than writing blank images. Grant it in
#   System Settings > Privacy & Security > Screen Recording
# then re-run. Run from the Screenshots/ directory:  bash mac-capture.sh
set -uo pipefail
cd "$(dirname "$0")"

PROJ="../CleanSheet.xcodeproj"
SCHEME="CleanSheet"
DD="/tmp/cleansheet-mac-shots"
BRAND="1A69BD"
mkdir -p raw-mac marketing-mac

echo "== building the Mac Catalyst app =="
xcodebuild -project "$PROJ" -scheme "$SCHEME" \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -configuration Debug -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO build >/dev/null || { echo "build failed"; exit 1; }

APP=$(find "$DD" -name "CleanSheet.app" -path "*maccatalyst*" | head -1)
[ -n "$APP" ] || { echo "could not find the built app"; exit 1; }

cat > /tmp/cs-winid.swift <<'SWIFT'
import CoreGraphics
import Foundation
guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { print("0"); exit(1) }
for w in list {
    let owner = (w[kCGWindowOwnerName as String] as? String) ?? ""
    let h = (w[kCGWindowBounds as String] as? [String: Any])?["Height"] as? Double ?? 0
    if owner == "CleanSheet", h > 200 { print((w[kCGWindowNumber as String] as? Int) ?? 0); exit(0) }
}
print("0")
SWIFT

shot () {  # shot <file> <launch args...>
  local FILE="$1"; shift
  pkill -f "maccatalyst/CleanSheet.app" 2>/dev/null; sleep 1
  open "$APP" --args --seed-sample "$@"
  sleep 6
  local ID
  ID=$(swift /tmp/cs-winid.swift 2>/dev/null | tail -1)
  if [ "$ID" = "0" ] || [ -z "$ID" ]; then
    echo "FAILED: no window found. Grant Screen Recording permission (see the header)."
    exit 1
  fi
  screencapture -x -o -l "$ID" "raw-mac/$FILE"
  echo "   raw-mac/$FILE"
}

shot 01-library.png
shot 02-reader.png  --open-first
shot 03-redact.png  --redact
shot 04-privacy.png --settings
pkill -f "maccatalyst/CleanSheet.app" 2>/dev/null

echo "== compositing onto 2560x1600 =="
for f in raw-mac/*.png; do
  out="marketing-mac/$(basename "$f")"
  # Fit the window inside the canvas with a margin, centred on the brand colour.
  sips -Z 1400 "$f" --out /tmp/cs-fit.png >/dev/null
  sips -p 1600 2560 --padColor "$BRAND" /tmp/cs-fit.png --out "$out" >/dev/null
  echo "   $out"
done

echo
echo "done. marketing-mac/ holds 2560x1600 images ready for the Mac App Store."
