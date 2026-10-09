# Contributing

**Languages / 语言：** [English](#contributing) · [简体中文](#简体中文)

Thanks for your interest in DayTrace. The project is still preparing for its first public contribution process; a license is pending, so please do not submit contributions until the maintainer adds one and confirms the contribution terms.

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

No project license or contributor agreement has been selected. Until that decision is made and published, the repository is not accepting reusable contributions under an open-source grant.

## 简体中文

感谢你关注 DayTrace。项目仍在准备首次公开贡献流程，许可证尚待决定；在维护者添加许可证并确认贡献条款前，请勿提交希望以开源方式复用或再分发的贡献。

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

项目尚未选定许可证或贡献者协议。在决定并发布相关条款前，仓库尚未按开源许可接受可再利用的贡献。
