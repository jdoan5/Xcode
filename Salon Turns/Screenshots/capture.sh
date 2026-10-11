#!/bin/bash
#
# capture.sh - App Store screenshots of Salon Turns on the 13-inch iPad simulator.
#
#   Screenshots/capture.sh
#
# What it does, in order:
#   1. builds a Release app for the simulator (unsigned, its own derived data folder);
#   2. finds the iPad 13-inch simulator by UDID and boots it if needed;
#   3. sets light appearance and a tidy status bar;
#   4. for each screen, relaunches the app with `--seed-sample --screen <name>`, so every
#      shot shows the same sample Saturday, and saves a screenshot to a temporary folder;
#   5. copies them into Screenshots/raw-ipad/ (as captured), marketing-ipad-13/ (flattened:
#      no alpha channel) and marketing-ipad-12.9/ (scaled to 2048x2732, flattened) - the same
#      layout as the developer's other apps;
#   6. checks every file is 2064x2752 (or 2752x2064) with no alpha.
#
# Settings you can override from the environment:
#   SIM_UDID       simulator to use (default: the iPad Pro 13-inch below)
#   CAPTURE_WORK   folder for derived data and raw shots (default: a new temp folder)
#   SETTLE         seconds to wait after launch before the shot (default: 5)
#   KEEP_BOOTED=1  leave the simulator running afterwards
#
# Look at every PNG before uploading: this script proves the size and the missing alpha,
# not that the screen shows what you expect.

set -euo pipefail

SIM_UDID="${SIM_UDID:-0F5857FD-2AB8-40AA-9B74-B90319E984C5}"
SETTLE="${SETTLE:-5}"
BUNDLE_ID="com.jdoan.SalonTurns"
# Every screen the app can open on. Board first: it is the one that explains the app.
SCREENS=(board tally log team settings)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RAW_OUT="$SCRIPT_DIR/raw-ipad"
OUT_DIR="$SCRIPT_DIR/marketing-ipad-13"
OUT_129="$SCRIPT_DIR/marketing-ipad-12.9"
WORK="${CAPTURE_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/salonturns-capture.XXXXXX")}"
DERIVED="$WORK/DerivedData"
RAW="$WORK/raw"
APP="$DERIVED/Build/Products/Release-iphonesimulator/SalonTurns.app"

say() { printf '\n== %s\n' "$*"; }
fail() { printf '\ncapture.sh: %s\n' "$*" >&2; exit 1; }

# simctl can block forever when the simulator stops drawing (seen on this Mac with
# Xcode 27: an app launch never returns and every later simctl call waits behind it).
# Each call gets a deadline so the script stops with a reason instead of hanging.
# perl's alarm survives exec, so the command itself is killed when time runs out.
within() {
    local seconds="$1"; shift
    perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]\n"' "$seconds" "$@"
}

display_stuck() {
    cat >&2 <<EOF

capture.sh: the simulator stopped responding during "$1".
  When this was first seen, launching Apple's own Settings app in the same simulator hung
  the same way, so the cause is the simulator rather than Salon Turns. Things to try,
  then run the script again:
    - show the simulator's screen in a window (Simulator or Xcode's device window);
    - xcrun simctl shutdown $SIM_UDID ; xcrun simctl erase $SIM_UDID   (erases that simulator)
    - restart the Mac, which restarts CoreSimulatorService.
EOF
    exit 3
}

# --- 1. Simulator --------------------------------------------------------------------------

say "Simulator $SIM_UDID"
device_line="$(xcrun simctl list devices | grep -F "($SIM_UDID)" || true)"
[[ -n "$device_line" ]] || fail "no simulator with UDID $SIM_UDID (xcrun simctl list devices)"
echo "$device_line"
[[ "$device_line" == *"iPad"*"13-inch"* ]] || fail "$SIM_UDID is not a 13-inch iPad"

# --- 2. Build ------------------------------------------------------------------------------

say "Building Release for the simulator (log: $WORK/build.log)"
mkdir -p "$WORK" "$RAW"
if ! xcodebuild -project "$PROJECT_DIR/SalonTurns.xcodeproj" -scheme SalonTurns \
        -sdk iphonesimulator -destination "id=$SIM_UDID" -configuration Release \
        -derivedDataPath "$DERIVED" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
        build > "$WORK/build.log" 2>&1; then
    tail -30 "$WORK/build.log" >&2
    fail "build failed"
fi
grep -q '\*\* BUILD SUCCEEDED \*\*' "$WORK/build.log" || fail "build did not report success"
[[ -d "$APP" ]] || fail "built app not found at $APP"

# The flattener is compiled once instead of interpreted per file.
xcrun swiftc -O "$SCRIPT_DIR/flatten.swift" -o "$WORK/flatten" || fail "flatten.swift did not compile"

# --- 3. Boot and prepare -------------------------------------------------------------------

# Always start from a fresh boot. If another app was in front (even Apple's Settings), iOS adds
# a "< Settings" back link to the status bar of the first screenshot.
if [[ "$device_line" == *"(Booted)"* ]]; then
    say "Rebooting the simulator for a clean home screen"
    within 60 xcrun simctl shutdown "$SIM_UDID" >/dev/null 2>&1 || true
fi
say "Booting"
xcrun simctl boot "$SIM_UDID"
booted_here=1

cleanup() {
    within 20 xcrun simctl status_bar "$SIM_UDID" clear >/dev/null 2>&1 || true
    if [[ "$booted_here" == 1 && "${KEEP_BOOTED:-0}" != 1 ]]; then
        within 60 xcrun simctl shutdown "$SIM_UDID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

within 300 xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null || fail "the simulator did not finish booting"
# bootstatus can return while the screen still shows the boot spinner; a screenshot that
# succeeds twice in a row means the home screen is drawing.
ready=0
for _ in $(seq 1 30); do
    if within 15 xcrun simctl io "$SIM_UDID" screenshot --type=png "$WORK/probe.png" >/dev/null 2>&1; then
        ready=$((ready + 1))
        [[ $ready -ge 2 ]] && break
    else
        ready=0
    fi
    sleep 4
done
[[ $ready -ge 2 ]] || display_stuck "waiting for the home screen"

within 20 xcrun simctl ui "$SIM_UDID" appearance light || display_stuck "setting light appearance"
# Full battery and signal, and a clock just after the sample's last entry. The sample day
# (SampleDay.swift) opens at 9:00 and its last entry is at 12:12 - unless it is captured before
# about 12:17, when it is shifted to end just before now. Neither a fixed 9:41 nor an afternoon
# clock fits next to entries ending at 12:12.
if [[ "$(date +%H%M)" -ge 1217 ]]; then clock="12:15"; else clock="$(date +%H:%M)"; fi
within 20 xcrun simctl status_bar "$SIM_UDID" override --time "$clock" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --batteryState charged --batteryLevel 100 || display_stuck "setting the status bar"

say "Installing"
within 120 xcrun simctl install "$SIM_UDID" "$APP" || display_stuck "installing the app"

# --- 4. Shots ------------------------------------------------------------------------------

index=0
shots=()
for screen in "${SCREENS[@]}"; do
    index=$((index + 1))
    name="$(printf '%02d-%s.png' "$index" "$screen")"
    say "$name"
    within 30 xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    # --seed-sample replaces today with the sample Saturday on every launch, so each shot
    # starts from the same day with nothing half-done on screen.
    within 60 xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" --seed-sample --screen "$screen" \
        || display_stuck "launching the app on $screen"
    # Long enough for the launch transition and the tab's first layout to finish.
    sleep "$SETTLE"
    within 30 xcrun simctl io "$SIM_UDID" screenshot --type=png "$RAW/$name" >/dev/null \
        || display_stuck "taking the $screen screenshot"
    shots+=("$name")
done
within 30 xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

# --- 5. Copy and flatten -------------------------------------------------------------------

say "Copying to raw-ipad/, marketing-ipad-13/ and marketing-ipad-12.9/, removing alpha"
mkdir -p "$RAW_OUT" "$OUT_DIR" "$OUT_129"
# Replace each folder's set wholesale, so a renamed or dropped screen cannot linger and be uploaded.
rm -f "$RAW_OUT"/*.png "$OUT_DIR"/*.png "$OUT_129"/*.png
for name in "${shots[@]}"; do
    cp "$RAW/$name" "$RAW_OUT/$name"
    cp "$RAW/$name" "$OUT_DIR/$name"
    "$WORK/flatten" "$OUT_DIR/$name"
    # 12.9-inch set: same shot scaled to 2048x2732 (or 2732x2048 if captured in landscape).
    w="$(sips -g pixelWidth "$RAW/$name" | awk '/pixelWidth/ {print $2}')"
    h="$(sips -g pixelHeight "$RAW/$name" | awk '/pixelHeight/ {print $2}')"
    if (( w > h )); then sips -z 2048 2732 "$RAW/$name" --out "$OUT_129/$name" >/dev/null
    else sips -z 2732 2048 "$RAW/$name" --out "$OUT_129/$name" >/dev/null; fi
    "$WORK/flatten" "$OUT_129/$name"
done

# --- 6. Check ------------------------------------------------------------------------------

say "Checking"
bad=0
for file in "$OUT_DIR"/*.png "$OUT_129"/*.png; do
    name="${file#$SCRIPT_DIR/}"
    width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')"
    height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')"
    alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')"
    status="ok"
    case "${width}x${height}" in
        2064x2752|2752x2064|2048x2732|2732x2048) ;;  # 13-inch and 12.9-inch, either orientation
        *) status="WRONG SIZE"; bad=1 ;;
    esac
    if [[ "$alpha" != "no" ]]; then
        status="HAS ALPHA"; bad=1
    fi
    printf '  %-38s %sx%s  hasAlpha %-3s  %s\n' "$name" "$width" "$height" "$alpha" "$status"
done
[[ $bad == 0 ]] || fail "some screenshots would be rejected by App Store Connect"

say "Done. Open each file in marketing-ipad-13/ and check it shows the sample day before uploading."
