小丑牌手柄增强｜Balatro Controller Haptics 1.3.2


正式版 / Release

设置 → 游戏 → 详细设置：
- 18 类事件，分为菜单、卡牌、计分、金币与盲注、标题五组。
- 每个事件可调整开关、强度、时长、左右混合，并预览或重置。
- 均衡（默认）、柔和两种内置预设；三个自定义配置槽位。
- 设备预设、额外增益、左右通道强度与测试。
- 按键图标：自动 / PlayStation / Nintendo / Xbox，即时预览。
  Nintendo 提示不符时可互换 A/B 与 X/Y；只改图标，不改按键功能。
- 新配置默认开启计分火焰：独立短脉冲，在 4 倍盲注目标达到上限。
- 内置预设保留设备选择、左右微调及火焰设置。
- 已有设置保留；升级后可应用均衡，并手动开启火焰。
配置自动保存在 settings.jkr。槽位保存不包含总强度及事件／简洁风格。
这是 mod，但自带 Lua 加载器，不需要 Lovely 或 Steamodded。

Settings > Game > Customize:
- 18 events in five categories, with on/off, gain, duration, channel mix and preview.
- Balanced (default) and Soft presets; three custom profile slots.
- Device preset, additional gain and independent left/right trims and tests.
- Button icons: Auto / PlayStation / Nintendo / Xbox, with live previews.
  Select a style manually if Steam Input hides the controller identity.
  Nintendo can swap A/B and X/Y labels to match remapped input; bindings stay unchanged.
  Icon settings persist separately from rumble presets and saved profiles.
- Score/blind-based flame feedback, enabled by default for new settings.
Balanced uses equal channels and 125% event duration; Soft uses original channel
ratios, 75% duration and 75% gain. Built-in presets keep device selection, left/right
trims and flame settings. Existing settings are preserved; apply Balanced and enable
flames to adopt the new defaults. Settings save in the existing settings.jkr.
Profiles include events, controller and flames, excluding master strength/style.
Event settings and flames use Events style; controller trims also affect Simple.
Flames add independent 55 ms crackle pulses every 100–150 ms during qualifying
scoring. Boost starts at half its selected cap at the blind target and reaches its
cap at 4x. Flames stop on pause, menus and the end of scoring. Output is capped at 100%.

- Sends feedback after the current frame's input and animation events.
- Uses short pulses measured in real time, shaped by preset/event duration settings.
- Converts each new screen-shake impulse into a single hit; the visual decay
  no longer feeds the motors every frame.
- Original channel ratios favor high-frequency detail; Balanced uses equal channels. A
  stronger 1.4 gain applies when a DualSense is directly identified (previously 0.7).
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
