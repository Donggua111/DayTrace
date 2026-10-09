# Contributing

**Languages / 语言：** [English](#contributing) · [简体中文](#简体中文)

Thanks for your interest in DayTrace. Contributions to project source are governed by MPL-2.0. By submitting a contribution, you agree that it may be distributed under that license; no separate CLA is currently required.

## Before proposing a change

- Read [Architecture](docs/engineering/ARCHITECTURE.md), [Privacy](docs/PRIVACY.md), and [Testing](docs/project/TESTING.md).
- Keep tracking semantics and privacy boundaries explicit. Never persist or log typed content, key sequences, full URLs, titles, page contents, audio samples, or clipboard contents.
- Avoid adding permissions, network services, dependencies, or persistence formats without a documented design decision.
- Keep changes focused and add deterministic regression tests for behavioral changes.

## Validation

Follow [BUILDING.md](BUILDING.md) for build and XCTest commands. Also run `git diff --check`, inspect the final diff, and ensure no generated files, user databases, backups, credentials, or local Xcode settings are included.

## Change proposals

Open a focused issue or pull request with the motivation, behavior change, privacy impact, tests run, and any manual macOS validation still needed. Do not attach personal activity exports or screenshots that reveal app/domain history. Security issues should be reported privately as described in [SECURITY.md](SECURITY.md).

## License and contribution terms

Project source is licensed under MPL-2.0; see [LICENSE](LICENSE). No separate contributor license agreement is currently used. Contributions must be submitted with the right to license them under MPL-2.0.

## 简体中文

感谢你关注 DayTrace。项目源码采用 MPL-2.0。提交贡献即表示你同意该贡献可按此许可证分发；目前不要求单独签署 CLA。

### 提交变更前

- 阅读[架构说明](docs/engineering/ARCHITECTURE.md)、[隐私说明](docs/PRIVACY.md)和[测试策略](docs/project/TESTING.md)。
- 明确维护跟踪语义和隐私边界；不得保存或记录输入文本、按键序列、完整 URL、网页标题/内容、音频样本或剪贴板内容。
- 未经设计决策，不增加权限、网络服务、依赖或持久化格式。
- 变更应聚焦；行为变更应配套确定性回归测试。

### 验证

按[构建指南](BUILDING.md)执行构建和 XCTest，并运行 `git diff --check`、检查最终差异。不得纳入生成文件、用户数据库、备份、凭据或本地 Xcode 设置。

### 变更建议

使用聚焦的 issue 或 pull request 说明动机、行为变化、隐私影响、已运行的测试和仍需人工验证的内容。不要附带暴露应用/网站历史的个人活动导出或截图。安全问题请按[安全策略](SECURITY.md)私下报告。

### 许可证与贡献条款

项目源码采用 MPL-2.0，详见 [LICENSE](LICENSE)。目前没有单独的贡献者许可协议；提交者须有权按 MPL-2.0 授权其贡献。
