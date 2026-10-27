Balatro Controller Haptics 1.1.0

Fixes for sticky rumble and late menu feedback

- Sends feedback after the current frame's input and animation events.
- Uses short pulses (about 40–100 ms) measured in real time.
- Converts each new screen-shake impulse into a single hit; the visual decay
  no longer feeds the motors every frame.
- Gives high-frequency detail more weight than low-frequency body, with a
  gentler preset when a Sony/DualSense controller is directly identified.
- Stops on focus loss, controller changes, disconnection, Off, and quit.
- Sets a 120 ms maximum duration for every nonzero hardware command so a
  stalled game does not leave an indefinite rumble command running.

INSTALL / UPDATE

Quit Balatro first. Copy BOTH Lua files from this folder directly into:

  macOS:   ~/Library/Application Support/Balatro
  Windows: %AppData%\Balatro

This is the folder containing settings.jkr. Replace the old Controller Haptics
files. No Steamodded or Lovely installation is required. The supplied main.lua
is the existing loader, unchanged; controller_haptics.lua contains the fixes.
If main.lua belongs to another mod, do not overwrite it: loaders must be merged.

Restart the game. Settings > Game > Controller vibration controls strength.
中文菜单：设置 → 游戏 → 控制器震动。先用“中”测试菜单左右切换及出牌计分。
This preserves your previous strength setting; change it to Medium for the
initial comparison if you previously selected High or Max.

The same two Lua files are intended for both Windows and macOS. Windows
hardware testing is still pending. See README.md or README.zh-CN.md for details.

TEST STATUS AND LIMITS

17 regression groups pass in the LuaJIT runtime bundled with the installed
Balatro 1.0.1o / LOVE 11.5, using the game's actual update_canvas_juice function
with mock controllers. These cover same-frame events, 20–500 FPS, slow frames,
stalls, screen shake, reduced motion, Off, controller changes, focus changes,
driver failure and exit. This verifies timing and commands, not physical feel. The maintainer has also
confirmed improved feel with a USB-C DualSense on macOS.

Example at 120 FPS: a single 0.7 scoring-shake event kept the old command above
amplitude 0.02 through 650 ms; the repaired command fell below it after 41.7 ms.
This is a software simulation, not a measured controller response time.

Windows and Xbox hardware have not been tested. Steam Input may present a
DualSense as an Xbox controller, preventing automatic Sony preset detection.
This mod uses standard two-motor rumble. It does not implement native iOS
Core Haptics, Switch HD Rumble waveforms, or DualSense audio-based haptics.
Those platforms' exact feel is not guaranteed. USB is fine; the inherited
PlayStation Bluetooth support remains available through optional SDL hints.

UNINSTALL / ROLLBACK

Quit Balatro. To remove this mod, delete only its main.lua and
controller_haptics.lua from the save folder. Leave settings.jkr and profile
folders alone. To restore the previous mod, copy your backed-up Lua files into the save
folder and restart.

Technical API references:
https://love2d.org/wiki/Joystick:setVibration
https://wiki.libsdl.org/SDL2/SDL_GameControllerRumble

Source and releases: https://github.com/KazuhaMax/balatro-controller-haptics
License: MIT (see LICENSE).
