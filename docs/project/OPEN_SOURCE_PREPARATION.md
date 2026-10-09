# Open-Source Preparation Status

**Languages / 语言：** [English](#open-source-preparation-status) · [简体中文](#简体中文)

This checklist records repository readiness and does not itself authorize
publication. Last reviewed against the local tree on 2026-10-09.

## Ready or improved

- Project overview and local build instructions are documented.
- Architecture and intended privacy/data boundaries are documented.
- Contributor and vulnerability-reporting guidance exists.
- No third-party Swift package dependencies or vendored runtime libraries were
  found in the current project configuration. Runtime dependencies are Apple
  platform frameworks and Chrome extension APIs; those remain subject to their
  respective platform terms.
- [x] MPL-2.0 adopted; full text is included in the root `LICENSE`.
- Build outputs, Xcode user state, local environment files, signing material,
  and common local database files are excluded by `.gitignore`.
- The current worktree does not track local build databases or generated
  DerivedData.

## Remaining before a safe public push

- [x] App Bundle ID, signing Team, and Chrome extension ID accept build-time
  overrides while preserving production defaults.
- Git history contains the maintainer's personal email in all 15 commits. Do
  not push publicly unless the owner explicitly approves history rewriting or
  accepts this exposure. No private key or high-confidence service-token
  pattern was found in the inspected history; no dedicated secret scanner ran.
- Confirm whether historical planning prompts and release notes should remain
  in the public source tree.
- Establish a public security contact and supported-version/response policy.
- Run XCTest when the installed DayTrace app is safely stopped; the test target
  loads the app executable and the app has a single-writer runtime guard.

License: MPL-2.0. See [LICENSE](../../LICENSE).

## 简体中文

本清单记录仓库准备情况，不等于已获准公开推送。最近一次对照本地仓库检查的日期：2026-10-09。

### 已完成或已改善

- 已整理项目概览和本地构建说明。
- 已说明架构和设计中的隐私/数据边界。
- 已补充贡献与漏洞报告说明。
- 当前工程配置未发现第三方 Swift Package 依赖或随仓库分发的第三方运行库。运行依赖为 Apple 平台框架和 Chrome 扩展 API，仍需遵守相应平台条款。
- [x] 已采用 MPL-2.0，根目录包含完整 `LICENSE`。
- 根 `.gitignore` 已排除构建产物、Xcode 用户状态、本地环境文件、签名材料和常见本地数据库文件。
- 当前 Git 跟踪文件中没有本地 build database 或 DerivedData。

### 安全公开推送前仍需处理

- [x] App Bundle ID、签名 Team 和 Chrome 扩展 ID 可按构建覆盖，且保留正式默认值。
- Git 历史 15 个提交都包含维护者个人邮箱。未经明确授权重写历史或接受该暴露前，不应公开推送。历史中未发现私钥或高置信度 token 模式；未运行专用 secret scanner。
- 决定是否将历史计划提示词和发布说明保留在公开源码中。
- 建立公开安全联系渠道及受支持版本/响应政策。
- 在安全停止已安装 DayTrace 后运行 XCTest；当前测试 target 会加载 App 可执行文件，而 App 有单 writer 运行时保护。

许可证：MPL-2.0，见根目录 [LICENSE](../../LICENSE)。
