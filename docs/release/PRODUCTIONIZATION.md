# DayTrace Productionization V1

**Languages / 语言：** [English](#daytrace-productionization-v1) · [简体中文](#简体中文)

## Current identity decision

The production Mac App Bundle ID is maintainer-configured. The legacy
development Bundle ID remains the UserDefaults migration source and rollback
identity. The Native Messaging host remains `com.daytrace.spike` for
compatibility. Chrome extension IDs are assigned/configured per development
profile and must not be shared as a project constant.

The current identity map is maintained in `scripts/daytrace-identity.sh` and
mirrored by `DayTraceIdentity` for diagnostics and migration helpers. Build-time
overrides are documented in `BUILDING.md`; defaults preserve the established
production Bundle ID, Team, and extension ID. Changing the Bundle ID creates a
different TCC identity and must not replace an existing install without an
intentional migration.

## Artifact classes

1. Automation build: unsigned, used only for local build and XCTest.
2. Development installed build: Apple Development signed, used for TCC and
   real-Mac validation.
3. Distribution build: Developer ID signed, notarized, stapled, and assessed
   by Gatekeeper.

The first class must never be reported as evidence for Input Monitoring.

## Stable locations and migration

The Core Data store is already at the Bundle-ID-independent user location:
`~/Library/Application Support/DayTrace/DayTrace.sqlite`. Backups remain under
`~/Library/Application Support/DayTrace/Backups`. The existing Native Host
development location remains under the same DayTrace-owned Application Support
root. No real-user data-location migration is required in this sprint.

On first production launch, the app runs a one-time, idempotent migration of
known UserDefaults keys from the legacy development identity to the configured
production identity. Existing production values win, unknown keys are
ignored, DayTrace-owned metadata identities are remapped narrowly, and the old
store is not deleted. Activity backups remain logical and portable across
identities.

## Installation and rollback

`scripts/install-development.sh` installs to the user Applications directory,
updates the Native Host with an atomic sibling-copy/rename, and retains the
previous app bundle for rollback. It requires a verified Apple Development
signature unless `--allow-unsigned` is explicitly supplied for non-TCC local
automation.

The Native Messaging installer writes a validated manifest to the user Chrome
directory through a temporary sibling and atomic rename. It rejects arbitrary
extension IDs and never touches TCC or unrelated Chrome data.

## Signing and distribution

The project has Debug and Release configurations with marketing version `0.9.0`
and build `1`. Signing remains automatic and uses the Team configured in the
project; credentials are never stored in the repository. The current
production candidate is Apple Development signed. Developer ID signing and
notarization remain later-phase capabilities.

Use `scripts/release/build-release.sh`, `build-dmg.sh`, `notarize.sh`, and
`validate-release.sh`. By default, generated Release artifacts are written to
the stable user-level directory `~/Applications/DayTrace/ReleaseArtifacts`;
set `DAYTRACE_RELEASE_OUTPUT_DIR` to override it. The repository `release/`
directory remains ignored for ad-hoc local artifacts and is not tracked.

## Runtime safety and privacy

The app owns a kernel-held lock under its DayTrace runtime directory so two
instances cannot simultaneously checkpoint the same store or own the Unix
socket. Existing tracking accounting, Native Messaging, Unix socket, Input
Monitoring, and privacy boundaries are unchanged. Diagnostics expose health,
version, identity class, and configuration metadata, not activity history,
typed content, full URLs, or personal paths.

## Manual validation status

Signed Input Monitoring, Chrome runtime IPC, background detectors, pause,
lock/sleep lifecycle, relaunch persistence, Restore, Selective Delete, Launch
at Login, and timezone re-anchor remain real-Mac acceptance gates. No runtime
PASS is inferred from static inspection.

## 简体中文

### 当前身份配置

生产 App Bundle ID 默认保持既有 `com.wudonggua.daytrace`；旧开发 Bundle ID 用作 UserDefaults 迁移来源和回滚身份。Native Messaging Host 名称 `com.daytrace.spike` 为兼容性保留。Team、App Bundle ID 和 Chrome 扩展 ID 可按构建覆盖；改变 Bundle ID 会形成不同 TCC 身份，不应未经迁移计划替换正式安装。

### 构建产物类别

1. 自动化构建：未签名，仅用于本地构建和 XCTest。
2. 开发安装版：Apple Development 签名，用于 TCC 和真实 Mac 验证。
3. 分发版：Developer ID 签名、notarize、staple，并通过 Gatekeeper 检查。

未签名自动化构建不能作为 Input Monitoring 验证证据。

### 数据位置与迁移

Core Data SQLite 存储位于 `~/Library/Application Support/DayTrace/DayTrace.sqlite`，备份位于同目录下的 `Backups`，均不依赖 Bundle ID。首次生产身份启动会幂等迁移已知 UserDefaults 项；已有生产值优先，忽略未知 key，只窄范围映射 DayTrace 自有元数据，不删除旧 store。真实旧版 store 不存在时，不声称完成了真实旧库迁移。

### 安装、回滚与签名

`scripts/install-development.sh` 将 App 安装到用户 Applications，原子更新 Native Host，并保留上一 App 供回滚。除非明确传入 `--allow-unsigned` 做非 TCC 自动化安装，否则要求签名验证通过的 Apple Development App。Native Messaging 安装器在 Chrome 用户目录以临时同级文件和原子替换写入 manifest，不修改 TCC 或其他 Chrome 配置。脚本当前还有维护者扩展 ID 限制，独立开发者使用前需改造。

工程提供 Debug/Release 配置；发布脚本包括 `build-release.sh`、`build-dmg.sh`、`notarize.sh` 和 `validate-release.sh`。签名凭据不得存入仓库。Developer ID 和公证仍需具备相应账户配置后单独验证。

### 运行安全、隐私与人工验收

内核持有的单实例锁防止两个 DayTrace 进程同时写同一 store 或拥有同一 socket。诊断信息可以包含健康、版本和配置元数据，不应包含活动历史、输入内容、完整 URL 或个人路径。Input Monitoring、Chrome IPC、后台检测、暂停/锁屏/睡眠、重启持久化、恢复、选择性删除、登录启动和时区重新锚定仍是需要真实 Mac 验收的项目；不能从静态检查推断 PASS。
