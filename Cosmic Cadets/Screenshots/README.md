# Screenshots

App Store Connect screenshot sets for Cosmic Cadets.

```
raw/             native captures from iPhone 17 Pro Max (1320×2868)
marketing-6.9/   6.9" — 1320×2868  (iPhone 17/16 Pro Max)   ← required slot
marketing-6.7/   6.7" — 1290×2796  (scaled from 6.9)
marketing-6.5/   6.5" — 1242×2688  (scaled from 6.9)
```

Five screens, numbered for upload order: `01-adventure`, `02-mission`,
`03-collection`, `04-cadets`, `05-parents`.

> A single 6.9" set satisfies App Store Connect for iPhone; the 6.5"/6.7" folders
> are provided for completeness and were scaled from the 6.9" capture.

## Recapture (automated)

Captured headlessly. The app reads launch arguments (plain `ProcessInfo`
arguments — they can't be set on a real App Store launch, so production behavior
is unaffected):

- `--seed-samples` — wipe/seed two photogenic cadets, "Mia" (22★) and "Leo" (11★),
  from `SampleData.swift`.
- `--launch-tab collection|cadets` — open a specific tab on launch.
- `--open-level N` — jump straight into level N's mission (3 = an addition mission
  that shows the count-the-objects visual).
- `--open-parentzone` / `--parent-unlocked` — open the Parent Zone, skipping the gate.

```bash
SIM="iPhone 17 Pro Max"; BID="com.jdoan.StarCadet"
APP=".../Build/Products/Debug-iphonesimulator/Cosmic Cadets.app"
xcodebuild -project StarCadet.xcodeproj -scheme StarCadet \
  -sdk iphonesimulator -configuration Debug \
  -destination "platform=iOS Simulator,name=$SIM" CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "$SIM"; xcrun simctl bootstatus "$SIM"
# clean status bar for marketing shots
xcrun simctl status_bar "$SIM" override --time "9:41" \
  --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
xcrun simctl install "$SIM" "$APP"
cap() { xcrun simctl terminate "$SIM" "$BID" 2>/dev/null; \
  xcrun simctl launch "$SIM" "$BID" "${@:2}"; sleep 3.5; \
  xcrun simctl io "$SIM" screenshot "raw/$1.png"; }
cap 01-adventure  --seed-samples
cap 02-mission    --seed-samples --open-level 3
cap 03-collection --seed-samples --launch-tab collection
cap 04-cadets     --seed-samples --launch-tab cadets
cap 05-parents    --seed-samples --open-parentzone --parent-unlocked
# scale marketing sets
for f in raw/*.png; do b=$(basename "$f"); cp "$f" "marketing-6.9/$b"
  sips -z 2796 1290 "$f" --out "marketing-6.7/$b"
  sips -z 2688 1242 "$f" --out "marketing-6.5/$b"; done
xcrun simctl status_bar "$SIM" clear
```

## Note on content

The cadets "Mia" and "Leo" and their progress are fictitious sample data seeded
only for these captures. No real user data ever appears.
