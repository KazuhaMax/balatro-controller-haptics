# 小丑牌手柄增强｜Balatro Controller Haptics

Short, responsive controller rumble for the Steam desktop version of Balatro.

[中文说明](README.zh-CN.md) · [Download stable release](https://github.com/KazuhaMax/balatro-controller-haptics/releases/latest) · [Report an issue](https://github.com/KazuhaMax/balatro-controller-haptics/issues)

This small Lua mod enables controller vibration and replaces the desktop game's
rumble mixing with short event-driven pulses. Menu navigation responds in the
current frame; scoring and card effects produce distinct hits without a long
screen-shake rumble tail.

**v1.3.2** adds automatic and manual PlayStation, Nintendo and Xbox button icons,
including the flame feedback and controller navigation fixes from 1.3.1.
New settings use Balanced feedback with flames enabled.
No Lovely or Steamodded dependency is required.

## Install on Windows

1. Extract `balatro-controller-haptics-1.3.2.zip`.
2. Quit Balatro completely.
3. Press **Win + R**, enter `%AppData%\Balatro`, and press Enter. If the folder
   does not exist, launch Balatro once, quit, then try again.
4. Copy **`main.lua` and `controller_haptics.lua`** directly into this folder,
   alongside `settings.jkr`. Do not put them in a `Mods` subfolder.
5. Connect a DualSense or Xbox controller over USB and start Balatro from Steam.
6. Open **Settings → Game → Controller vibration** and start with **Medium**.

No additional mod loader is required for this standalone installation. Updating
from an older version of this mod means replacing its two Lua files while the
game is closed. If `main.lua` belongs to another mod, keep a backup and merge
the loaders instead of overwriting it.

## Install on macOS

Quit Balatro. In Finder, press **Command + Shift + G** and open:

```text
~/Library/Application Support/Balatro
```

Copy the same two Lua files into this folder, alongside `settings.jkr`, then
restart the game. Use **Settings → Game → Controller vibration** to adjust strength.

## Customize the feedback

Open **Settings → Game → Customize**, directly below vibration strength.
Haptic style is now inside Customize. New settings use Balanced with flames enabled.
Existing saved settings are preserved: to adopt the new defaults, apply Balanced
and enable **Score flame feedback → Flame boost**.

- **Customize events:** 18 events in five groups: menus, cards, scoring, money/blinds,
  and title effects. Each event has an on/off switch, strength (25–200%), duration
  (50–150%), channel mix, a preview button and an individual reset.
- **Channel mixes:** Original, Right / light, Balanced, Left / heavy and Dual full.
  These adjust the two standard rumble channels. Perceived weight depends on the pad.
- **Presets and saved profiles:** Balanced (default) and Soft presets,
  plus three slots for your own event, controller and flame settings. Saving replaces
  the selected slot; loading an empty slot leaves settings unchanged. Balanced uses
  equal channels and 125% event duration; Soft uses original channel ratios, 75%
  duration and 75% gain. Applying either preset keeps device selection, left/right
  trims and flame settings. Master strength
  and the Events/Simple style are not included in a profile. Settings persist in
  the game's existing `settings.jkr`; no extra configuration file is needed.
- **Controller tuning:** Auto, Xbox / Generic, DualSense or Other Sony preset;
  additional gain and independent left/right trims (50–150%), with channel tests.
  Manually select DualSense when Steam Input exposes it as a virtual Xbox pad.
  This is manual tuning, not automatic hardware calibration or native audio haptics.
- **Button icons:** Auto (default), PlayStation, Nintendo or Xbox, with live previews.
  Auto recognizes Sony/Nintendo vendor IDs and DualSense, DualShock, Switch and
  Joy-Con names. If Steam Input exposes a virtual Xbox device, choose a style
  manually under **Customize → Button icons**. Nintendo defaults to B/A/Y/X
  for south/east/west/north; choose **Swap A/B and X/Y** if Steam Input
  remaps the letters. This changes prompts throughout the game, not input bindings.
  Icon choices save independently of rumble presets and profile slots.
- **Score flame feedback:** adds short, separated crackle pulses once the displayed
  hand score (chips × mult) reaches the blind target, even without a new score sound.
  The 55 ms pulses repeat every 100–150 ms while qualifying scoring continues.
  Scoring-event boost starts at half the selected maximum at the target and reaches
  its cap at 4× the target. Choose +25%, +50% or +100%; this also scales crackle
  strength. Flames stop on pause, menus or the end of scoring, and skip unsupported
  big-number values.

Event customization and flame feedback apply to **Events** style. Controller trims
also apply to **Simple**. Use a controller to activate pulse previews; master Off,
focus loss and disconnection still silence output. All output is capped at 100%,
so very strong settings can compress the differences between events.

## How the standalone loader works

This is a mod; it simply includes its own small loader. In this desktop build,
LÖVE searches Balatro's save folder before the packaged game files. Our `main.lua`
therefore runs first. It temporarily prioritizes the packaged files to load the
original `main.lua`, restores normal lookup, executes the original entry point,
then loads `controller_haptics.lua` before the game's startup callback.

The Lua code wraps existing event, update and UI functions, preserving their normal
work while generating rumble through `Joystick:setVibration`. LÖVE/SDL sends that
output to the controller. The same code builds the settings pages using Balatro's
native UI functions. No game executable patch or additional mod framework is needed.

## Core feedback behavior

- **Haptic style → Events / Simple** switches between classified effects (default)
  and the 1.1 generic short-pulse response. The selection is saved.
- Events distinguish menu focus/confirmation, card draws, played hands, chips,
  mult/XMult/edition scoring, coins, cash-out totals, debuffs, destruction,
  shattering, blind reveals and title effects, with separate pulse presets.
- Menu focus is observed directly; other categories use sound calls, even while
  muted. Shared sound names can classify additional scenes using the same sound.
- Same-category events in a frame are coalesced. Classified events replace the
  aggregate signal for that frame; unknown events with native vibration signals
  retain generic feedback.
- Menu feedback is sent after input and game events are processed in the current frame.
- Event pulses are timed in real seconds, independent of game speed; preset and
  per-event duration settings adjust their length.
- New screen-shake impulses trigger hits; their visual decay does not repeatedly retrigger rumble.
- The original channel mix favors high-frequency detail; Balanced uses equal channels. Directly identified DualSense pads use a 1.4 gain (twice the preview's 0.7 command amplitude before clamping); Xbox/general gain stays at 1.0. Other Sony pads retain 0.7.
- Effects stop on focus loss, controller changes, disconnection, Off, and quit.
- Every nonzero command has a finite 120 ms duration to bound rumble if the game stalls.
- Strength settings: Off, Low, Medium, High, Max. Existing settings are preserved.

This uses standard two-motor rumble. It does **not** implement native iOS haptic
patterns, Switch HD Rumble waveforms, DualSense audio haptics, or adaptive triggers.
Event classification makes individual tuning possible; it does not establish
parity with official versions. Compare the same controller on iOS and desktop
before drawing conclusions about feel.

## Troubleshooting

- **No vibration setting:** verify that both files sit directly beside `settings.jkr`,
  and fully restart the game. Check `controller_haptics.log` in that folder.
- **Setting appears, but no rumble:** press a controller button to make it the
  active input device. Check that vibration is not Off. Try USB first.
- **DualSense appears as an Xbox pad:** Steam Input can change the identity exposed
  to the game. If rumble fails, try disabling Steam Input for Balatro and relaunching;
  restore it if controller input stops working. A virtual Xbox identity uses the
  generic strength preset in Auto; choose **Customize → Controller tuning →
  Device preset → DualSense** to override it.
- **Feel is too soft or strong:** adjust master strength, then controller trims or
  individual event settings under Customize.
- **Reporting a problem:** include OS, game version, controller model, USB/Bluetooth,
  Steam Input setting, and relevant lines from `controller_haptics.log`.

## Uninstall

Quit Balatro and remove only this mod's `main.lua` and `controller_haptics.lua`
from the save folder. Leave `settings.jkr` and the numbered profile folders alone.
To roll back, restore a backup of the previous two mod files and restart.

## Development

The project consists of two files:

- `main.lua`: loads the game's original entry point, then this mod.
- `controller_haptics.lua`: hooks game events, generates pulses, and adds strength controls.

The repository and release contain only the mod and its documentation; Balatro
game files and assets are not distributed. To contribute, open an issue or pull request.

## License and credits

[MIT License](LICENSE). Maintained by [KazuhaMax](https://github.com/KazuhaMax).
Developed with assistance from Claude and OpenAI Codex.

Sound-category mappings are adapted from [Luna-Terra's balatro-rumble](https://github.com/delta9690/balatro-rumble/blob/main/categories.lua),
under MIT. The full upstream notice is retained in the Lua file and
[THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt). Pulse synthesis and presets
remain this project's independent implementation.

This is an unofficial fan mod and is not affiliated with or endorsed by
Balatro's developers or publisher. Balatro is required and must be obtained separately.

API references: [LÖVE vibration](https://love2d.org/wiki/Joystick:setVibration),
[SDL rumble](https://wiki.libsdl.org/SDL2/SDL_GameControllerRumble).
