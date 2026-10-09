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
- [x] The publishable branch history uses the maintainer's exact GitHub
  noreply address for both author and committer. The metadata rewrite preserved
  commit subjects, dates, and tree contents. A pre-rewrite Git bundle is
  retained locally for recovery and must not be published.
- A repository/history scan found no private-key material, high-confidence
  token patterns, or tracked user databases/backups. No dedicated secret
  scanner was available, so this is not a guarantee that all possible secrets
  were detected.
- Internal development prompts are excluded from the public tree and its Git
  history; a local archive is retained outside the repository. Product,
  architecture, testing, and release documentation remain in the public tree.
- A concrete private vulnerability-reporting channel and supported-version /
  response policy are still needed. `SECURITY.md` currently describes the
  intended handling but does not provide an actionable private contact route.
- [x] Isolated XCTest passed (143/143); Debug and Release app builds and both
  Native Host configurations built successfully. Tests used a temporary data
  root and test identity, not the installed production app or its database.

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
- [x] 可发布分支的全部历史已统一使用维护者提供的 GitHub noreply 地址作为 Author 和 Committer。元数据改写保留了提交说明、日期和 tree 内容。本地保留了改写前的 Git bundle 以供恢复，不得公开推送该备份。
- 仓库/历史扫描未发现私钥材料、高置信度 token 模式或被跟踪的用户数据库/备份。未运行专用 secret scanner，因此不能保证发现所有可能的秘密。
- 内部开发提示词已从公开工作树和 Git 历史中排除，并在仓库外保留本地归档。产品、架构、测试和发布文档仍保留在公开源码树中。
- 仍需建立可实际使用的私密漏洞报告渠道，以及受支持版本/响应政策。当前 `SECURITY.md` 描述了处理原则，但没有可操作的私密联系途径。
- [x] 隔离 XCTest 通过（143/143）；Debug、Release App 及 Native Host 的 Debug/Release 构建均成功。测试使用临时数据目录和测试身份，没有使用已安装正式 App 或其数据库。

许可证：MPL-2.0，见根目录 [LICENSE](../../LICENSE)。
