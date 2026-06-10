# Screenshots

App Store Connect screenshot sets for Job Trail.

```
raw/             native captures from iPhone 17 Pro Max (1320×2868)
marketing-6.9/   6.9" — 1320×2868  (iPhone 17/16 Pro Max)   ← required slot
marketing-6.7/   6.7" — 1290×2796  (scaled from 6.9)
marketing-6.5/   6.5" — 1242×2688  (scaled from 6.9)
```

Four screens, numbered for upload order: `01-list`, `02-detail`, `03-add`, `04-filter`.

> A single 6.9" set satisfies App Store Connect for iPhone; the 6.5"/6.7" folders are provided for completeness and were scaled from the 6.9" capture.

## Recapture (automated)

These were captured headlessly on the **DEBUG** build. The app reads two launch
environment variables (see `applyUITestHooks()` in `ContentView.swift`, compiled
only under `#if DEBUG`):

- `UITEST_SEED=1` — wipe and seed deterministic sample jobs (from `SampleData.swift`).
- `UITEST_SCREEN=detail|add|filter` — open a specific screen on launch
  (omit for the plain list).

Neither variable can be set on a real App Store launch, so production behavior is
unaffected.

```bash
DEV="iPhone 17 Pro Max"; BID="com.jdoan.JobTracker"
xcodebuild -project JobTracker.xcodeproj -scheme JobTracker \
  -sdk iphonesimulator -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEV" \
  -derivedDataPath /tmp/jobtrail CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "$DEV"; xcrun simctl bootstatus "$DEV" -b
# clean status bar for marketing shots
xcrun simctl status_bar "$DEV" override --time "9:41" \
  --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
xcrun simctl install "$DEV" "/tmp/jobtrail/Build/Products/Debug-iphonesimulator/Job Tracker.app"
for s in :01-list detail:02-detail add:03-add filter:04-filter; do
  SIMCTL_CHILD_UITEST_SEED=1 SIMCTL_CHILD_UITEST_SCREEN="${s%%:*}" \
    xcrun simctl launch --terminate-running-process "$DEV" "$BID"
  sleep 5
  xcrun simctl io "$DEV" screenshot "raw/${s##*:}.png"
done
# scale marketing sets
for f in raw/*.png; do b=$(basename "$f"); cp "$f" "marketing-6.9/$b"
  sips -z 2796 1290 "$f" --out "marketing-6.7/$b"
  sips -z 2688 1242 "$f" --out "marketing-6.5/$b"; done
```

## Note on content

The sample jobs are fictitious example companies (Lumen Labs, Brightwave, Cobalt
Systems, etc.) seeded only for these captures. Real user data never appears.
