# Screenshots

App Store Connect screenshot sets for Price Trail.

```
raw/                native captures from iPhone 17 Pro Max (1320×2868)
marketing-6.9/      6.9" — 1320×2868  (iPhone 17/16 Pro Max)   ← required slot
marketing-6.7/      6.7" — 1290×2796  (scaled from 6.9)
marketing-6.5/      6.5" — 1242×2688  (scaled from 6.9)
raw-ipad/           native captures from iPad Pro 13" (2064×2752)
marketing-ipad-13/  13" iPad — 2064×2752                       ← required slot
```

Four screens, numbered for upload order: `01-list`, `02-detail` (chart +
outlook — the money shot), `03-add`, `04-settings`.

## Recapture (automated)

Captured headlessly on the **DEBUG** build. The app reads two launch
environment variables (see `applyUITestHooks()` in `RootView.swift` and the
seed hook in `PriceTrackerApp.swift`, compiled only under `#if DEBUG`):

- `UITEST_SEED=1` — wipe and seed deterministic sample products with price
  history into a throwaway temp store (`SampleData.swift`). Sample store URLs
  are example.com hosts; UI-test runs never fetch the network.
- `UITEST_SCREEN=detail|add|settings` — open a specific screen on launch
  (omit for the plain list).

Neither variable can be set on a real App Store launch.

```bash
PMAX="iPhone 17 Pro Max"; IPAD="iPad Pro 13-inch (M5)"; BID="com.jdoan.PriceTracker"
xcodebuild -project PriceTracker.xcodeproj -scheme PriceTracker \
  -sdk iphonesimulator -configuration Debug \
  -destination "platform=iOS Simulator,name=$PMAX" \
  -derivedDataPath /tmp/pricetrail CODE_SIGNING_ALLOWED=NO build
for DEV in "$PMAX" "$IPAD"; do
  xcrun simctl boot "$DEV"; xcrun simctl bootstatus "$DEV" -b
  xcrun simctl status_bar "$DEV" override --time "9:41" \
    --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
  xcrun simctl install "$DEV" "/tmp/pricetrail/Build/Products/Debug-iphonesimulator/Price Tracker.app"
done
for s in :01-list detail:02-detail add:03-add settings:04-settings; do
  SIMCTL_CHILD_UITEST_SEED=1 SIMCTL_CHILD_UITEST_SCREEN="${s%%:*}" \
    xcrun simctl launch --terminate-running-process "$PMAX" "$BID"
  SIMCTL_CHILD_UITEST_SEED=1 SIMCTL_CHILD_UITEST_SCREEN="${s%%:*}" \
    xcrun simctl launch --terminate-running-process "$IPAD" "$BID"
  sleep 7
  xcrun simctl io "$PMAX" screenshot "raw/${s##*:}.png"
  xcrun simctl io "$IPAD" screenshot "raw-ipad/${s##*:}.png"
done
# marketing sets
for f in raw/*.png; do b=$(basename "$f"); cp "$f" "marketing-6.9/$b"
  sips -z 2796 1290 "$f" --out "marketing-6.7/$b"
  sips -z 2688 1242 "$f" --out "marketing-6.5/$b"; done
for f in raw-ipad/*.png; do cp "$f" "marketing-ipad-13/$(basename "$f")"; done
```
