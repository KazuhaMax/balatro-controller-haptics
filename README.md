# Balatro Controller Haptics

Short, responsive controller rumble for the Steam desktop version of Balatro.

[中文说明](README.zh-CN.md) · [Download v1.1.0](https://github.com/KazuhaMax/balatro-controller-haptics/releases/latest) · [Report an issue](https://github.com/KazuhaMax/balatro-controller-haptics/issues)

This small Lua mod enables controller vibration and replaces the desktop game's
rumble mixing with short event-driven pulses. Menu navigation responds in the
current frame; scoring and card effects produce distinct hits without a long
screen-shake rumble tail.

## Install on Windows

1. Download and extract `balatro-controller-haptics-1.1.0.zip` from Releases.
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
the loaders instead of overwriting it. Other mod-loader combinations are untested.

## Install on macOS

Quit Balatro. In Finder, press **Command + Shift + G** and open:

```text
~/Library/Application Support/Balatro
```

Copy the same two Lua files into this folder, alongside `settings.jkr`, then
restart the game. Use **Settings → Game → Controller vibration** to adjust strength.

## What changes

- Menu feedback is sent after input and game events are processed in the current frame.
- Effects use roughly 40–100 ms pulses timed in real seconds, independent of game speed.
- New screen-shake impulses trigger hits; their visual decay does not repeatedly retrigger rumble.
- High-frequency detail gets more weight than low-frequency body. Directly identified Sony pads use a gentler preset.
- Effects stop on focus loss, controller changes, disconnection, Off, and quit.
- Every nonzero command has a finite 120 ms duration to bound rumble if the game stalls.
- Strength settings: Off, Low, Medium, High, Max. Existing settings are preserved.

This uses standard two-motor rumble. It does **not** implement native iOS haptic
patterns, Switch HD Rumble waveforms, DualSense audio haptics, or adaptive triggers.

## Compatibility and testing

| Configuration | Status |
| --- | --- |
| Steam Balatro 1.0.1o on macOS, LÖVE 11.5 / SDL 2.28.5 | Loaded successfully |
| DualSense over USB-C on macOS | Hands-on feedback confirmed by the maintainer |
| Windows Steam version | Intended to work with the same Lua files; not yet tested |
| Xbox controller | Not yet hardware-tested |
| Bluetooth | Optional SDL PlayStation hints included; not yet hands-on verified |
| Steamodded / Lovely / other loaders | Integration not tested |

17 regression groups passed using the installed game's LuaJIT runtime and
original canvas-update function with mock controllers. They covered same-frame
response, 20–500 FPS, slow frames, stalls, screen shake, reduced motion,
focus changes, controller changes, driver errors, settings, and exit.

One simulated scoring event at 120 FPS kept the old command above amplitude
0.02 through 650 ms; the revised command fell below that threshold after
41.7 ms. These are software signal measurements, not hardware latency measurements.

## Troubleshooting

- **No vibration setting:** verify that both files sit directly beside `settings.jkr`,
  and fully restart the game. Check `controller_haptics.log` in that folder.
- **Setting appears, but no rumble:** press a controller button to make it the
  active input device. Check that vibration is not Off. Try USB first.
- **DualSense appears as an Xbox pad:** Steam Input can change the identity exposed
  to the game. If rumble fails, try disabling Steam Input for Balatro and relaunching;
  restore it if controller input stops working. A virtual Xbox identity uses the
  generic strength preset.
- **Feel is too soft or strong:** adjust strength in the game settings.
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
Hardware feedback is especially useful for the untested Windows configurations.

## License and credits

[MIT License](LICENSE). Maintained by [KazuhaMax](https://github.com/KazuhaMax).
Developed with assistance from Claude and OpenAI Codex.

This is an unofficial fan mod and is not affiliated with or endorsed by
Balatro's developers or publisher. Balatro is required and must be obtained separately.

API references: [LÖVE vibration](https://love2d.org/wiki/Joystick:setVibration),
[SDL rumble](https://wiki.libsdl.org/SDL2/SDL_GameControllerRumble).
