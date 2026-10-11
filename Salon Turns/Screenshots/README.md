# Screenshots

App Store Connect screenshot sets for **Salon Turns** (`com.jdoan.SalonTurns`). The app is iPad only.

```
raw-ipad/             native captures from the iPad Pro 13-inch simulator (2064x2752), as taken
marketing-ipad-13/    13-inch iPad   - 2064x2752, alpha removed      <- required iPad slot
marketing-ipad-12.9/  12.9-inch iPad - 2048x2732, scaled, alpha removed (legacy slot)
```

Regenerate with `bash capture.sh` from this folder. It builds the app for the simulator, loads the
sample day (`--seed-sample`), opens each screen with `--screen board|log|team|tally|settings`, writes
the captures through a temp folder (the simulator service cannot write into ~/Documents), and
replaces each folder's set wholesale so a renamed screen cannot linger.

Every PNG is flattened by `flatten.swift`. App Store Connect rejects screenshots with an alpha
channel and reports it as a *dimensions* error; `sips --setProperty hasAlpha false` does not strip it.
Open each file in `marketing-ipad-13/` and check it shows the sample day before uploading.
