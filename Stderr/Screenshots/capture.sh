#!/bin/bash
# App Store screenshot capture for Stderr.
# Every screen is reached by a DEBUG launch argument, so a re-shoot after a copy
# change reproduces the same framing instead of a different scroll offset.
set -euo pipefail
cd "$(dirname "$0")"

PROJ="../Stderr.xcodeproj"; SCHEME="Stderr"; BID="com.jdoan.CodeRef"
DD="/tmp/stderr-shots"
APP="$DD/Build/Products/Debug-iphonesimulator/Stderr.app"
# Discovered, not hardcoded. The simulator line-up moves every autumn, and a
# hardcoded "iPhone 17 Pro Max" fails the whole script a year later. Returns a
# UDID from the NEWEST runtime, because a name can exist on several runtimes and
# xcodebuild will not always resolve the one you meant.
pick () {
  xcrun simctl list devices available -j | python3 -c "
import json,sys
want='$1'
best=None
for rt, ds in sorted(json.load(sys.stdin)['devices'].items()):
    if 'iOS' not in rt: continue
    for x in ds:
        if x.get('isAvailable') and want in x['name']:
            best = (rt, x['udid'], x['name'])
print(best[1] if best else '')
"
}
name_of () { xcrun simctl list devices available -j | python3 -c "
import json,sys
for rt,ds in json.load(sys.stdin)['devices'].items():
    for x in ds:
        if x['udid']=='$1': print(x['name']); raise SystemExit
"; }
IPHONE="$(pick 'Pro Max')"
IPAD="$(pick 'iPad Pro 13')"
[ -n "$IPHONE" ] && [ -n "$IPAD" ] || { echo "no suitable simulators installed"; exit 1; }
echo "   iPhone: $(name_of "$IPHONE")"
echo "   iPad:   $(name_of "$IPAD")"

echo "== building =="
xcodebuild -project "$PROJ" -scheme "$SCHEME" -sdk iphonesimulator -configuration Debug \
  -destination "id=$IPHONE" -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO build >/dev/null

shot () {  # shot <device> <outdir> <file> <args...>
  local DEV="$1" OUT="$2" FILE="$3"; shift 3
  xcrun simctl terminate "$DEV" "$BID" >/dev/null 2>&1 || true
  xcrun simctl launch "$DEV" "$BID" "$@" >/dev/null
  sleep 4
  xcrun simctl io "$DEV" screenshot "$OUT/$FILE" >/dev/null 2>&1
  echo "   $OUT/$FILE"
}

capture () {
  local DEV="$1" OUT="$2"; mkdir -p "$OUT"
  xcrun simctl boot "$DEV" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$DEV" -b >/dev/null
  xcrun simctl status_bar "$DEV" override --time "9:41" --batteryState charged \
    --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi >/dev/null 2>&1 || true
  xcrun simctl uninstall "$DEV" "$BID" >/dev/null 2>&1 || true
  xcrun simctl install "$DEV" "$APP"
  shot "$DEV" "$OUT" "01-wall.png"
  shot "$DEV" "$OUT" "02-trap.png"    --trap java.casting.q1
  shot "$DEV" "$OUT" "03-refused.png" --refused
  shot "$DEV" "$OUT" "04-search.png"  --search "cannot find symbol"
}

echo "== iPhone =="; capture "$IPHONE" raw
echo "== iPad ==";   capture "$IPAD"   raw-ipad

scale () { mkdir -p "$2"; for f in "$1"/*.png; do sips -z "$4" "$3" "$f" --out "$2/$(basename "$f")" >/dev/null; done; echo "   $2  $3x$4"; }
echo "== scaling =="
mkdir -p marketing-6.9 && cp raw/*.png marketing-6.9/ && echo "   marketing-6.9  1320x2868 (native)"
scale raw marketing-6.7 1290 2796
scale raw marketing-6.5 1242 2688
mkdir -p marketing-ipad-13 && cp raw-ipad/*.png marketing-ipad-13/ && echo "   marketing-ipad-13  2064x2752 (native)"
scale raw-ipad marketing-ipad-12.9 2048 2732

# App Store Connect rejects any screenshot with an alpha channel, and the error
# it shows for that talks about DIMENSIONS, which sends you measuring images that
# were the right size all along.
echo "== flattening =="
for f in marketing-*/*.png; do swift flatten.swift "$f"; done
echo "   done"

rm -rf UPLOAD; mkdir -p UPLOAD/iPhone-6.9 UPLOAD/iPad-13
cp marketing-6.9/*.png UPLOAD/iPhone-6.9/; cp marketing-ipad-13/*.png UPLOAD/iPad-13/
echo
echo "Drag from UPLOAD/, never from raw-*/. The raw captures are not a valid size."
