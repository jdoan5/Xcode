#!/bin/bash
# macOS App Store screenshot capture for Invoice Tracker.
# Launches the Mac app per tab, captures its window, and composites each onto an
# exact 2880x1800 canvas (a valid Mac App Store size) on the brand-blue background.
#
# NOTE: capturing a real app window requires Screen Recording permission for
# whatever runs this (e.g. Terminal). Grant it in System Settings > Privacy &
# Security > Screen Recording, then re-run. Run from the Screenshots/ dir.
set -uo pipefail
cd "$(dirname "$0")"

PROJ="../InvoiceTracker.xcodeproj"
SCHEME="InvoiceTracker"
DD="/tmp/it-mac-shots"
APP="$DD/Build/Products/Debug/Invoice Tracker.app"
BRAND="2B5BD7"
mkdir -p raw-mac marketing-mac

echo "== building macOS app =="
xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination 'platform=macOS' \
  -configuration Debug -derivedDataPath "$DD" build >/dev/null || { echo "build failed"; exit 1; }

# Helper: print the window number for the app's main window.
cat > /tmp/winid.swift <<'SWIFT'
import CoreGraphics
import Foundation
let owner = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Invoice Tracker"
let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { exit(1) }
for w in list {
    if let o = w[kCGWindowOwnerName as String] as? String, o == owner,
       let n = w[kCGWindowNumber as String] as? Int,
       let b = w[kCGWindowBounds as String] as? [String: Any],
       let h = b["Height"] as? CGFloat, h > 200 { print(n); exit(0) }
}
exit(2)
SWIFT

capture() {
  local tab="$1" out="$2" seed="$3"
  killall "Invoice Tracker" 2>/dev/null; sleep 1
  open -n "$APP" --args --unlock $seed --tab-"$tab"
  sleep 5
  local wid; wid=$(swift /tmp/winid.swift "Invoice Tracker" 2>/dev/null)
  if [ -z "$wid" ]; then echo "!! no window id for $tab (is a GUI session active?)"; return 1; fi
  screencapture -o -x -l"$wid" "raw-mac/$out.png" || { echo "!! screencapture failed for $tab"; return 1; }
  # Pad (no upscaling needed; window opens at 1000x720 pt) onto exact 2880x1800.
  sips -p 1800 2880 --padColor "$BRAND" "raw-mac/$out.png" --out "marketing-mac/$out.png" >/dev/null
}

echo "== capturing screens =="
capture ledger    01-invoices  --seed-sample
capture dashboard 02-dashboard ""
capture settings  03-settings  ""
killall "Invoice Tracker" 2>/dev/null

echo "== results =="
for f in raw-mac/*.png marketing-mac/*.png; do
  [ -e "$f" ] || continue
  d=$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk 'NR>1{print $2}' | paste -sd'x' -)
  echo "$f -> $d"
done
echo "DONE"
