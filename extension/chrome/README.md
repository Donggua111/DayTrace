# DayTrace Chrome Extension

**Languages / 语言：** [English](#daytrace-chrome-extension) · [简体中文](#简体中文)

This unpacked Manifest V3 extension requires only `tabs` and `nativeMessaging`.
It sends a sanitized hostname, `Browser Internal`, `Local File`, or `Unknown`.
It never sends the full URL, path, query string, title, or page content.

Load this directory from `chrome://extensions` with Developer mode enabled.
Chrome assigns the unpacked extension an ID for the local profile/package. The
generated Native Messaging manifest must allow that exact ID. Never commit a
personal Chrome profile ID or a generated manifest. The current install helper
still enforces a maintainer-specific ID and must be made configurable before
the development install flow is contributor-ready.

## 简体中文

此 Manifest V3 扩展仅请求 `tabs` 和 `nativeMessaging`。它只发送清理后的主机名或 `Browser Internal`、`Local File`、`Unknown` 状态，不发送完整 URL、路径、查询参数、标题或页面内容。

在 `chrome://extensions` 开启开发者模式并加载此目录。Chrome 会根据本地 profile/打包方式分配扩展 ID。生成的 Native Messaging manifest 必须允许该 ID。不要提交个人 Chrome profile ID 或生成的 manifest。当前安装辅助脚本仍限制维护者的扩展 ID；在改为可配置前，开发安装流程尚不适合独立贡献者直接使用。
