# DayTrace Engineering Decisions

**Languages / 语言：** [English](#daytrace-engineering-decisions) · [简体中文](#简体中文)

## Timeline V2: aggregate canonical, intervals detailed

Status: accepted for Internal Beta foundation

Daily app, website, and typing records remain the canonical source for totals,
Dashboard, menu bar, history aggregates, and analytics. Timeline V2 adds a
separate Core Data interval layer used only for chronological detail and
derived Chrome gaps.

The interval layer stores stable app identity/display metadata, sanitized
Chrome domains, local date keys, timestamps, durations, and open-state recovery
metadata. It never stores full URLs, titles, content, paths, queries, text,
clipboard data, screenshots, key codes, key sequences, or keyboard history.

Intervals are positive, non-overlapping presentation units split at local
midnight. Checkpointing updates the same open record and closes records at
foreground transitions, lock, sleep, pause, termination, and calendar
boundaries. Relaunch closes stale open rows at the last durable end and starts a
new interval. A Chrome website row is valid only inside a Chrome app interval;
unattributed Chrome time is derived and is never persisted independently.

Detailed Timeline storage defaults to on. Turning it off stops new interval
records while aggregates continue and existing detail remains available. The
dedicated delete action removes interval entities only; Delete All removes both
layers and reanchors runtime state. Aggregate export remains backward
compatible unless detailed timeline export is explicitly selected. Backups use
a versioned envelope and recognize earlier versions without attempting restore.

No public network, cloud, database migration framework, or production installer
is introduced by this decision.

Validation evidence: the pre-Timeline migration fixture retains App, Website,
Typing, and Typing-App aggregate data while creating no interval records. A
real legacy production store is not available, so no real old-store migration
PASS is claimed.

## Background Activity V1: separate intervals, honest detector signals

Status: accepted for Internal Beta foundation

Background activity is represented by a separate interval-only entity and a
separate History lane. It is not a second interpretation of foreground usage:
overlapping background intervals are allowed across different apps/detectors,
but none contributes to the canonical foreground total or Chrome website
parent. A shared coordinator polls detectors at a low cadence and persists via
the existing checkpoint path.

V1 supports two inspected identities only. NookX uses public visible-window
metadata without reading window content. NetEase uses the public CoreAudio
process output-running property without capturing audio. Process existence
alone is not treated as activity, and unavailable signals stay unavailable.
No private MediaRemote API or new sensitive permission is allowed.

Background intervals are exported only as metadata when detailed export is
selected and can be deleted independently. The backup envelope is version 3
because its detailed payload now includes background intervals. Migration from
the current Timeline V2 schema is additive; no real prior production dataset
exists, so a real old-store migration test remains unavailable.

## Product Completion V1: durable local control

Status: implemented for Internal Beta

Analytics V3 remains a pure read-side layer. It computes hourly distributions,
sessions, transitions, and daily trends from existing aggregates and Timeline
records without adding event-level persistence. Restore is replace semantics,
with strict preflight validation, a safety backup, one Core Data transaction,
and runtime re-anchoring. Selective deletion is date-range based and keeps
unselected datasets intact; App Usage deletion is coupled to website and
detailed Timeline children.

Integrity checks are manual and privacy-safe. Only deterministic stale-open
interval repair is automatic; aggregate values are never guessed or rewritten.
Diagnostics export health metadata only. Exact Category Rules and Hide Identity
are presentation metadata, distinct from the deferred Exclude Tracking mode.

## Productionization V1: identity and installation

Status: implemented as local infrastructure; final production identity pending

- Use a stable, developer-owned production Mac App Bundle ID.
- Retain `com.daytrace.spike` as the legacy Bundle ID for UserDefaults
  migration and controlled rollback.
- Keep the Native Messaging host name `com.daytrace.spike` for compatibility.
- Treat Chrome extension IDs as local profile/package configuration, not as a
  shared project identity.
- Keep activity data and backups in Bundle-ID-independent Application Support
  locations.
- Migrate only known UserDefaults keys on a future identity cutover, preserving
  production precedence and the legacy store.
- Keep unsigned automation, signed Development, and Developer ID Distribution
  artifacts distinct.
- Never modify TCC databases or store Apple credentials in source.

## 简体中文

### Timeline V2：聚合为规范数据，区间用于明细

状态：Internal Beta 基础架构已接受。

App、网站和输入活动每日记录仍是 Dashboard、菜单栏、历史汇总和分析的总量来源。Timeline V2 是独立的 Core Data 区间层，只用于时间顺序明细和 Chrome 未归属时间的派生计算。区间保存稳定身份/展示元数据、本地日期键、起止时间、时长和开放状态恢复信息；Chrome 网站只保存清理域名。不保存完整 URL、标题、内容、路径、查询、剪贴板、截图、键码、键序列或键盘历史。

有效区间为正时长、不重叠，并按本地午夜切分。状态转换、锁屏、睡眠、暂停、退出和日历边界会关闭区间；checkpoint 更新同一开放记录。重新启动时只恢复到最后持久化边界。网站区间必须位于 Chrome 父区间内；未归属时间运行时派生、不单独持久化。停用 Timeline 会停止新明细但保留聚合和现有历史；可单独删除详细记录。聚合导出默认保持兼容，详细导出需明确选择。

迁移验证使用旧 Timeline 前的确定性 Core Data fixture，确认 App、Website、Typing、Typing-App 聚合保留且新建区间为空。没有真实旧版生产数据库，因此不宣称真实旧库迁移 PASS。

### Background Activity V1：独立区间，诚实表达检测信号

状态：Internal Beta 基础架构已接受。

后台活动独立记录为 History 中的一条区间轨道，不是前台使用的另一种解释。不同检测器的后台区间可以重叠，但不加入规范前台总量或 Chrome 网站父区间。共享 coordinator 以低频率轮询，通过现有 checkpoint 持久化。

V1 仅支持已检查的 NookX 与 NetEase 身份：NookX 读取公开可见窗口元数据，不读窗口内容；NetEase 使用公开 CoreAudio 进程输出状态，不采集音频。仅进程存在不代表活动；信号不可用时保持 unavailable。不会使用私有 MediaRemote 或新增敏感权限。详细导出可按选择包含后台区间元数据，且可单独删除。备份 envelope 为 v3。没有真实旧生产数据时，旧库迁移仍不可用。

### Product Completion V1：本地持久化控制

状态：Internal Beta 已实现的本地能力。

Analytics V3 是纯读取分析层，从现有聚合和 Timeline 计算小时分布、会话、切换和每日趋势，不添加事件级持久化。恢复采用 Replace 语义：严格预检、先建立安全备份、单一 Core Data 事务替换并重新锚定运行状态。按日期范围删除会保留所选范围外数据。完整性检查为手动且隐私安全；自动修复仅关闭过期开放区间，不猜测或重写聚合。诊断导出只包含健康元数据。Exact Category Rules 和 Hide Identity 是展示元数据；Exclude Tracking 仍延期。

### Productionization V1：身份与安装

状态：本地安装基础设施已实现；对外生产身份仍需配置。

- 生产 Bundle ID 应稳定并由开发者自有。
- 保留 `com.daytrace.spike` 旧 Bundle ID 作为 UserDefaults 迁移和受控回滚来源。
- Native Messaging Host `com.daytrace.spike` 为兼容性保留。
- Chrome 扩展 ID 是本地 profile/package 配置，不是共享项目身份。
- 数据与备份留在不依赖 Bundle ID 的 Application Support 路径。
- 身份切换只迁移已知 UserDefaults key，保持生产值优先和旧 store 不删除。
- 自动化未签名、Apple Development 签名和 Developer ID 分发产物必须区分。
- 不得修改 TCC 数据库或将 Apple 凭据存进源码。
