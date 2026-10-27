# Balatro Controller Haptics

为 Steam 桌面版《Balatro》增加短促、及时的手柄震动反馈。

[English](README.md) · [下载最新版](https://github.com/KazuhaMax/balatro-controller-haptics/releases/latest) · [反馈问题](https://github.com/KazuhaMax/balatro-controller-haptics/issues)

这个 Lua mod 将菜单、出牌及计分事件转成短促的震动脉冲，改善持续拖尾和菜单反馈迟钝的问题。

## Windows 安装

1. 在 Releases 下载并解压 `balatro-controller-haptics-1.1.0.zip`。
2. 完全退出 Balatro。
3. 按 **Win + R**，输入 `%AppData%\Balatro`，按回车。如果目录不存在，先启动一次游戏并退出。
4. 把 **`main.lua` 和 `controller_haptics.lua`** 复制到这个文件夹，与 `settings.jkr` 放在同一层。
5. 用 USB 连接 DualSense 或 Xbox 手柄，从 Steam 启动游戏。
6. 在 **设置 → 游戏 → 控制器震动** 中先选择 **中**。

不需要额外安装 mod 加载器，也不要把文件放进 `Mods` 子目录。更新本 mod 时，退出游戏后替换这两个文件即可。

如果已有 `main.lua` 属于其他 mod，请先备份并合并加载器，避免直接覆盖。

## macOS 安装

退出游戏，在 Finder 中按 **Command + Shift + G**，打开：

```text
~/Library/Application Support/Balatro
```

把相同的两个 Lua 文件放到 `settings.jkr` 旁边，重启游戏后调整震动强度。

## 主要改进

- 菜单操作和游戏事件处理完成后，在当前帧输出震动。
- 使用约 40–100 毫秒的短脉冲，按真实时间计时。
- 屏幕抖动每次新增冲击只触发一次反馈，视觉拖尾不会不断补充震动。
- 加强高频细节、减轻低频持续感，识别到 Sony 手柄时使用较柔和的强度。
- 切换窗口、切换控制器、断连、关闭震动及退出时停止反馈。
- 每条非零震动指令最多持续 120 毫秒，避免游戏卡住时留下无限震动。
- 保留关、弱、中、强、最强五档，以及已有设置。

这是普通双马达震动，不实现 iOS 原生触觉模式、Switch HD Rumble 波形、DualSense 音频触觉或自适应扳机。

## 常见问题

- **没有“控制器震动”选项：** 检查两个 Lua 文件是否直接放在 `settings.jkr` 旁边，并完全重启游戏。可查看同目录的 `controller_haptics.log`。
- **有选项但不震：** 按一下手柄按钮，让游戏切换到手柄输入；确认震动未关闭，优先使用 USB 连接。
- **DualSense 被识别为 Xbox：** Steam Input 可能改变游戏看到的设备身份。如果完全不震，可以尝试仅为 Balatro 关闭 Steam Input 后重启；若手柄无法操作，再恢复原设置。虚拟 Xbox 身份会使用通用强度。
- **强弱不合适：** 在游戏设置中调整震动强度。
- **提交问题：** 请提供系统、游戏版本、手柄型号、USB/蓝牙、Steam Input 状态及相关日志。

## 卸载

退出游戏，删除本 mod 的 `main.lua` 和 `controller_haptics.lua` 即可。不要删除 `settings.jkr` 或数字命名的存档目录。回退旧版时，恢复备份的两个 mod 文件并重启。

## 许可证与致谢

采用 [MIT 许可证](LICENSE)，由 [KazuhaMax](https://github.com/KazuhaMax) 维护，开发过程中使用了 Claude 和 OpenAI Codex 辅助。

本仓库只包含 mod 与说明，不分发 Balatro 原始游戏代码或素材。此项目为非官方玩家 mod，与游戏开发者或发行商无隶属或背书关系，需另行拥有游戏。
