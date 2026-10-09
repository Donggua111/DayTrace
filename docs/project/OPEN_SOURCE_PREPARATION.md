# Open-Source Preparation Status

**Languages / 语言：** [English](#open-source-preparation-status) · [简体中文](#简体中文)

This checklist records repository readiness; it does not grant a license or
authorize publication. Last reviewed against the local tree on 2026-10-09.

## Ready or improved

- Project overview and local build instructions are documented.
- Architecture and intended privacy/data boundaries are documented.
- Contributor and vulnerability-reporting guidance exists.
- No third-party Swift package dependencies or vendored runtime libraries were
  found in the current project configuration. Runtime dependencies are Apple
  platform frameworks and Chrome extension APIs; those remain subject to their
  respective platform terms.
- Build outputs, Xcode user state, local environment files, signing material,
  and common local database files are excluded by `.gitignore`.
- The current worktree does not track local build databases or generated
  DerivedData.

## Required before public repository creation

- Select and approve an open-source license. No `LICENSE` file is included yet.
- Replace maintainer-specific Team, App Bundle ID, and Chrome extension ID
  defaults with contributor-owned configuration. Preserve the existing
  installed app's TCC identity and Native Messaging setup while doing so.
- Make the native-host install and test scripts accept a developer's own
  extension ID rather than enforcing one profile's ID.
- Review all Git history before publication. Existing commits contain the
  maintainer's commit email and personal app/team/Chrome-profile identifiers.
  No private key or high-confidence service-token pattern was found in the
  inspected current tree/history, but history has not been rewritten or
  independently scanned with a dedicated secret-scanning product.
- Confirm whether historical planning prompts and release notes should remain
  in the public source tree.
- Establish a public security contact and supported-version/response policy.
- Run XCTest when the installed DayTrace app is safely stopped; the test target
  loads the app executable and the app has a single-writer runtime guard.

## License decision guide (not a selection)

- MIT: short, permissive reuse terms with attribution and warranty disclaimer.
- Apache-2.0: permissive terms with an explicit patent grant and additional
  notice requirements.
- GPL-3.0: copyleft terms requiring covered derivative distributions to remain
  under compatible terms.

Choose based on the intended reuse and contribution model. The maintainer must
make this decision; this preparation does not create a license grant.

## 简体中文

本清单记录仓库准备情况，不授予许可证，也不等于允许公开发布。最近一次对照本地仓库检查的日期：2026-10-09。

### 已完成或已改善

- 已整理项目概览和本地构建说明。
- 已说明架构和设计中的隐私/数据边界。
- 已补充贡献与漏洞报告说明。
- 当前工程配置未发现第三方 Swift Package 依赖或随仓库分发的第三方运行库。运行依赖为 Apple 平台框架和 Chrome 扩展 API，仍需遵守相应平台条款。
- 根 `.gitignore` 已排除构建产物、Xcode 用户状态、本地环境文件、签名材料和常见本地数据库文件。
- 当前 Git 跟踪文件中没有本地 build database 或 DerivedData。

### 创建公开仓库前必须处理

- 选择并批准开源许可证；目前未添加 `LICENSE` 文件。
- 将维护者专属 Team、App Bundle ID 和 Chrome 扩展 ID 改为贡献者自行配置，并确保不影响已安装 App 的 TCC 身份和 Native Messaging。
- 修改 Native Host 安装/测试脚本，使其接受开发者自己的扩展 ID。
- 发布前审查 Git 历史。当前提交包含维护者提交邮箱及个人 App/Team/Chrome profile 标识。检查范围内未发现私钥或高置信度服务 token 模式，但没有重写历史，也未使用专用 secret scanner 做独立扫描。
- 决定是否将历史计划提示词和发布说明保留在公开源码中。
- 建立公开安全联系渠道及受支持版本/响应政策。
- 在安全停止已安装 DayTrace 后运行 XCTest；当前测试 target 会加载 App 可执行文件，而 App 有单 writer 运行时保护。

### 许可证选择参考（非决定）

- MIT：简短、宽松，要求保留署名和免责声明。
- Apache-2.0：宽松许可，并明确授予专利许可，附带额外通知要求。
- GPL-3.0：copyleft，要求受覆盖的衍生分发遵守兼容条款。

请根据希望的复用和贡献模式决定。本准备工作不代表维护者已经选择或授予任何许可证。
