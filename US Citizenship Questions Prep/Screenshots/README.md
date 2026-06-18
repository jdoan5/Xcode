# Screenshots

App Store Connect screenshot sets for Civics Test 2025.

```
raw/             native captures from iPhone 17 Pro Max (1320×2868)
marketing-6.9/   6.9" — 1320×2868  (iPhone 17/16 Pro Max)   ← required slot
marketing-6.7/   6.7" — 1290×2796  (scaled from 6.9)
marketing-6.5/   6.5" — 1242×2688  (scaled from 6.9)
```

Five screens, numbered for upload order: `01-home`, `02-quiz`, `03-fill`,
`04-study`, `05-officials`.

> A single 6.9" set satisfies App Store Connect for iPhone; the 6.5"/6.7"
> folders are provided for completeness and were scaled from the 6.9" capture.

## Recapture (automated)

These were captured headlessly on the **DEBUG** build. The app reads two launch
environment variables (see `applyUITestHooks()` in `Views/HomeView.swift`,
compiled only under `#if DEBUG`):

- `UITEST_SEED=1` — deterministic question order (no shuffle), so the practice
  test and fill-in-the-blank shots always open on question 1.
- `UITEST_SCREEN=quiz|fill|study|officials` — open a specific screen on launch
  (omit for the home screen; `fill` also skips the setup stage straight into
  the typing screen).

Neither variable can be set on a real App Store launch, so production behavior
is unaffected.

```bash
DEV="iPhone 17 Pro Max"; BID="com.jdoan.USCitizenshipCivicQuestions"
xcodebuild -project "US Citizenship Civic Questions.xcodeproj" \
  -scheme "US Citizenship Civic Questions" \
  -sdk iphonesimulator -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEV" \
  -derivedDataPath /tmp/civics CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot "$DEV"; xcrun simctl bootstatus "$DEV" -b
# clean status bar for marketing shots
xcrun simctl status_bar "$DEV" override --time "9:41" \
  --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
xcrun simctl install "$DEV" "/tmp/civics/Build/Products/Debug-iphonesimulator/US Citizenship Civic Questions.app"
for s in :01-home quiz:02-quiz fill:03-fill study:04-study officials:05-officials; do
  SIMCTL_CHILD_UITEST_SEED=1 SIMCTL_CHILD_UITEST_SCREEN="${s%%:*}" \
    xcrun simctl launch --terminate-running-process "$DEV" "$BID"
  sleep 4
  xcrun simctl io "$DEV" screenshot "raw/${s##*:}.png"
done
# scale marketing sets
for f in raw/*.png; do b=$(basename "$f"); cp "$f" "marketing-6.9/$b"
  sips -z 2796 1290 "$f" --out "marketing-6.7/$b"
  sips -z 2688 1242 "$f" --out "marketing-6.5/$b"; done
```

## Note on content

All questions and answers shown are from the official, public-domain USCIS
civics test list (M-1778, 09/25). No user data appears — the My Officials
screen is captured empty, showing only its field labels and hints.
