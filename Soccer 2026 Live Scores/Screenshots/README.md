# Screenshots

App Store Connect screenshot sets for World Cup 2026.

```
raw/             native captures from iPhone 17 Pro Max (1320×2868)
marketing-6.9/   6.9" — 1320×2868  (iPhone 17/16 Pro Max)   ← required slot
marketing-6.7/   6.7" — 1290×2796  (scaled from 6.9)
marketing-6.5/   6.5" — 1242×2688  (scaled from 6.9)
```

Five screens, numbered for upload order: `01-schedule`, `02-groups`, `03-bracket`, `04-teams`, `05-favorites`.

> A single 6.9" set now satisfies App Store Connect for iPhone; the 6.5"/6.7" folders are provided for completeness and were scaled from the 6.9" capture.

## Recapture (automated)

These were captured headlessly. The app reads a `UITEST_TAB` launch env var (`schedule`/`groups`/`bracket`/`teams`/`favorites`) to open a specific tab, and skips the notification prompt when it's set.

```bash
DEV="iPhone 17 Pro Max"; BID="com.jdoan.WorldCup2026"
xcodebuild -project WorldCup2026.xcodeproj -scheme WorldCup2026 \
  -sdk iphonesimulator -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEV" \
  -derivedDataPath /tmp/wc CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "$DEV"; xcrun simctl bootstatus "$DEV" -b
# clean status bar for marketing shots
xcrun simctl status_bar "$DEV" override --time "9:41" \
  --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
xcrun simctl install "$DEV" /tmp/wc/Build/Products/Debug-iphonesimulator/WorldCup2026.app
# optional: seed a few favorites so the Favorites/stars look real
xcrun simctl spawn "$DEV" defaults write "$BID" favorites.v1 \
  '{teams = ("Brazil","Argentina","France"); matches = ("2026-06-11|mexico|south africa"); }'
for t in schedule:01 groups:02 bracket:03 teams:04 favorites:05; do
  SIMCTL_CHILD_UITEST_TAB="${t%%:*}" xcrun simctl launch --terminate-running-process "$DEV" "$BID"
  sleep 4
  xcrun simctl io "$DEV" screenshot "raw/${t##*:}-${t%%:*}.png"
done
```

## Note on content

These raw shots were taken on the **bundled (no-key) data**, so Schedule shows the "add a key" banner, Groups read 0-0-0, and the bracket shows seed placeholders (`2A`, `W73`). For the final marketing set, recapture during the tournament with a live API-Football key configured so scores, real standings, and resolved knockout teams appear.
