# DayTrace / DayTrace（中英文）

**Languages / 语言：** [English](#english) · [简体中文](#简体中文)

## English

DayTrace is a local-first macOS activity tracker. It summarizes foreground app use, sanitized website domains from Chrome, aggregate typing activity, and selected background activity. It is designed not to retain typed content, full URLs, page titles, or page contents.

> **Release notice:** Source code is licensed under [MPL-2.0](LICENSE). Public release readiness still depends on reviewing Git history for maintainer metadata and completing a clean public-repository build audit.

## What it does

- Tracks foreground app intervals and Chrome website time as a child of Chrome usage.
- Counts supported keyboard categories as aggregates through a listen-only macOS event tap; it does not build a text buffer.
- Optionally records supported NookX visible activity and NetEase audio playback as separate interval streams.
- Stores activity locally using Core Data/SQLite. No account, cloud sync, telemetry, or public service is included.
- Provides local history, insights, pause controls, backup/restore, and data deletion.

See [Privacy](docs/PRIVACY.md) and [Architecture](docs/engineering/ARCHITECTURE.md) for boundaries and limitations.

## Build and test

Requirements and reproducible commands are in [BUILDING.md](BUILDING.md). The app is a native Xcode project under `app/DayTraceSpike/`; the Chrome extension and Native Messaging host are separate components. A clean unsigned build is suitable for compile/test checks, but Input Monitoring and some macOS integrations require a correctly signed app and manual OS authorization.

## Repository map

- `app/DayTraceSpike/DayTrace.xcodeproj` — macOS app, Native Messaging host, and XCTest targets
- `extension/chrome/` — Manifest V3 extension
- `scripts/` — development installation, native-host, and release helpers
- `docs/` — product, engineering, testing, and release notes
- `design/` — source design assets

## Project status

DayTrace is under active development. Interfaces, data formats, and supported detectors may change. See [ROADMAP.md](docs/project/ROADMAP.md) for the current direction. Source licensing is governed by [MPL-2.0](LICENSE); the license does not grant rights to DayTrace trademarks or third-party materials.

## Contributing and security

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes. For vulnerability reports, see [SECURITY.md](SECURITY.md). Do not include databases, backups, screenshots containing personal activity, signing credentials, or raw keyboard data in issues or pull requests.

## License

DayTrace source code is available under the [Mozilla Public License 2.0](LICENSE). Third-party components, Apple frameworks, Chrome APIs, and trademarks remain subject to their own terms.

## 简体中文

DayTrace 是一款以本地处理为主的 macOS 活动统计应用，汇总前台应用使用时间、Chrome 网站域名、聚合键盘活动，以及部分后台活动。它不保存输入文本、完整 URL、网页标题或网页内容。

> **发布提示：** DayTrace 源码采用 [MPL-2.0](LICENSE)。公开发布前仍需审查 Git 历史中的维护者元数据，并完成干净公开仓库构建审计。

### 功能概览

- 记录前台应用区间；Chrome 网站时间作为 Chrome 使用时间的子项。
- 通过 listen-only macOS 事件监听按类别聚合支持的键盘事件，不构建文本缓冲区。
- 可选记录 NookX 可见活动和 NetEase 音频播放的独立区间。
- 使用 Core Data/SQLite 在本机存储；项目不包含账户、云同步、遥测或公共服务。
- 提供本地历史、洞察、暂停控制、备份/恢复和数据删除。

请阅读[隐私说明](docs/PRIVACY.md)和[架构说明](docs/engineering/ARCHITECTURE.md)，了解数据边界和当前限制。

### 构建、测试与仓库导航

环境要求和可复制的命令见[构建指南](BUILDING.md)。原生 App、Chrome 扩展和 Native Messaging Host 是独立组件。未签名构建适合编译和自动化测试；Input Monitoring 等 macOS 集成需要合适的签名和人工系统授权。

- `app/DayTraceSpike/DayTrace.xcodeproj`：macOS App、Native Messaging Host 与 XCTest 工程
- `extension/chrome/`：Manifest V3 扩展
- `scripts/`：开发安装、Native Host 和发布辅助脚本
- `docs/`：产品、工程、测试和发布说明
- `design/`：设计源文件

### 项目状态、贡献与安全

项目仍在开发中，界面、数据格式和支持的检测器可能变化。当前方向见[路线图](docs/project/ROADMAP.md)。源码使用 [MPL-2.0](LICENSE)；该许可证不授予 DayTrace 商标或第三方材料的权利。

贡献前请阅读[贡献指南](CONTRIBUTING.md)。漏洞报告方式见[安全策略](SECURITY.md)。请勿在 issue 或 PR 中附带数据库、备份、包含个人活动的截图、签名凭据或原始键盘数据。

### 许可证

DayTrace 源码采用 [Mozilla 公共许可证 2.0](LICENSE)。第三方组件、Apple 框架、Chrome API 和商标仍受各自条款约束。
