# Habit Tracker — Screenshots

App Store screenshots for both platforms. Generated with
`swift scripts/make_screenshots.swift` (faithful Core Graphics renders of the
real UI — the simulators are unavailable on this machine, so these stand in
for simulator captures).

## Apple Watch screens
1. **Today** — habit list with tap-to-complete rings, streaks, daily progress
2. **Detail** — large progress ring, current/best streak, 30-day rate, this-week strip
3. **Streaks** — this-week dots, 28-day history grid, schedule
4. **New Habit** — name, emoji icon, color, repeat-day picker

## iPhone screens
1. **Today** — date large-title list, tap-to-complete rings, progress header, tab bar
2. **Detail** — large ring card, 2×2 stat tiles, this-week strip, 12-week grid
3. **Habits** — manage list (emoji, schedule, streaks)
4. **New Habit** — sheet form: name, icon grid, colors, weekday schedule, daily target

## Sizes (App Store Connect)
| Folder | Pixels | Slot |
| --- | --- | --- |
| `marketing-ultra` / `raw` | 410 × 502 | Apple Watch Ultra (49 mm) |
| `marketing-45mm` | 396 × 484 | Apple Watch Series 7–9 (45 mm) |
| `marketing-6.9` | 1320 × 2868 | iPhone 6.9" (16/17 Pro Max) |
| `marketing-6.5` | 1242 × 2688 | iPhone 6.5" |
| `marketing-ipad-13` | 2064 × 2752 | iPad 13" (required because the iOS target supports iPad) |

Upload `marketing-6.9` to the iPhone slot, `marketing-ipad-13` to the iPad
13" slot, and `marketing-ultra` to the Apple Watch slot; App Store Connect
scales the rest down. iPad screens show the same UI at tablet size (top tab
pill, form sheet for New Habit), matching how the SwiftUI app renders on iPad.
To regenerate: `cd "Habit Tracker" && swift scripts/make_screenshots.swift`.
