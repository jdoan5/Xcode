#!/bin/bash
#
# capture.sh - App Store screenshots of Stand Study (com.jdoan.StandStudy).
#
#   bash Screenshots/capture.sh
#
# What it does, in order:
#   1. finds the simulators: a 6.3-inch iPhone (an iPhone NN Pro), a 6.9-inch iPhone (Pro Max),
#      a 13-inch iPad Pro and, when one is installed, an iPhone Duo (iOS 27.1). Simulators named
#      "... (Stand Study)" win, then the newest runtime. Override with IPHONE_MEDIUM_UDID /
#      IPHONE_UDID / IPAD_UDID / DUO_UDID; the value none skips that simulator and keeps its raw
#      folder from an earlier run;
#   2. builds a Debug app for the simulator (unsigned, its own derived data in a temp folder).
#      Debug, because every screen is reached by a DEBUG launch argument (README "Launch
#      arguments"); a release build ignores them all;
#   3. prepares each simulator: 12-hour clock, light appearance, default text size, a clean
#      status bar (9:41, full battery and signal), and a fresh install, so no sets, sessions or
#      settings from an earlier run show up. The fresh install is then launched once and
#      closed, so the first shot is not taken while the app is still starting for the first time;
#   4. relaunches the app once per screen and saves a screenshot into the temp folder (the
#      simulator service cannot write into ~/Documents). A frame that is one plain colour (the
#      launch screen: the app had not drawn yet) is taken again after a longer wait, and the
#      script stops if it is still blank. frames.swift then paints over the 3x3 black mark the
#      iOS 27 iPhone simulators leave in the top-left corner. The sets are copied into
#      raw-6.3/, raw/ (6.9"), raw-ipad/ and raw-duo/ (the Duo's outer display);
#   5. makes the marketing sets from the raw folders (6.3" native, 6.9" native, 6.7" and 6.5"
#      scaled, 13" iPad native, 12.9" iPad scaled, iPhone Duo native), removes the alpha
#      channel from every one with flatten.swift, and copies the four upload sets into UPLOAD/
#      (one folder per App Store Connect slot: see the README);
#   6. checks every marketing and UPLOAD file for its size and for an alpha channel, and that
#      each UPLOAD folder holds exactly one file per screen.
#
# Settings you can override from the environment:
#   IPHONE_MEDIUM_UDID, IPHONE_UDID,   simulators to use; none skips one and keeps its raw
#   IPAD_UDID, DUO_UDID                 folder (e.g. only the 6.3": IPHONE_UDID=none IPAD_UDID=none
#                                       DUO_UDID=none)
#   CAPTURE_WORK                        folder for derived data and raw shots (default: new temp folder)
#   SETTLE                              seconds to wait after a launch before the shot (default: 6)
#   WARMUP                              seconds the first, unrecorded launch is given (default: 12)
#   KEEP_BOOTED=1                       leave simulators this script booted running afterwards
#
# The script proves sizes, the missing alpha channel and that no frame is blank, not content:
# open every file in UPLOAD/ before dragging it into App Store Connect.

set -euo pipefail

BUNDLE_ID="com.jdoan.StandStudy"
SETTLE="${SETTLE:-6}"
WARMUP="${WARMUP:-12}"

# Upload order, strongest first: "file name|launch arguments". The same screens on iPhone, iPad
# and Duo, each laid out the way that device really lays it out (no forced -pose).
#   01 the player on the Sample set's Degas dancer, paused at 0:42 on pose 3 of a Gesture plan
#   02 the same pose with three-value notan and the thirds grid
#   03 Draw: the Sample set chosen, the plan presets, Start
#   04 Library > Sample set: the 28 bundled public-domain works (credits below on iPad)
#   05 Log > the Class session from the example log: every pose with its reference
#   06 Settings: cues and the default view aids with their preview
# Compare is left out on purpose: there is no real photo of a drawing to show in it.
SHOTS=(
    "01-player|-demo-player"
    "02-notan-grid|-demo-player -demo-aids notan3,grid"
    "03-draw|-tab draw"
    "04-sample-set|-open sample-set"
    "05-session|-demo-log -open session"
    "06-settings|-tab settings"
)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORK="${CAPTURE_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/standstudy-capture.XXXXXX")}"
DERIVED="$WORK/DerivedData"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/StandStudy.app"
FLATTEN="$WORK/flatten"
FRAMES="$WORK/frames"

say() { printf '\n== %s\n' "$*"; }
fail() { printf '\ncapture.sh: %s\n' "$*" >&2; exit 1; }

# simctl can hang when a simulator stops drawing; every call gets a deadline so the script
# stops with a reason instead of waiting forever. perl's alarm survives exec.
within() {
    local seconds="$1"; shift
    perl -e 'alarm shift; exec @ARGV or die "cannot run $ARGV[0]\n"' "$seconds" "$@"
}

stuck() {
    cat >&2 <<EOF

capture.sh: the simulator stopped responding during "$1".
  Show its screen (Simulator.app or Xcode's device window) and run the script again. If it
  still hangs: xcrun simctl shutdown <udid>, or restart the Mac to restart CoreSimulatorService.
EOF
    exit 3
}

# --- 1. Simulators -------------------------------------------------------------------------

# pick <device type pattern> [minimum iOS version]: a UDID or nothing. The lineup changes every
# autumn, so the device type is matched loosely; a simulator made for this app wins, then the
# newest runtime (a name alone can exist on several runtimes).
pick() {
    xcrun simctl list devices available -j | python3 -c '
import json, re, sys
pattern, minimum = sys.argv[1], tuple(int(p) for p in sys.argv[2].split("."))
best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m: continue
    version = (int(m.group(1)), int(m.group(2)))
    if version < minimum: continue
    for d in devices:
        if not d.get("isAvailable") or not re.search(pattern, d["deviceTypeIdentifier"]): continue
        key = ("(Stand Study)" in d["name"], version)
        if best is None or key > best[0]: best = (key, d["udid"])
print(best[1] if best else "")
' "$1" "${2:-0.0}"
}

describe() {  # describe <udid>: "name (runtime) state", or nothing
    xcrun simctl list devices -j | python3 -c '
import json, sys
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["udid"] == sys.argv[1]:
            print("%s (%s) %s" % (d["name"], runtime.rsplit(".", 1)[-1], d["state"])); raise SystemExit
' "$1"
}

# The 6.3-inch iPhone fills App Store Connect's one required iPhone slot, "iPhone with Dynamic
# Island (medium display)" (1206x2622). The 6.9-inch Pro Max fills the large-display slot.
IPHONE_MEDIUM="${IPHONE_MEDIUM_UDID:-$(pick 'iPhone-[0-9]+-Pro$')}"
IPHONE="${IPHONE_UDID:-$(pick 'iPhone-[0-9]+-Pro-Max')}"
IPAD="${IPAD_UDID:-$(pick 'iPad-Pro-13-inch')}"
DUO="${DUO_UDID:-$(pick 'iPhone-Duo' 27.1)}"
# none: that simulator is skipped and its raw folder from an earlier run is used as it is.
SKIPPED=""
for var in IPHONE_MEDIUM IPHONE IPAD DUO; do
    if [[ "${!var}" == none ]]; then
        printf -v "$var" '%s' ""
        SKIPPED="$SKIPPED $var"
    fi
done
skipped() { [[ " $SKIPPED " == *" $1 "* ]]; }
[[ -n "$IPHONE_MEDIUM" ]] || skipped IPHONE_MEDIUM \
    || fail "no 6.3-inch iPhone simulator (an iPhone NN Pro); set IPHONE_MEDIUM_UDID"
[[ -n "$IPHONE" ]] || skipped IPHONE || fail "no 6.9-inch iPhone simulator (Pro Max); set IPHONE_UDID"
[[ -n "$IPAD" ]] || skipped IPAD || fail "no 13-inch iPad Pro simulator; set IPAD_UDID"
say "Simulators"
for udid in $IPHONE_MEDIUM $IPHONE $IPAD $DUO; do
    line="$(describe "$udid")"
    [[ -n "$line" ]] || fail "no simulator with UDID $udid (xcrun simctl list devices)"
    echo "   $udid  $line"
done
[[ -n "$IPHONE_MEDIUM" ]] || echo "   6.3-inch iPhone skipped: raw-6.3/ is used as it is"
[[ -n "$IPHONE" ]] || echo "   6.9-inch iPhone skipped: raw/ is used as it is"
[[ -n "$IPAD" ]] || echo "   iPad skipped: raw-ipad/ is used as it is"
[[ -n "$DUO" ]] || echo "   no iPhone Duo simulator: raw-duo/ is used as it is"

# --- 2. Build ------------------------------------------------------------------------------

say "Building Debug for the simulator (log: $WORK/build.log)"
mkdir -p "$WORK"
if ! xcodebuild -project "$PROJECT_DIR/StandStudy.xcodeproj" -scheme StandStudy \
        -sdk iphonesimulator -configuration Debug -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "$DERIVED" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
        build > "$WORK/build.log" 2>&1; then
    tail -30 "$WORK/build.log" >&2
    fail "build failed"
fi
[[ -d "$APP" ]] || fail "built app not found at $APP"

# Compiled once instead of interpreted for every file.
xcrun swiftc -O "$SCRIPT_DIR/flatten.swift" -o "$FLATTEN" || fail "flatten.swift did not compile"
xcrun swiftc -O "$SCRIPT_DIR/frames.swift" -o "$FRAMES" || fail "frames.swift did not compile"

# --- 3. Prepare a simulator ----------------------------------------------------------------

BOOTED_HERE=""
CAPTURED=""  # the raw sets this run took, as opposed to ones kept from an earlier run

cleanup() {
    for udid in $BOOTED_HERE; do
        [[ "${KEEP_BOOTED:-0}" == 1 ]] && break
        within 60 xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    done
}
trap cleanup EXIT

boot() {  # boot <udid>: boots (if needed) and waits until the screen draws
    local udid="$1" ready=0
    if [[ "$(describe "$udid")" != *Booted* ]]; then
        within 120 xcrun simctl boot "$udid" || stuck "booting $udid"
        [[ " $BOOTED_HERE " == *" $udid "* ]] || BOOTED_HERE="$BOOTED_HERE $udid"
    fi
    within 300 xcrun simctl bootstatus "$udid" -b >/dev/null || stuck "waiting for $udid to boot"
    # bootstatus can return while the boot spinner is still up; two screenshots in a row
    # that succeed mean the home screen is drawing.
    for _ in $(seq 1 30); do
        if within 15 xcrun simctl io "$udid" screenshot --type=png "$WORK/probe.png" >/dev/null 2>&1; then
            ready=$((ready + 1))
            [[ $ready -ge 2 ]] && return 0
        else
            ready=0
        fi
        sleep 3
    done
    stuck "waiting for the home screen on $udid"
}

is_ipad() {  # is_ipad <udid>: true for an iPad simulator
    xcrun simctl list devices -j | python3 -c '
import json, sys
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["udid"] == sys.argv[1]:
            raise SystemExit(0 if "iPad" in d["deviceTypeIdentifier"] else 1)
raise SystemExit(1)
' "$1"
}

prepare() {  # prepare <udid>
    local udid="$1" restart=0
    boot "$udid"
    # A simulator copies the Mac's 24-hour setting, which turned the status bar into 09:41 and
    # the log's times into 18:30. The listing is US English, so the clock is 12-hour. The
    # status bar only reads it at startup, hence the restart when it had to change.
    if [[ "$(xcrun simctl spawn "$udid" defaults read -g AppleICUForce24HourTime 2>/dev/null || true)" != 0 ]]; then
        echo "   switching $udid to a 12-hour clock (restarts it)"
        xcrun simctl spawn "$udid" defaults write -g AppleICUForce24HourTime -bool false
        restart=1
    fi
    # iPadOS starts a new simulator in Windowed Apps mode: every capture then has a window
    # resize grabber in the bottom-right corner and the app's name beside the date in the
    # status bar. Full Screen Apps (Settings > Multitasking & Gestures) is Windowed Apps and
    # Stage Manager both off; SpringBoard reads them at startup.
    if is_ipad "$udid"; then
        local key
        for key in SBMedusaMultitaskingEnabled SBChamoisWindowingEnabled; do
            if [[ "$(xcrun simctl spawn "$udid" defaults read com.apple.springboard "$key" 2>/dev/null || true)" != 0 ]]; then
                echo "   switching $udid to Full Screen Apps ($key off; restarts it)"
                xcrun simctl spawn "$udid" defaults write com.apple.springboard "$key" -bool false
                restart=1
            fi
        done
    fi
    if [[ $restart == 1 ]]; then
        within 120 xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
        boot "$udid"
    fi
    within 20 xcrun simctl ui "$udid" appearance light || stuck "setting light appearance"
    # Large is the default text size. A simulator left at an accessibility size breaks every
    # line of every shot, and nothing below would notice.
    within 20 xcrun simctl ui "$udid" content_size large || stuck "setting the text size"
    within 20 xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged \
        --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi >/dev/null 2>&1 \
        || echo "   (this simulator does not take a status bar override)"
    # Uninstalling deletes the app's store, files and settings: Draw opens on its defaults
    # (Sample set, Gesture), Library has no sets of its own, Settings shows the default cues.
    within 60 xcrun simctl uninstall "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    within 120 xcrun simctl install "$udid" "$APP" || stuck "installing the app"
    # The first launch of a fresh install (more so straight after a restart) creates the store
    # and the caches and can take longer than SETTLE; until it draws, a capture is the plain
    # white launch screen. One unrecorded launch gets that out of the way.
    within 60 xcrun simctl launch "$udid" "$BUNDLE_ID" -tab draw >/dev/null || stuck "launching the app the first time"
    sleep "$WARMUP"
    within 30 xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

# --- 4. Shots ------------------------------------------------------------------------------

capture() {  # capture <udid> <set name> [simctl io screenshot options]
    local udid="$1" set="$2"; shift 2
    local entry name args
    mkdir -p "$WORK/$set"
    rm -f "$WORK/$set"/*.png
    for entry in "${SHOTS[@]}"; do
        name="${entry%%|*}.png"
        read -r -a args <<< "${entry#*|}"
        within 30 xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
        within 60 xcrun simctl launch "$udid" "$BUNDLE_ID" "${args[@]}" >/dev/null \
            || stuck "launching the app for $name"
        # Covers the launch, the pushed screen and the thumbnails, which load off the main thread.
        sleep "$SETTLE"
        within 30 xcrun simctl io "$udid" screenshot "$@" --type=png "$WORK/$set/$name" >/dev/null 2>&1 \
            || stuck "taking $set/$name"
        # A frame that is all one colour is the launch screen: the app had not drawn yet.
        if ! "$FRAMES" blank "$WORK/$set/$name" >/dev/null; then
            echo "   $set/$name was blank; waiting and taking it again"
            sleep "$WARMUP"
            within 30 xcrun simctl io "$udid" screenshot "$@" --type=png "$WORK/$set/$name" >/dev/null 2>&1 \
                || stuck "taking $set/$name"
            "$FRAMES" blank "$WORK/$set/$name" >/dev/null \
                || fail "$set/$name is still blank (one plain colour) after $((SETTLE + WARMUP)) s"
        fi
        echo "   $set/$name  $(size_of "$WORK/$set/$name")"
    done
    within 30 xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    # The iOS 27 iPhone simulators leave a 3x3 black square in the top-left corner of every
    # capture; it is not the app's. Files without it are left untouched.
    "$FRAMES" corner "$WORK/$set"/*.png >/dev/null || fail "could not clean the corner of $set"
    CAPTURED="$CAPTURED $set"
}

size_of() { sips -g pixelWidth -g pixelHeight "$1" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}'; }

if [[ -n "$IPHONE_MEDIUM" ]]; then
    say "iPhone 6.3-inch"
    prepare "$IPHONE_MEDIUM"
    capture "$IPHONE_MEDIUM" raw-6.3
fi
if [[ -n "$IPHONE" ]]; then
    say "iPhone 6.9-inch"
    prepare "$IPHONE"
    capture "$IPHONE" raw
fi
if [[ -n "$IPAD" ]]; then
    say "iPad"
    prepare "$IPAD"
    capture "$IPAD" raw-ipad
fi
if [[ -n "$DUO" ]]; then
    say "iPhone Duo (outer display)"
    prepare "$DUO"
    # Display 1 is the outer display. Closed, the Duo shows the app there; the inner display
    # stays black and is not captured.
    capture "$DUO" raw-duo --display=1
fi

# --- 5. Copy, scale, flatten ---------------------------------------------------------------

say "Copying the sets into $SCRIPT_DIR"
cd "$SCRIPT_DIR"
# Every captured folder is replaced wholesale, so a renamed or dropped screen cannot linger and
# be uploaded. A skipped simulator's folder is kept, and must hold every screen in SHOTS.
for set in raw-6.3 raw raw-ipad raw-duo; do
    if [[ " $CAPTURED " == *" $set "* ]]; then
        rm -rf "$set"; mkdir -p "$set"; cp "$WORK/$set"/*.png "$set/"
    fi
    for entry in "${SHOTS[@]}"; do
        [[ -f "$set/${entry%%|*}.png" ]] \
            || fail "$set/${entry%%|*}.png is missing; capture that simulator instead of skipping it"
    done
done

MARKETING="marketing-6.3 marketing-6.9 marketing-6.7 marketing-6.5 marketing-ipad-13 marketing-ipad-12.9 marketing-duo"
# Rebuilt from the raw folders every run, so they always match them.
for set in $MARKETING; do
    rm -rf "$set"; mkdir -p "$set"
done

# fit <source> <dest> <width> <height>: a copy when the capture already has that size, a sips
# scale when only the aspect ratio matches. Anything else would stretch the screen: stop.
fit() {
    local src="$1" dest="$2" width="$3" height="$4" size w h
    size="$(size_of "$src")"; w="${size%x*}"; h="${size#*x}"
    if [[ "$size" == "${width}x${height}" ]]; then
        cp "$src" "$dest"
    elif (( w * height == h * width )); then
        sips -z "$height" "$width" "$src" --out "$dest" >/dev/null
    else
        fail "$src is $size, which does not have the aspect ratio of ${width}x${height}"
    fi
}

# Only the screens in SHOTS, so nothing else that happens to sit in a raw folder is uploaded.
for entry in "${SHOTS[@]}"; do
    name="${entry%%|*}.png"
    fit "raw-6.3/$name" "marketing-6.3/$name" 1206 2622
    fit "raw/$name" "marketing-6.9/$name" 1320 2868
    # 6.7" and 6.5" are not quite the 6.9" shape; scaling squeezes them by under half a
    # percent, which is how these slots have always been filled from a 6.9" capture.
    sips -z 2796 1290 "raw/$name" --out "marketing-6.7/$name" >/dev/null
    sips -z 2688 1242 "raw/$name" --out "marketing-6.5/$name" >/dev/null
    fit "raw-ipad/$name" "marketing-ipad-13/$name" 2064 2752
    # The 12.9" slot is a hair narrower than 3:4; the same small squeeze as the phones above.
    sips -z 2732 2048 "raw-ipad/$name" --out "marketing-ipad-12.9/$name" >/dev/null
    # The Duo slot takes the outer display at 1398x2034, the size it is captured at.
    fit "raw-duo/$name" "marketing-duo/$name" 1398 2034
done

say "Removing the alpha channel"
# App Store Connect rejects a screenshot with an alpha channel and calls it a size problem.
# sips --setProperty hasAlpha false only changes a flag; flatten.swift redraws the pixels.
for file in marketing-*/*.png; do
    "$FLATTEN" "$file" >/dev/null || fail "could not flatten $file"
done
echo "   $(ls marketing-*/*.png | wc -l | tr -d ' ') files"

# One folder per App Store Connect slot (README, "Which folder goes where"). Only the folders
# this script fills are replaced, plus UPLOAD/iPhone-6.9 from before the slots were renamed;
# anything else in UPLOAD/ is left alone.
UPLOADS="iPhone-medium-6.3:marketing-6.3 iPhone-large-6.9:marketing-6.9 iPhone-Duo:marketing-duo iPad-13:marketing-ipad-13"
rm -rf UPLOAD/iPhone-6.9
for pair in $UPLOADS; do
    rm -rf "UPLOAD/${pair%%:*}"; mkdir -p "UPLOAD/${pair%%:*}"
    cp "${pair#*:}"/*.png "UPLOAD/${pair%%:*}/"
done

# --- 6. Check ------------------------------------------------------------------------------

say "Checking"
bad=0
for file in marketing-*/*.png UPLOAD/*/*.png; do
    case "$file" in
        marketing-6.3/*|UPLOAD/iPhone-medium-6.3/*) want=1206x2622 ;;
        marketing-6.9/*|UPLOAD/iPhone-large-6.9/*) want=1320x2868 ;;
        marketing-6.7/*) want=1290x2796 ;;
        marketing-6.5/*) want=1242x2688 ;;
        marketing-ipad-13/*|UPLOAD/iPad-13/*) want=2064x2752 ;;
        marketing-ipad-12.9/*) want=2048x2732 ;;
        marketing-duo/*|UPLOAD/iPhone-Duo/*) want=1398x2034 ;;
        *) continue ;;
    esac
    size="$(size_of "$file")"
    alpha="$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')"
    status=ok
    [[ "$size" == "$want" ]] || { status="WRONG SIZE (want $want)"; bad=1; }
    [[ "$alpha" == no ]] || { status="HAS ALPHA"; bad=1; }
    printf '   %-40s %-10s alpha %-4s %s\n' "$file" "$size" "$alpha" "$status"
done
for pair in $UPLOADS; do
    folder="UPLOAD/${pair%%:*}"
    count="$(ls "$folder"/*.png | wc -l | tr -d ' ')"
    if [[ "$count" != "${#SHOTS[@]}" ]]; then
        printf '   %-40s %s files, want %s\n' "$folder" "$count" "${#SHOTS[@]}"; bad=1
    fi
done
[[ $bad == 0 ]] || fail "some screenshots would be rejected by App Store Connect"

say "Done. Drag from UPLOAD/ (never raw*/), after opening every file to check what it shows."
