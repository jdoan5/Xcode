# Screenshots

App Store Connect screenshot sets for **Stand Study** (`com.jdoan.StandStudy`), v1.0 (1).

## Which folder goes where

App Store Connect names its slots by display, not by inches. Each `UPLOAD/` folder is one slot:

| Folder | App Store Connect slot | Size | |
|---|---|---|---|
| `UPLOAD/iPhone-medium-6.3/` | iPhone with Dynamic Island (medium display) | 1206x2622 | **required** |
| `UPLOAD/iPad-13/` | iPad 13" display | 2064x2752 | **required** |
| `UPLOAD/iPhone-large-6.9/` | iPhone with Dynamic Island (large display) | 1320x2868 | optional |
| `UPLOAD/iPhone-Duo/` | iPhone Duo (outer display) | 1398x2034 | optional until April 2027 |

The 6.9-inch set is rejected as "File dimensions are invalid" in the medium-display slot: that
slot takes only 1206x2622 or 1179x2556 (iPhone 18 Pro, 17 Pro, 17, 16 Pro, 16, 15 Pro, 15, 14
Pro). App Store Connect scales the required sets for every slot left empty, so the two optional
folders only replace a scaled copy with a native one. The iPhone Duo slot becomes required for
apps built with the iOS 27.1 SDK or later from April 2027.

```
raw-6.3/              iPhone 18 Pro simulator (iOS 27.0), as captured*: 1206x2622, has alpha
raw/                  iPhone 18 Pro Max simulator (iOS 27.0), as captured*: 1320x2868, has alpha
raw-ipad/             iPad Pro 13-inch (M5) simulator (iOS 27.0), as captured: 2064x2752, has alpha
raw-duo/              iPhone Duo simulator (iOS 27.1), outer display, as captured*: 1398x2034, has alpha
marketing-6.3/        6.3-inch iPhone   1206x2622, alpha removed, = UPLOAD/iPhone-medium-6.3
marketing-6.9/        6.9-inch iPhone   1320x2868, alpha removed, = UPLOAD/iPhone-large-6.9
marketing-6.7/        6.7-inch iPhone   1290x2796, scaled from raw/, alpha removed
marketing-6.5/        6.5-inch iPhone   1242x2688, scaled from raw/, alpha removed
marketing-ipad-13/    13-inch iPad      2064x2752, alpha removed, = UPLOAD/iPad-13
marketing-ipad-12.9/  12.9-inch iPad    2048x2732, scaled from raw-ipad/, alpha removed
marketing-duo/        iPhone Duo        1398x2034, alpha removed, = UPLOAD/iPhone-Duo
```

\* Except for the simulator's corner mark, painted over (see Recapture).

The 6.7 and 6.5 sets fit "iPhone with Face ID (large display)" (1290x2796 is also accepted in
the Dynamic Island large slot) and the 12.9 set the iPad 12.9" slot, in case one is ever wanted
on its own.

## Upload order

Strongest first. The same six screens on iPhone and iPad, each in the layout that device really
uses: on iPhone the reference fills the screen with the controls in a bar below it; on iPad the
controls sit in a column beside the reference.

| # | File | Shows | Launch arguments |
|---|------|-------|------------------|
| 1 | `01-player` | A session under way: Degas's *Little Fourteen-Year-Old Dancer* from the Sample set, pose 3 of 10, paused at 0:42 | `-demo-player` |
| 2 | `02-notan-grid` | The same pose with three-value notan and the thirds grid turned on | `-demo-player -demo-aids notan3,grid` |
| 3 | `03-draw` | Draw: the Sample set chosen, the plan presets (Gesture selected), Start; on iPad also Shuffle (on iPhone it is further down the list, under the Start bar) | `-tab draw` |
| 4 | `04-sample-set` | Library > Sample set: the 28 bundled works (on iPad the credits list starts below the grid) | `-open sample-set` |
| 5 | `05-session` | Log > the Class session from the example log: totals, plan, and each pose with its reference and time | `-demo-log -open session` |
| 6 | `06-settings` | Settings: chime, warning tick, haptics, and the default view aids with their preview | `-tab settings` |

Left out on purpose:

- **Compare.** It shows a photo of your drawing over the reference, and there is no real
  drawing photo to put in it. A staged one would show something the app did not do.
- **The forced fold poses** (`-pose tabletop|book`). They exist for checking layouts on a
  simulator; a tabletop layout forced onto an iPad is not what an iPad shows.

All content is the bundled Sample set: public-domain (CC0) works from The Metropolitan Museum of
Art's Open Access program (`Submission/sample-set-sources.md`), credited in the app's About
screen and under the Sample set grid. The log is the in-memory example from `-demo-log`, so its
dates are whatever week the script ran in, and nothing is written to the app's real store.

## iPhone Duo

`raw-duo/` holds the same six screens from the iPhone Duo simulator's **outer** display (screen
id 1), closed, at 1398x2034, which is the outer-display size App Store Connect's iPhone Duo slot
takes; `UPLOAD/iPhone-Duo/` is them flattened. The slot also takes the inner display at
2007x2853, but the inner display cannot be captured from the command line, so there are no
inner-display shots. The simulator is the only Duo these were taken on.

## Recapture

```bash
bash Screenshots/capture.sh
```

It builds a Debug app (the launch arguments are DEBUG-only; see the project README, "Launch
arguments"), finds a 6.3-inch Pro iPhone, a Pro Max iPhone, a 13-inch iPad Pro and an iPhone Duo
(simulators named "... (Stand Study)" first, then the newest runtime; override with
`IPHONE_MEDIUM_UDID`, `IPHONE_UDID`, `IPAD_UDID` and `DUO_UDID`), and for each one: sets a
12-hour clock, light appearance, the default text size and, on iPad, Full Screen Apps, overrides
the status bar to 9:41 with full battery and signal, reinstalls the app so nothing from an
earlier run shows, and relaunches it once per screen. Captures go through a temp folder because
the simulator service cannot write into ~/Documents. Every raw folder it captures is replaced
wholesale, so a renamed or dropped screen cannot linger and be uploaded.

Set a simulator's variable to `none` to skip it and keep its raw folder as it is; the marketing
and `UPLOAD/` folders are always rebuilt from the raw folders, and only from the six screens in
the table above. The 6.3-inch set was added this way, without touching the others:

```bash
IPHONE_UDID=none IPAD_UDID=none DUO_UDID=none bash Screenshots/capture.sh
```

A fresh install's first launch can take longer than the usual wait (`SETTLE`, 6 s), and a shot
taken too early is the app's plain white launch screen. So each simulator gets one unrecorded
launch after the install (`WARMUP`, 12 s), and every shot is checked with `frames.swift blank`:
a frame that is one plain colour is taken again after a longer wait, and the script stops if it
is still blank.

iPadOS starts a new simulator in Windowed Apps mode, which puts a window resize grabber in the
bottom-right corner of every capture and the app's name beside the date in the status bar. The
script turns it off the way Settings > Multitasking & Gestures > Full Screen Apps does
(`SBMedusaMultitaskingEnabled` and `SBChamoisWindowingEnabled` false in `com.apple.springboard`)
and restarts the simulator when it had to change them. The iPad set was recaptured this way
on 2026-10-24; the first iPad set had the grabber and the app name.

The iOS 27 iPhone simulators (the 18 Pro Max and the Duo at least) draw a 3x3-pixel black
square, with a soft one-pixel edge, in the very top-left corner of every capture. It is not part
of the app, and on Stand Study's light paper and gray backgrounds it shows. `frames.swift
corner` fills that 4x4 corner with the background colour right beside it, only when the mark is
there, and changes no other pixel. The iPad captures have no mark and are left as they are.

The 6.3-inch, 6.9-inch and Duo shots must come out of the simulator at exactly 1206x2622,
1320x2868 and 1398x2034. If a future simulator captures at a different size, the script scales
only when the aspect ratio is identical and stops otherwise.

Every marketing PNG goes through `flatten.swift`. App Store Connect rejects a screenshot with an
alpha channel and reports it as a *dimensions* error, and `sips --setProperty hasAlpha false`
only flips a flag. The last step of the script prints each file's size and alpha and checks that
each `UPLOAD/` folder holds exactly six files. It cannot tell whether a screen shows the right
thing, so open every file in `UPLOAD/` before uploading.

On iPhone, 03, 05 and 06 show the list scrolled to the top, so the last rows run under the Start
bar or the floating tab bar, the way they do on the device; the iPad shots have room for them.

Captured 2026-10-24 with Xcode 27.1 (the 6.3-inch set later the same day).
