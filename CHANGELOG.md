# Changelog

## 1.1.0 — 2026-10-28

First public release.

- Replace accumulating screen-shake rumble with short event pulses.
- Send haptics after current-frame input and event processing.
- Use real-time pulse duration instead of frame-dependent native decay.
- Separate low-frequency body and high-frequency detail, with gentler Sony gain.
- Add finite command duration, explicit stops and driver-error handling.
- Preserve strength controls and the existing standalone save-folder loader.

## 1.0.0 — private prototype

- Enable Balatro's existing rumble flag on desktop.
- Add five strength levels, optional PlayStation Bluetooth SDL hints, logging,
  and cleanup when the active controller changes.
