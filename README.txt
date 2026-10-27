Balatro Controller Haptics 1.3.0


正式版 / Release

设置 → 游戏 → 详细设置：
- 18 类事件，分为菜单、卡牌、计分、金币与盲注、标题五组。
- 每个事件可调整开关、强度、时长、左右混合，并预览或重置。
- 清晰、均衡、柔和三种内置预设；三个自定义配置槽位。
- 设备预设、额外增益、左右通道强度与测试。
- 可选计分火焰增强，默认关闭；默认参数保留 1.2 的手感。
配置自动保存在 settings.jkr。槽位保存不包含总强度及事件／简洁风格。
这是 mod，但自带 Lua 加载器，不需要 Lovely 或 Steamodded。

Settings > Game > Customize:
- 18 events in five categories, with on/off, gain, duration, channel mix and preview.
- Crisp, Balanced and Soft presets; three custom profile slots.
- Device preset, additional gain and independent left/right trims and tests.
- Optional score/blind-based flame boost, disabled by default.
Defaults preserve the 1.2 feel. Settings save in the existing settings.jkr.
Profiles include events, controller and flames, excluding master strength/style.
Event settings and flames use Events style; controller trims also affect Simple.
Flames boost scoring pulses from the blind target up to 16x the target, without
extending pulses or adding continuous rumble. Output is capped at 100%.

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
DualSense as an Xbox controller. Select Customize > Controller tuning >
Device preset > DualSense to override automatic detection.
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
