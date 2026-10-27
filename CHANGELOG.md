# Changelog

## 1.2.0 — 2026-10-28

- Increase directly identified DualSense gain from 0.7 to 1.4, leaving Xbox/general
  and other Sony gains unchanged. Output remains clamped to the supported range.
- Add classified short pulses for UI, card, score, money, blind and title events.
- Observe sounds before mute and focus changes directly; coalesce duplicate hits.
- Keep generic feedback for unknown native events and the 1.1 Simple style.
- Add a saved Events / Simple selector alongside strength in the game settings.
- Fix a disconnected-controller edge case when events arrive before re-selection.
- Attribute the adapted MIT sound map to Luna-Terra's balatro-rumble.
- Presets are authored approximations, not measured official controller output.

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
