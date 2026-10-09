# DayTrace Chrome Extension

**Languages / 语言：** [English](#daytrace-chrome-extension) · [简体中文](#简体中文)

This unpacked Manifest V3 extension requires only `tabs` and `nativeMessaging`.
It sends a sanitized hostname, `Browser Internal`, `Local File`, or `Unknown`.
It never sends the full URL, path, query string, title, or page content.

Load this directory from `chrome://extensions` with Developer mode enabled.
Chrome assigns the unpacked extension an ID for the local profile/package. The
generated Native Messaging manifest must allow that exact ID. Never commit a
personal Chrome profile ID or a generated manifest. Set
`DAYTRACE_CHROME_EXTENSION_ID` to the ID shown by your local Chrome profile
before using the development install helper.

## 简体中文

此 Manifest V3 扩展仅请求 `tabs` 和 `nativeMessaging`。它只发送清理后的主机名或 `Browser Internal`、`Local File`、`Unknown` 状态，不发送完整 URL、路径、查询参数、标题或页面内容。

在 `chrome://extensions` 开启开发者模式并加载此目录。Chrome 会根据本地 profile/打包方式分配扩展 ID。使用开发安装辅助脚本前，将 `DAYTRACE_CHROME_EXTENSION_ID` 设为本机显示的 ID；生成的 Native Messaging manifest 会允许该 ID。不要提交个人 Chrome profile ID 或生成的 manifest。
