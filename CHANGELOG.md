# Changelog

## 1.3.2 — 2026-10-28

- Add Auto, PlayStation, Nintendo and Xbox button icon styles with live previews.
- Recognize DualSense/DualShock, Sony vendor IDs, Switch/Joy-Con and Nintendo IDs.
- Update existing prompts immediately when changing style or switching controllers.
- Add optional Nintendo A/B and X/Y label swapping for remapped input layouts.
- Save icon preferences independently of rumble settings and custom profile slots.
- Reuse the game’s built-in artwork without changing button actions or adding dependencies.

## 1.3.1 — 2026-10-28

- Fix missing flame feedback when displayed scoring updates without a new sound.
- Add separated, short flame crackles and reach full score boost at 4x the blind.
- Stop flame output on pause, overlays and the end of scoring.
- Fix controller navigation across customization controls; focus a control on entry
  and retain button focus after applying, loading or resetting settings.
- Place Customize below vibration strength and move Haptic style into Customize.
- Keep only Balanced and Soft presets. New settings default to Balanced with flames on.
- Keep device selection, channel trims and flame settings when applying a built-in preset.
- Preserve existing saved settings and custom slots on upgrade.

## 1.3.0 — 2026-10-28

- Add native Chinese/English customization menus with five event groups.
- Add per-event enable, gain, duration, channel mix, preview and reset controls.
- Add Crisp, Balanced and Soft presets and three persistent custom profile slots.
- Add manual device selection, gain, left/right trims and single-channel tests.
- Add optional score-to-blind flame boost with a bounded cap, scoring-only scope
  and no continuous rumble or longer pulses. Disabled by default.
- Preserve the 1.2 defaults, saved master strength and Events/Simple selection.
- Keep the standalone two-file installation with no additional mod framework.

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
