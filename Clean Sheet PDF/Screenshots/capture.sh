#!/bin/bash
# Automated App Store screenshot capture for Clean Sheet PDF.
# Captures native iPhone 6.9" and iPad 13" screens, then scales the remaining
# marketing sizes. Run from the Screenshots/ directory:  bash capture.sh
#
# Every screen is reached by a DEBUG launch argument rather than by tapping, so
# a re-shoot after a copy change reproduces the same framing instead of a
# slightly different scroll offset on each image.
set -euo pipefail
cd "$(dirname "$0")"

PROJ="../CleanSheet.xcodeproj"
SCHEME="CleanSheet"
BID="com.jdoan.CleanSheet"
DD="/tmp/cleansheet-shots"
APP="$DD/Build/Products/Debug-iphonesimulator/CleanSheet.app"

IPHONE="iPhone 17 Pro Max"    # 6.9" — 1320x2868
IPAD="iPad Pro 13-inch (M5)"  # 13"  — 2064x2752

# Resolve names to UDIDs rather than passing names through.
#
# TWO SEPARATE WAYS THE NAME ALONE BREAKS, both of which have bitten this script:
# a device can exist under several runtimes at once, so simctl has to guess which
# one you meant; and xcodebuild defaults to OS:latest, so the moment a new
# runtime lands WITHOUT the model you named, the build fails with "no available
# devices matched" while that device is sitting right there under the older
# runtime. A UDID is unambiguous and survives both.
udid_for () {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
want = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
# Newest runtime first, so the shot is taken on the current OS when there is a choice.
for runtime in sorted(devices, reverse=True):
    for d in devices[runtime]:
        if d["name"] == want:
            print(d["udid"]); sys.exit(0)
sys.exit(1)' "$1"
}

IPHONE_ID="$(udid_for "$IPHONE")" || { echo "No simulator named '$IPHONE'. Available:"; xcrun simctl list devices available | grep -E "iPhone"; exit 1; }
IPAD_ID="$(udid_for "$IPAD")"     || { echo "No simulator named '$IPAD'. Available:";   xcrun simctl list devices available | grep -E "iPad";   exit 1; }
echo "iPhone: $IPHONE  ($IPHONE_ID)"
echo "iPad:   $IPAD  ($IPAD_ID)"

echo "== building for the simulator =="
xcodebuild -project "$PROJ" -scheme "$SCHEME" \
  -sdk iphonesimulator -configuration Debug \
  -destination "id=$IPHONE_ID" \
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build >/dev/null

shot () {   # shot <device> <outdir> <file> <launch args...>
  local DEV="$1" OUT="$2" FILE="$3"; shift 3
  xcrun simctl terminate "$DEV" "$BID" >/dev/null 2>&1 || true
  xcrun simctl launch "$DEV" "$BID" --seed-sample "$@" >/dev/null
  sleep 4
  xcrun simctl io "$DEV" screenshot "$OUT/$FILE" >/dev/null 2>&1
  echo "   $OUT/$FILE"
}

capture_device () {
  local DEV="$1" OUT="$2"
  mkdir -p "$OUT"
  xcrun simctl boot "$DEV" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$DEV" -b >/dev/null
  # A clean, consistent marketing status bar — 9:41, full bars, charged.
  xcrun simctl status_bar "$DEV" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 --dataNetwork wifi >/dev/null 2>&1 || true
  xcrun simctl uninstall "$DEV" "$BID" >/dev/null 2>&1 || true
  xcrun simctl install "$DEV" "$APP"

  shot "$DEV" "$OUT" "01-library.png"
  shot "$DEV" "$OUT" "02-reader.png"   --open-first
  shot "$DEV" "$OUT" "03-redact.png"   --redact
  shot "$DEV" "$OUT" "04-fill.png"     --fill
  shot "$DEV" "$OUT" "05-sign.png"     --sign
  shot "$DEV" "$OUT" "06-privacy.png"  --settings
}

echo "== iPhone =="
capture_device "$IPHONE_ID" raw
echo "== iPad =="
capture_device "$IPAD_ID" raw-ipad

# The sizes App Store Connect will accept are decided here, not at upload time.
# Its error for a wrong size talks about dimensions, which is at least honest —
# but the one for an alpha channel ALSO talks about dimensions, so an unchecked
# mismatch sends you measuring images that were correct all along.
expect_size () {  # expect_size <file> <w> <h>
  local got
  got="$(sips -g pixelWidth -g pixelHeight "$1" | awk '/pixel/ {printf "%s", $2"x"}' | sed 's/x$//')"
  if [ "$got" != "$2x$3" ]; then
    echo "   WARNING: $1 is $got, expected $2x$3"
  fi
}
for f in raw/*.png;      do expect_size "$f" 1320 2868; done
for f in raw-ipad/*.png; do expect_size "$f" 2064 2752; done

# ---- scale to the other marketing sizes -------------------------------------
# Apple accepts one iPhone and one iPad size and derives the rest, but uploading
# each explicitly avoids any resampling decision being made for us.
scale_to () {  # scale_to <src dir> <dst dir> <width> <height>
  local SRC="$1" DST="$2" W="$3" H="$4"
  # EMPTIED, not just written into. Copying over a directory leaves any file
  # whose screen no longer exists sitting there, and the staging step below
  # cheerfully copies it into UPLOAD — so a renamed or dropped screen shows up
  # as an extra slide nobody meant to ship. Caught exactly that way: a
  # 04-privacy.png from a previous run rode along beside its replacement.
  rm -rf "$DST"
  mkdir -p "$DST"
  for f in "$SRC"/*.png; do
    sips -z "$H" "$W" "$f" --out "$DST/$(basename "$f")" >/dev/null
  done
  echo "   $DST  ${W}x${H}"
}

echo "== scaling =="
rm -rf marketing-6.9 && mkdir -p marketing-6.9 && cp raw/*.png marketing-6.9/ && echo "   marketing-6.9  1320x2868 (native)"
scale_to raw      marketing-6.7        1290 2796
scale_to raw      marketing-6.5        1242 2688
rm -rf marketing-ipad-13 && mkdir -p marketing-ipad-13 && cp raw-ipad/*.png marketing-ipad-13/ && echo "   marketing-ipad-13  2064x2752 (native)"
scale_to raw-ipad marketing-ipad-12.9  2048 2732

# ---- strip the alpha channel ------------------------------------------------
# simctl screenshots are RGBA even though every pixel is fully opaque, and App
# Store Connect refuses any screenshot carrying an alpha channel. Worse, the
# error it shows for that complains about DIMENSIONS, which sends you measuring
# images that were the right size all along.
echo "== flattening (App Store Connect rejects alpha) =="
for f in marketing-*/*.png; do
  swift flatten.swift "$f"
done
echo "   done"

echo
echo "done. Upload marketing-6.9 (iPhone) and marketing-ipad-13 (iPad)."
echo "The 6.5/6.7 and ipad-12.9 sets are legacy sizes, kept only as fallbacks."

# ---- stage exactly what gets dragged into App Store Connect -----------------
# Uploading the wrong folder is the easiest mistake here: the raw-* captures are
# whatever size the window happened to be, and dropping one produces
# "The dimensions of one or more screenshots are wrong". This leaves one folder
# containing only files that match their slot.
rm -rf UPLOAD
mkdir -p UPLOAD/iPhone-6.9 UPLOAD/iPad-13
cp marketing-6.9/*.png UPLOAD/iPhone-6.9/ 2>/dev/null || true
cp marketing-ipad-13/*.png UPLOAD/iPad-13/ 2>/dev/null || true
if ls marketing-mac/*.png >/dev/null 2>&1; then
  mkdir -p UPLOAD/Mac && cp marketing-mac/*.png UPLOAD/Mac/
fi
echo "Staged in UPLOAD/ — drag from there, never from raw-*/."
echo "For macOS: bash mac-shots-guide.sh (capture needs Screen Recording permission)."
