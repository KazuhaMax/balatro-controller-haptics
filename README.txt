Balatro Controller Haptics 1.2.0

分类反馈与 DualSense 增强 / Classified feedback and stronger DualSense rumble

设置 → 游戏：震动强度建议先选“中”，震动风格默认“事件”。
“事件”区分菜单、抽牌、出牌、计分、金币及结算等操作。
“简洁”保留 1.1 的通用短脉冲反馈，可随时切换比较。
DualSense 专用增益从 0.7 提高到 1.4；Xbox 强度不变。无需前置 mod。
这是自行调校的效果，不代表官方 iOS／Switch 手感的原样复刻。

Settings > Game > Haptic style: Events (default) / Simple (1.1 feel).
Events use independently tuned short-pulse presets, not official waveforms.
Sound categories still work when muted. Unknown native signals use fallback.

- Sends feedback after the current frame's input and animation events.
- Uses short pulses (about 35–100 ms) measured in real time.
- Converts each new screen-shake impulse into a single hit; the visual decay
  no longer feeds the motors every frame.
- Gives high-frequency detail more weight than low-frequency body, with a
  stronger 1.4 gain when a DualSense is directly identified (previously 0.7).
  Xbox/general gain remains 1.0; other Sony controllers retain 0.7.
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
中文菜单：设置 → 游戏 → 控制器震动。建议先选择“中”档强度。
This preserves your previous strength setting; change it to Medium for the
initial comparison if you previously selected High or Max.

The same two Lua files are used for Windows and macOS.
See README.md or README.zh-CN.md for details.

TECHNICAL NOTES

Steam Input may present a
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
Sound mapping adapted from Luna-Terra's balatro-rumble (MIT).
See THIRD_PARTY_NOTICES.txt and the notice embedded in controller_haptics.lua.
