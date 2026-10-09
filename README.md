# DayTrace / DayTrace（中英文）

**Languages / 语言：** [English](#english) · [简体中文](#简体中文)

## English

DayTrace is a local-first macOS activity tracker. It summarizes foreground app use, sanitized website domains from Chrome, aggregate typing activity, and selected background activity. It is designed not to retain typed content, full URLs, page titles, or page contents.

> **Pre-release notice:** This repository is being prepared for an open-source release. It currently has no selected open-source license, and its Xcode signing/identity defaults and Git history still contain maintainer-specific identifiers. Do not redistribute binaries or treat the repository as release-ready until those items are resolved.

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

DayTrace is under active development. Interfaces, data formats, and supported detectors may change. See [ROADMAP.md](docs/project/ROADMAP.md) for the current direction. The project does not yet grant permission to use, modify, or redistribute the code; a license decision is pending.

## Contributing and security

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes. For vulnerability reports, see [SECURITY.md](SECURITY.md). Do not include databases, backups, screenshots containing personal activity, signing credentials, or raw keyboard data in issues or pull requests.

## License

No open-source license has been selected. Until a license is added, all rights are reserved by default; please do not assume that the code may be redistributed or reused. The maintainer will add a license after choosing one.

## 简体中文

DayTrace 是一款以本地处理为主的 macOS 活动统计应用，汇总前台应用使用时间、Chrome 网站域名、聚合键盘活动，以及部分后台活动。它不保存输入文本、完整 URL、网页标题或网页内容。

> **发布前提示：** 项目仍在准备开源发布，尚未选定开源许可证。Xcode 签名/身份默认值和 Git 历史中仍有维护者环境标识。相关问题解决前，请勿将项目视为可直接再分发的开源项目。

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

项目仍在开发中，界面、数据格式和支持的检测器可能变化。当前方向见[路线图](docs/project/ROADMAP.md)。项目尚未授予使用、修改或再分发代码的许可；许可证待维护者决定。

贡献前请阅读[贡献指南](CONTRIBUTING.md)。漏洞报告方式见[安全策略](SECURITY.md)。请勿在 issue 或 PR 中附带数据库、备份、包含个人活动的截图、签名凭据或原始键盘数据。

### 许可证

项目尚未选定开源许可证，也未包含 `LICENSE` 文件。在添加许可证前，默认保留全部权利；请勿假设代码可以复用或再分发。维护者作出选择后会添加许可证文件。
