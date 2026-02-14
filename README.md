# AudioInput（macOS 语音输入）

AudioInput 是一个 macOS 菜单栏语音输入工具，使用火山引擎 ASR。

## 功能

- 按住配置的 `Command` 侧键开始录音（默认右 `Cmd`）。
- 松开后自动转写并粘贴到当前输入框。
- 录音中按 `Esc` 立即取消（不转写、不插入）。

## 本地运行

```bash
swift run AudioInput
```

启动后点击菜单栏 `AI` 图标，进入 `Settings...`（设置）填写：

- `APP_ID`
- `ACCESS_TOKEN`

并可配置：

- 触发热键（右 Cmd / 左 Cmd / 左右 Cmd）
- 最大录音时长（秒）
- 是否保留识别结果在剪贴板
- 开机自动启动
- 日志保留天数

## `.env` 迁移说明

如果 `.env` 中已有 `APP_ID` / `ACCESS_TOKEN`，仅在首次启动时作为设置默认值导入。
后续以设置窗口保存的数据为准。

## 权限要求

- 麦克风
- 辅助功能（Accessibility）
- 输入监控（部分系统版本需要）
- 通知（可选）

若未授予辅助功能/输入监控权限，全局热键和模拟粘贴可能失效。

## 结构化日志

日志以 JSON Lines 形式落盘：

- `~/Library/Logs/AudioInput/audioinput-YYYY-MM-DD.log`

会按“日志保留天数”自动清理旧日志。

## 打包 `.app`

执行：

```bash
./scripts/package_app.sh
```

产物路径：

- `dist/AudioInput.app`

说明：

- 打包脚本会自动 `swift build -c release`
- 生成的 `Info.plist` 已包含菜单栏模式（`LSUIElement=true`）和麦克风权限说明
