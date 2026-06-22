# Screenshots

App Store Connect screenshot sets for **Invoice Tracker** (`com.jdoan.InvoiceTracker`).

```
raw/                 native iPhone captures from iPhone 17 Pro Max (1320×2868)
marketing-6.9/       6.9"  — 1320×2868  (iPhone 17/16 Pro Max)   ← required iPhone slot
marketing-6.7/       6.7"  — 1290×2796  (scaled from 6.9)
marketing-6.5/       6.5"  — 1242×2688  (scaled from 6.9)
raw-ipad/            native iPad captures from iPad Pro 13" (2064×2752)
marketing-ipad-13/   iPad 13"   — 2064×2752 (iPad Pro/Air 13")   ← required iPad slot
marketing-ipad-12.9/ iPad 12.9" — 2048×2732 (scaled, legacy)
```

Three screens, numbered for upload order: `01-invoices`, `02-dashboard`, `03-settings`.
The app is **universal**, so App Store Connect requires **both** an iPhone set (6.9") and an
iPad set (13"). A single 6.9" set satisfies the iPhone requirement; the 6.5"/6.7" folders are
provided for completeness and were scaled from the 6.9" capture.

## macOS set (Mac App Store)

The Mac App Store needs its **own** screenshots, separate from iPhone/iPad, at one of these exact
sizes: **2880×1800 / 2560×1600 / 1440×900 / 1280×800**.

### Primary: headless in-app render (no permissions)

```bash
bash mac-snapshot.sh
```

The app has a built-in `--snapshot <dir>` mode (`SnapshotRenderer.swift`, macOS-only) that uses SwiftUI's
`ImageRenderer` to draw each screen directly to a PNG — **no window and no Screen Recording permission**.
`mac-snapshot.sh` builds the app, re-signs it ad-hoc (to drop the sandbox so it can write out), runs the
render, and writes `marketing-mac/*.png` at **2560×1600** (a valid Mac App Store size). The snapshot
screens are chromeless reconstructions (no `NavigationStack`/`ScrollView`, which `ImageRenderer` can't
render offscreen) that reuse the app's real components, with data fetched synchronously.

> Build note: the script passes `ENABLE_DEBUG_DYLIB=NO` — the separate preview/debug dylib's codesign
> step is flaky in headless contexts and isn't needed for rendering.

### Alternative: capture the real window

`bash mac-capture.sh` launches the app and screen-captures the live window (needs Screen Recording
permission + a GUI session), compositing onto a 2880×1800 canvas. Use this if you want the exact native
window chrome. The headless `mac-snapshot.sh` is preferred since it needs no permissions.

## Recapture (automated)

The app reads plain launch **arguments** (parsed in `applyLaunchArgs()` in `ContentView.swift`) so
screens can be captured headlessly:

- `--seed-sample` — insert the demo records (`SampleData.seed`). **Pass once** — it appends every launch.
- `--unlock` — skip the optional biometric lock screen (the lock is off by default anyway).
- `--tab-ledger | --tab-dashboard | --tab-settings` — open a specific tab on launch.

These arguments are never supplied on a normal App Store launch, so production behavior is unaffected.

Run the bundled script from this folder:

```bash
bash capture.sh
```

It builds the app for the simulator, boots an **iPhone 17 Pro Max** and an **iPad Pro 13"**, sets a
clean 9:41 / full-battery marketing status bar, seeds the demo data once, captures the three screens
on each device into `raw/` and `raw-ipad/`, then scales every marketing set with `sips`.

## Note on content

The records shown (March rent, Website redesign, etc.) are fictitious example data seeded only for
these captures. Real user data never appears.
