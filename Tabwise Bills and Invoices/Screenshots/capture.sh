#!/bin/bash
# Automated App Store screenshot capture for Invoice Tracker.
# Captures native iPhone 6.9" + iPad 13" screens, then scales the other
# marketing sizes. Run from the Screenshots/ directory:  bash capture.sh
set -euo pipefail
cd "$(dirname "$0")"

PROJ="../InvoiceTracker.xcodeproj"
SCHEME="InvoiceTracker"
BID="com.jdoan.InvoiceTracker"
DD="/tmp/invoicetracker"
APP="$DD/Build/Products/Debug-iphonesimulator/Invoice Tracker.app"

IPHONE="iPhone 17 Pro Max"   # 6.9" — 1320×2868
IPAD="iPad Pro 13-inch (M5)" # 13"  — 2064×2752

# ---- build once for the simulator ----
xcodebuild -project "$PROJ" -scheme "$SCHEME" \
  -sdk iphonesimulator -configuration Debug \
  -destination "platform=iOS Simulator,name=$IPHONE" \
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build

capture_device() {
  local DEV="$1" OUT="$2"
  xcrun simctl boot "$DEV" 2>/dev/null || true
  xcrun simctl bootstatus "$DEV" -b
  # clean, consistent marketing status bar
  xcrun simctl status_bar "$DEV" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 --dataNetwork wifi 2>/dev/null || true
  xcrun simctl uninstall "$DEV" "$BID" 2>/dev/null || true   # start clean (don't duplicate seed)
  xcrun simctl install "$DEV" "$APP"

  # 01 invoices — seed the sample data ONCE here (it persists for later launches)
  xcrun simctl launch "$DEV" "$BID" --seed-sample --unlock --tab-ledger
  sleep 5; xcrun simctl io "$DEV" screenshot "$OUT/01-invoices.png"

  # 02 dashboard
  xcrun simctl terminate "$DEV" "$BID" 2>/dev/null || true
  xcrun simctl launch "$DEV" "$BID" --unlock --tab-dashboard
  sleep 5; xcrun simctl io "$DEV" screenshot "$OUT/02-dashboard.png"

  # 03 settings
  xcrun simctl terminate "$DEV" "$BID" 2>/dev/null || true
  xcrun simctl launch "$DEV" "$BID" --unlock --tab-settings
  sleep 4; xcrun simctl io "$DEV" screenshot "$OUT/03-settings.png"

  xcrun simctl terminate "$DEV" "$BID" 2>/dev/null || true
}

echo "== iPhone capture =="
capture_device "$IPHONE" "raw"

echo "== iPad capture =="
capture_device "$IPAD" "raw-ipad"

echo "== scale iPhone marketing sets =="
for f in raw/*.png; do
  b=$(basename "$f")
  cp "$f" "marketing-6.9/$b"
  sips -z 2796 1290 "$f" --out "marketing-6.7/$b" >/dev/null
  sips -z 2688 1242 "$f" --out "marketing-6.5/$b" >/dev/null
done

echo "== scale iPad marketing sets =="
for f in raw-ipad/*.png; do
  b=$(basename "$f")
  cp "$f" "marketing-ipad-13/$b"
  sips -z 2732 2048 "$f" --out "marketing-ipad-12.9/$b" >/dev/null
done

echo "DONE. Captured screens:"
find raw raw-ipad -name '*.png' | sort
