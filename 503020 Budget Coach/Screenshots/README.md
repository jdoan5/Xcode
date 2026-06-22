# Screenshots

App Store Connect screenshot sets for Budget Coach (503020: Budget Coach).

```
raw/             native captures from iPhone 17 Pro Max (1320×2868)
marketing-6.9/   6.9" — 1320×2868  (iPhone 17/16 Pro Max)   ← required slot
marketing-6.7/   6.7" — 1290×2796  (scaled from 6.9)
marketing-6.5/   6.5" — 1242×2688  (scaled from 6.9)
```

Four screens, numbered for upload order: `01-budget`, `02-coach`, `03-history`, `04-settings`.

> A single 6.9" set satisfies App Store Connect for iPhone; the 6.5"/6.7" folders are
> provided for completeness and were scaled from the 6.9" capture.

## Recapture (automated)

The app reads plain launch **arguments** (parsed in `applyLaunchArgs()` in `ContentView.swift`,
plus the `--autocoach` hook in `CoachTab.swift`) so screens can be captured headlessly:

- `--accept-disclaimer` — skip the one-time first-run disclaimer sheet.
- `--seed-example` — fill the working budget with the example numbers (`FinanceStore.fillExample()`).
- `--seed-history` — insert four demo monthly snapshots (`SampleData.seed`). **Pass once** — it appends every launch.
- `--autocoach` — auto-run the on-device coaching when the Coach tab appears.
- `--tab-budget | --tab-coach | --tab-history | --tab-settings` — open a specific tab on launch.

These arguments are never supplied on a normal App Store launch, so production behavior is
unaffected.

```bash
DEV="iPhone 17 Pro Max"; BID="com.jdoan.FinanceCoach"
xcodebuild -project FinanceCoach.xcodeproj -scheme FinanceCoach \
  -sdk iphonesimulator -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEV" \
  -derivedDataPath /tmp/budgetcoach CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "$DEV"; xcrun simctl bootstatus "$DEV" -b
# clean status bar for marketing shots
xcrun simctl status_bar "$DEV" override --time "9:41" \
  --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
APP="/tmp/budgetcoach/Build/Products/Debug-iphonesimulator/Finance Coach.app"
xcrun simctl uninstall "$DEV" "$BID" 2>/dev/null   # start clean so history isn't duplicated
xcrun simctl install "$DEV" "$APP"

# 01 budget — seed the draft AND history here (history seeded once)
xcrun simctl launch "$DEV" "$BID" --accept-disclaimer --seed-example --seed-history --tab-budget
sleep 4; xcrun simctl io "$DEV" screenshot raw/01-budget.png

# 02 coach — on-device AI (no --seed-history so it isn't duplicated)
xcrun simctl terminate "$DEV" "$BID"
xcrun simctl launch "$DEV" "$BID" --accept-disclaimer --seed-example --tab-coach --autocoach
sleep 10; xcrun simctl io "$DEV" screenshot raw/02-coach.png   # wait for the model

# 03 history / 04 settings
for s in history:03-history settings:04-settings; do
  xcrun simctl terminate "$DEV" "$BID"
  xcrun simctl launch "$DEV" "$BID" --accept-disclaimer --tab-"${s%%:*}"
  sleep 4; xcrun simctl io "$DEV" screenshot "raw/${s##*:}.png"
done

# scale marketing sets
for f in raw/*.png; do b=$(basename "$f"); cp "$f" "marketing-6.9/$b"
  sips -z 2796 1290 "$f" --out "marketing-6.7/$b"
  sips -z 2688 1242 "$f" --out "marketing-6.5/$b"; done
```

## Note on content

The numbers shown (income $4,200, etc.) and the saved months are fictitious example data
seeded only for these captures. Real user data never appears.
