# DayTrace Architecture

**Languages / 语言：** [English](#daytrace-architecture) · [简体中文](#简体中文)

Status: implementation snapshot; verify current behavior against source/tests
Scope: tracking capabilities, local persistence, and product surfaces built
over the privacy boundary

This document describes the implementation boundary and design decisions. It
is not a claim that every real-Mac integration has passed on the current
revision; see the test record for validation evidence. Product surfaces such
as History, menu bar, launch-at-login, export, and data deletion are layered on
the tracking and privacy boundaries below.

## Runtime topology

```text
DayTrace macOS App
├── ForegroundTracker
├── TypingCounter
├── DomainTracker
├── UsageStore
├── UnixSocketBridge
├── SwiftUI Dashboard + History + native Settings scene
└── Menu bar summary

Chrome Extension
  → Chrome Native Messaging Host (stdio)
  → user-only Unix domain socket
  → DayTrace UnixSocketBridge
  → DomainTracker
```

The topology is local-only. There is no TCP listener, LAN listener, public
backend, account service, cloud sync, or persistent message queue.

## Local persistence

`UsageStore` is the single persistence boundary for the current product data.
It receives aggregate foreground intervals, sanitized Chrome domain intervals,
and aggregate typing categories. It uses a native Core Data model (the app
continues to support macOS 13, so SwiftData is not used here) backed by a
user-level SQLite store under the DayTrace Application Support directory. The
runtime trackers remain responsible for event handling; they do not write
database records directly.

The persisted daily records are:

- `AppUsageDailyRecord`: local day key, app identity, and seconds.
- `WebsiteUsageDailyRecord`: local day key, Chrome identity, sanitized domain,
  and seconds.
- `TypingDailyRecord`: local day key, metric version, category counts, typing
  sessions, and aggregate active typing seconds.
- `TypingAppDailyRecord`: local day key, app identity, and aggregate typing
  category counts.

Timeline V2 is a separate detail layer and never replaces the daily records:

- `AppUsageIntervalRecord`: stable interval ID, local `dateKey`, start/end,
  duration, open-state recovery flag, and stable app identity/display name.
- `WebsiteUsageIntervalRecord`: stable interval ID, local `dateKey`, start/end,
  duration, open-state recovery flag, Chrome identity, sanitized domain, and
  optional parent app interval ID.

Background Activity V1 is a separate interval-only stream:

- `BackgroundActivityIntervalRecord`: stable interval ID, local `dateKey`,
  start/end, duration, open-state recovery flag, app identity, activity kind,
  and detector identifier.

Background intervals are never merged into foreground app totals, Chrome
website parent time, typing metrics, or comparisons. The selected-day History
lane and Dashboard card derive per-app/per-kind summaries from these intervals;
there is no duplicate daily background aggregate entity.

Only valid positive intervals are persisted. Intervals are split at local
midnight and never cross a stored `dateKey`. One open interval per active
stream is checkpointed in place; transitions close the current row and create
a new row. On relaunch, stale open rows are closed at their last durable end
rather than extended to launch time. Chrome child rows are written only inside
Chrome app intervals. Unattributed Chrome time is derived at read time as
non-negative gaps; no independent gap stream is persisted.

The Timeline view queries only the selected local day and presents a value-type
snapshot to SwiftUI. Existing aggregate records remain the source for
Dashboard totals, History totals, menu bar totals, typing analytics, and
website reconciliation.

All durations are stored as `Double` seconds. Intervals crossing a local
midnight are split into the relevant local calendar day keys. Website time is
stored separately and never added to total app usage.

`BackgroundActivityCoordinator` uses one shared low-frequency detector poll and
the existing checkpoint path. It does not add a second persistence loop or
per-second Core Data writes. NookX (`com.monsterwl.NookX`) is inspected through
public visible-window metadata only; NetEase Cloud Music
(`com.netease.163music`) uses the public CoreAudio process output-running
property. No titles, coordinates, pixels, window content, audio samples, or
private MediaRemote API are read. Process existence alone is not activity, and
an unavailable signal remains unavailable. No new Screen Recording,
Accessibility, Full Disk Access, microphone, or network permission is added.

Checkpoints run periodically while the app is active and during app
termination. Upserts are idempotent, so repeated checkpoints do not duplicate
intervals. A failed save rolls back only the pending Core Data transaction;
runtime aggregates and interval progress remain available for a later retry.
The store reports this recoverable state as degraded rather than blocking
tracking. If the store cannot be opened, the runtime trackers remain usable and
the error is surfaced through the store status; tracking does not crash or
silently substitute a second persistence path.

The daily record uniqueness keys are:

- App: `dateKey + bundleIdentifier`.
- Website: `dateKey + browserBundleIdentifier + domain`.
- Typing: `dateKey + metricVersion`.
- Per-app typing: `dateKey + bundleIdentifier + metricVersion`.

On load/checkpoint, legacy duplicate rows are normalized to one deterministic
canonical row using the greatest aggregate value. They are never blindly
summed, which prevents a repeated or partially migrated row from inflating
usage.

## Runtime identities

The Native Messaging host name is a protocol identity shared by the Chrome
service worker and the generated user-level host manifest. A contributor's
unpacked Chrome extension ID is profile/package-specific and must be configured
for that developer; it must not be copied from another user's profile. The app
Bundle ID is also tied to the developer's signing/TCC identity. Existing
production identity defaults are retained for compatibility, with build-time
overrides available for app Bundle ID, signing Team, and extension ID. Changing
the Bundle ID creates a distinct TCC identity. See [BUILDING.md](../../BUILDING.md).

## Foreground usage

`ForegroundTracker` is the source of primary usage time.

- The frontmost App is identified by a stable bundle identifier. If macOS does
  not provide one, the tracker uses an `unknown-process-<runtime>-pid-<pid>`
  fallback that is stable only within that tracker runtime. A later launch
  therefore cannot merge unrelated processes merely because a PID was reused.
  Display name is presentation metadata and may change without splitting the
  same identified app's aggregate.
- Foreground intervals are event-driven and non-overlapping.
- Sleep, lock, and paused intervals are excluded.
- The loginwindow identity is never recorded as a normal app.
- App usage is the parent usage layer.
- Website usage never increases total Mac usage.

The Internal Beta foundation does not change this definition. A wake event is
not treated as an unlock: if the interactive session is still inactive, the
tracker remains locked and does not start an interval. A session-active or
screen-unlocked event performs a fresh frontmost-app query before resuming.

The persistence layer only accepts closed intervals and a current interval
snapshot at checkpoint time. Lock, sleep, and pause transitions close the
active interval before persistence can consume it; unlocking or wake resumes a
fresh interval.

When macOS reports a system time-zone, calendar-day, or system-clock change,
the active interval is closed at the event timestamp and the transition is
checkpointed before the UsageStore adopts the new calendar. Tracking then
re-anchors at the current frontmost app if the session is awake and active.
Previously stored aggregate durations are not re-counted or rewritten merely
because the system calendar changed.

Daily records use the local calendar day observed when the usage was recorded.
The stored `dateKey` is historical and immutable; it has no retroactive
reinterpretation when the system time zone changes. A time-zone change closes
the old interval and starts a new interval under the new local calendar.

## Typing privacy boundary

`TypingCounter` listens through a listen-only Core Graphics event tap.

The Event Tap lifecycle is owned by a dedicated serial event queue and the
RunLoop created on that queue. Creation, source registration, re-enable after
timeout, source removal, and Mach-port invalidation all happen on that same
RunLoop. Callers do not remove the source from their own RunLoop; `stop()` only
marks the lifecycle as stopping and schedules cleanup with
`CFRunLoopPerformBlock` followed by `CFRunLoopWakeUp`. This prevents a live
`CFRunLoopRun()` from being stranded behind work queued to the same dispatch
queue and avoids cross-thread access to the Event Tap objects.

Lifecycle states are coordinated separately from the RunLoop-owned objects:

```text
stopped → starting → running → stopping → stopped
```

If a stop request arrives while creation is still in progress, the creation
path observes the stopping state and cleans up the newly created tap before
entering the run loop. A start request received while stopping is retained as
one pending restart and runs only after the old tap has been invalidated. The
callback retains no ownership of the counter; the active event-queue run-loop
block keeps the counter alive until cleanup has invalidated the tap.

Application termination is ordered as: stop accepting new typing events,
preserve the aggregate state already accepted, perform the final UsageStore
checkpoint, then stop the Unix socket and finish Event Tap cleanup on its own
run loop. This coordination is bounded and never waits with a sleep, busy
loop, or indefinite retry.

The processing boundary is:

```text
keyDown
  → transient classification
  → aggregate count
  → discard event detail
```

DayTrace does not store or reconstruct typed characters, Unicode text, key
sequences, text buffers, or keyboard history. Input Monitoring is used for
listen-only counting; Accessibility, Full Disk Access, and Screen Recording are
not substitutes or additional requirements.

## Chrome website attribution

The extension sends only a sanitized hostname token or an approved internal
state such as `Browser Internal`, `Local File`, or `Unknown`.

The native boundary rejects payloads that contain unexpected fields and does not
accept full URL, path, query, title, or page-content data. Website time is
counted only while Chrome is the foreground parent App.

Current hostname handling is intentionally sanitized-hostname based. Public
Suffix List and registrable-domain aggregation are not part of this frozen
boundary.

## IPC boundary

The DayTrace App owns a user-only Unix domain socket at the current local
Application Support path. The Native Messaging Host connects to it only when
forwarding a validated domain event.

The current spike boundary intentionally has no:

- general IPC framework,
- persistent queue,
- retry subsystem,
- repository abstraction,
- TCP/LAN/public listener,
- domain persistence layer.

When the App is unavailable, the Native Messaging Host fails quickly and does
not cache domain messages.

The selected-day Timeline projection combines durable interval rows with the
current in-memory continuation. If a checkpoint row and its live continuation
share an ID, the projection keeps the newest durable end rather than showing a
stale shorter row. Live rows are filtered by the selected local `dateKey`, so
an interval crossing midnight cannot leak into the following day. The current
model intentionally does not add Core Data index metadata: the pre-Timeline
migration fixture must remain compatible, and selected-day fetches are already
constrained by `dateKey`.

## Migration validation status

The available development SQLite store was copied with its SQLite sidecars to
a temporary test location and opened with an integrity check. It contained the
current schema and zero aggregate rows, so it is not an old compatible store.
The automated genuine pre-Timeline fixture preserves App, Website, Typing, and
Typing-App aggregate records and leaves both interval entities empty after
migration. REAL OLD-STORE MIGRATION TEST NOT AVAILABLE: no prior
production/legacy persistence dataset exists to migrate. Duplicate logical
rows, when encountered during load/checkpoint, are normalized to the greatest
existing aggregate rather than blindly summed.

The current schema adds `BackgroundActivityIntervalRecord` as an additive
lightweight migration. The pre-background fixture preserves daily aggregates
and Timeline V2 intervals while producing an empty background stream. No
duplicate migration ledger or separate persistence repository is introduced.

## UI and localization

The current App uses native SwiftUI `WindowGroup` and `Settings` scenes.

- Dashboard is user-facing and hides technical diagnostics.
- Diagnostics remain under Advanced Settings.
- Follow System, 简体中文, and English are supported.
- User-facing strings are stored in `Localizable.xcstrings`.

The UI is not a permission to expand the tracking model or introduce storage.
Advanced Diagnostics also exposes the persistence health state. A transient
save failure is reported as degraded while runtime collection continues; a
later successful checkpoint returns the store to healthy.

## Product surfaces over aggregates

History queries the existing local-day records and combines them with the
current runtime snapshot for the active day. It supports today, yesterday,
rolling seven and 30 days, the current week, and the current month. A small
pure analytics layer derives safe comparisons, averages, heatmap cells, and
meaningful change summaries; no event history or second usage persistence
layer is introduced.

The menu bar uses one long-lived AppKit `NSStatusItem` controller and exposes
only a compact total/typing summary, tracking pause/resume, dashboard/settings
actions, and a display-mode preference. Its presentation-only live refresh is
kept at one second; real-Mac refresh validation remains a manual gate. Launch
at login uses `SMAppService.mainApp`; it does not create a custom helper or
background service.

Export produces aggregate-only JSON containing app, sanitized website, and
typing metrics. Delete All Activity Data removes the four current aggregate
entities, clears in-memory runtime aggregates, and leaves the stable app and
Native Messaging identities unchanged.

Pins and App categories are display metadata stored separately in UserDefaults;
they never modify bundle/domain identity or historical usage values. Optional
backups wrap the existing aggregate export in a versioned JSON envelope under
the user Application Support directory and prune only DayTrace-managed files.
Restore/import is intentionally deferred until transactional replacement and
rollback semantics are specified.

Detailed export additionally includes background interval metadata only when
requested. Background-only deletion removes only the background interval
entity; Delete All removes it with the rest of local activity data. The backup
envelope is version 3 to reflect this additive detailed payload.

Dashboard refreshes reuse one live snapshot per displayed timestamp and cache
resolved application icons. These are presentation optimizations only; they do
not alter tracker event handling or persisted values.

## Source organization baseline

The current physical source container remains `app/DayTraceSpike/` to avoid a
broad directory move in Foundation Sprint 1. The formal Xcode identity is:

```text
Project: DayTrace.xcodeproj
App target/module: DayTrace
Test target: DayTraceTests
Native host target: DayTraceNativeHost
```

Generated build output and Xcode user state are excluded by `.gitignore`.

## Explicit non-goals

The following are not part of this architecture freeze:

- per-entity event-level charts and trend persistence,
- additional background detector integrations beyond the V1 NookX and NetEase
  identities,
- automatic category rules and privacy zones,
- account or cloud sync,
- public networking,
- AI-derived classification.

## Product Completion V1 decisions

Product analytics is a pure transformation layer over loaded Timeline and
daily aggregate snapshots. Hourly activity splits intervals at local hour
boundaries; sessions are continuous foreground intervals; transitions count
adjacent changes between stable App identities. These descriptive metrics do
not infer focus or productivity.

Restore is explicit Replace All Activity Data, not merge import. A validated
backup is parsed completely before a safety backup and one controlled Core Data
save. Runtime cursors are cleared and trackers are re-anchored after success.
Recognized backup versions 1–3 are accepted when their available datasets are
valid; missing newer datasets remain empty rather than being fabricated.

Range deletion is dataset-specific. App Usage deletion is coupled to Website
Usage and detailed Timeline for the same date range to avoid orphaned child
accounting. Integrity checks are manual and return Info/Warning/Error findings;
only stale open intervals have a deterministic repair path.

Exact Category Rules affect display metadata only, with manual App assignment
taking precedence over exact rules. Hide Identity is separate from Exclude
Tracking and currently changes normal presentation only. Exclude Tracking and
entity-specific historical deletion are deferred until their runtime and
identity semantics have dedicated regression coverage.

Diagnostic export is versioned and health-only by default: it contains build,
permission, subsystem, persistence, detector, and record-count metadata, but
no activity lists, URLs, domains, Timeline rows, paths, or typed content.

## Productionization V1 decisions

The production App Bundle ID is maintainer-configured; the legacy development
identity remains the migration source. The Native Messaging host remains
`com.daytrace.spike` for protocol compatibility. App and extension identifiers
must be configured for each contributor and are not portable profile data.

The Core Data store and backups use user Application Support paths that do not
depend on the Bundle ID. `DayTracePreferencesMigration` copies only known
DayTrace settings from the legacy domain, is idempotent, preserves newer
production values, narrowly remaps only DayTrace's own old metadata identity,
and never deletes the old store. A kernel-held user-only runtime lock prevents
multiple writers and Unix socket owners across legacy and production identities.

Automation, Development, and Distribution artifacts are separate classes.
Release tooling never embeds credentials, and missing Developer ID or Notary
credentials leave distribution as pending rather than being reported as
successful.

## System events, attribution, and interval time model

Foreground state is event-driven: `ForegroundTracker` observes AppKit workspace
activation, sleep/wake, active-session changes, screen lock/unlock notifications,
and system calendar/time changes. It records a frontmost app only while tracking
is enabled and the session is awake and active. These notifications are OS
signals, not a guarantee that every transition is delivered under every system
condition; lifecycle behavior is covered by deterministic tests and named
real-Mac checks.

Attribution has four distinct lanes:

1. **Foreground app** is the primary, non-overlapping usage lane.
2. **Website** is a sanitized Chrome hostname child and accrues only while
   Chrome is foreground. It never adds to total Mac usage.
3. **Typing** is a separate aggregate metric, attributed to the foreground app
   observed when each supported key-down is classified.
4. **Background activity** is an overlapping, interval-only lane for supported
   detectors. It is never added to foreground or website totals.

Intervals carry a stable ID, local date key, start/end, duration, and open-state
recovery metadata. Runtime intervals are checkpointed in place; transitions
close one interval and begin another. Day boundaries split intervals according
to the current local calendar. Stale open intervals are recovered at their
last durable end rather than extended across downtime. Daily aggregate records
remain canonical for totals; Timeline rows provide detail and do not replace or
recompute those canonical aggregates.

## System event monitoring and lifecycle

`TypingCounter` uses `CGEvent.tapCreate` with `.listenOnly` and a key-down-only
event mask. CoreGraphics preflight is used for the Event Tap permission path;
IOHID permission status is diagnostic, not a gate overriding a functioning
tap. Event Tap and RunLoop objects are owned by a dedicated serial queue. Tap
timeouts are re-enabled; app activation rechecks permission and attempts
recovery. Events are transiently classified and only aggregate category,
foreground app identity, and timestamp cross into persistence.

`AppDelegate` acquires a kernel-backed advisory lock before the app starts its
tracking services. A competing process exits before creating another writer.
Normal termination quiesces typing, checkpoints the store, closes background
intervals, and stops IPC/Event Tap resources. This protects a single local
writer; it is not a distributed lock or a data-encryption feature.

## Chrome Native Messaging and Unix socket IPC

The Manifest V3 extension requests `tabs` and `nativeMessaging`; it has no broad
host permission. The service worker transiently reads the active tab URL only
to derive a hostname or one of the approved states (`Browser Internal`,
`Local File`, `Unknown`). It sends a length-prefixed Chrome Native Messaging
message to the registered stdio host. The host validates an exact small schema,
sanitizes the domain token, and forwards only that token through a user-level
Unix domain socket. The app validates the schema and hostname again before
updating `DomainTracker`.

The socket is local-only, created under the user's Application Support area
with restrictive directory/socket permissions. There is no TCP listener,
message queue, or domain persistence in the host. If the app is unavailable,
the host rejects quickly; it does not cache or retry domain events. Host name,
extension ID, and app Bundle ID are separate identities and must be configured
consistently for a developer's environment.

## Core Data, backups, and recovery

`UsageStore` owns a programmatically defined Core Data model backed by SQLite
under the user's Bundle-ID-independent Application Support directory. App,
website, typing, Timeline, and background records use aggregate or interval
granularity; raw event streams are not persisted. Uniqueness constraints and
normalization prevent duplicate logical rows from being blindly summed.

Checkpointing runs every 30 seconds and on important transitions/termination.
Runtime progress cursors advance only after a successful save, allowing failed
saves to be retried without losing the pending delta. Restore uses a versioned
JSON envelope, validates before changing data, creates a safety backup, and
replaces supported datasets in a transaction; it is not a merge. Backup
contents can include aggregate and, when selected, detailed interval metadata.
Real legacy-store migration evidence is unavailable where no prior-schema
fixture/store exists; this must not be represented as a migration pass.

## Performance engineering

The current code uses event notifications for foreground changes, one shared
two-second refresh cadence for the supported background detectors, and a
30-second persistence checkpoint. Background process discovery uses targeted
`runningApplications(withBundleIdentifier:)` lookup rather than enumerating all
apps. Snapshot/icon caching and delta-based accumulation are used in the
presentation and persistence paths. These are implementation choices, not a
published CPU, energy, memory, or battery guarantee. Performance claims require
repeatable measurements under documented conditions; no benchmark result is
inferred from the presence of a timer or an optimization in source.

The menu-bar controller has a one-second refresh timer only when the selected
display mode requires a live value; this refresh updates presentation, not the
persistence cadence. This code fact alone is not evidence of measurable load.

## 简体中文

### 系统事件、归属和区间时间模型

前台状态由事件驱动：`ForegroundTracker` 监听 AppKit workspace 应用激活、睡眠/唤醒、会话活跃状态、锁屏/解锁通知，以及系统日历和时间变化。只有跟踪已启用且会话处于唤醒、活跃状态时才记录前台应用。这些是操作系统信号，不保证所有环境下都能交付每一次状态变化；生命周期由确定性测试和命名的真实 Mac 检查覆盖。

归属分为四条独立数据通道：

1. **前台应用**是主要且不重叠的使用时间通道。
2. **网站**是清理后的 Chrome 主机名子项，只有 Chrome 在前台时才累计，不增加 Mac 总使用时间。
3. **输入活动**是独立聚合指标，按分类时观察到的前台应用归属支持的 key-down 事件。
4. **后台活动**是支持检测器的可重叠区间通道，不计入前台或网站总量。

区间包含稳定 ID、本地日期键、起止时间、时长和开放状态恢复元数据。运行中的区间会原位 checkpoint；状态转换关闭旧区间并开启新区间。跨日区间按当前本地日历切分。恢复时，过期开放区间在最后一次可靠持久化的结束点关闭，不延长覆盖停机时间。每日聚合记录仍是总量的规范来源；Timeline 仅提供明细，不替代或重新计算规范聚合。

### 系统事件监听与生命周期

`TypingCounter` 使用 `CGEvent.tapCreate` 创建 `.listenOnly`、仅关注 key-down 的 Event Tap。CoreGraphics preflight 用于判断 Event Tap 的权限路径；IOHID 权限状态仅作诊断，不能推翻已正常运行的 tap。Event Tap 和 RunLoop 对象由专用串行队列持有。tap 超时后会重新启用；应用再次激活时会重新检查权限并尝试恢复。事件仅短暂分类，持久化边界只接收类别聚合、前台应用身份和时间戳。

`AppDelegate` 在启动跟踪服务前获取基于内核的 advisory lock。竞争进程会在创建第二个 writer 前退出。正常退出时先停止接收新键盘事件，再 checkpoint，关闭后台区间并停止 IPC/Event Tap 资源。这是单机单 writer 保护，不是分布式锁或数据加密功能。

### Chrome Native Messaging 与 Unix Socket IPC

Manifest V3 扩展只请求 `tabs` 和 `nativeMessaging`，没有宽泛 host permission。Service Worker 只为提取主机名或有限状态（`Browser Internal`、`Local File`、`Unknown`）而临时读取活动标签页 URL。它将带长度前缀的 Chrome Native Messaging 消息发送给 stdio Host。Host 校验严格的小型 schema、清理域名 token，再通过用户级 Unix domain socket 仅转发该 token。App 会再次校验 schema 与 hostname 后才更新 `DomainTracker`。

Socket 仅本机使用，位于用户 Application Support 目录，并使用受限目录和 socket 权限。没有 TCP listener、消息队列，也不由 Host 持久化域名。App 不可用时 Host 会快速拒绝，不缓存或重试 domain 事件。Host 名称、扩展 ID 和 App Bundle ID 是不同身份，必须在开发者自己的环境中协调配置。

### Core Data、备份与恢复

`UsageStore` 持有以代码定义的 Core Data 模型，并使用 SQLite 存储于不依赖 Bundle ID 的用户 Application Support 目录。App、网站、输入活动、Timeline 和后台记录均为聚合或区间粒度；不会持久化原始事件流。唯一性约束和规范化逻辑防止重复逻辑行被盲目累加。

常规 checkpoint 每 30 秒执行一次，并在重要状态转换和退出时执行。只有保存成功后运行进度游标才会前移，因此失败保存可以重试而不丢失待写增量。恢复使用带版本的 JSON envelope，先验证数据，再创建安全备份，并在事务中替换支持的数据集；不是合并操作。备份可包含聚合数据，以及在用户选择详细备份时包含区间元数据。若不存在真实旧版 schema 数据或夹具，就没有真实迁移证据；不得将其表述为迁移通过。

### 性能工程

当前实现使用事件通知处理前台变化、一个共享的两秒后台检测刷新周期，以及 30 秒持久化 checkpoint。后台进程发现使用按 Bundle ID 定向的 `runningApplications(withBundleIdentifier:)` 查询，不再遍历所有应用。展示和持久化路径使用快照/图标缓存及增量累计。这些是实现选择，不是 CPU、能耗、内存或电池续航保证。性能结论需要在记录测试条件的前提下重复测量；不能仅根据源码中存在 timer 或优化代码推断基准结果。

仅当所选显示模式需要实时数值时，菜单栏控制器才启用一秒刷新 timer；此刷新更新展示，不改变持久化周期。仅凭这一源码事实不能断定存在可测负载。

### 本地记录类型与规范数据

Core Data 中每日聚合实体包括 App 使用、Website 使用、Typing 和 per-App Typing；Timeline 实体包括 App 与 Website 区间；后台活动是独立 interval entity。唯一键分别按日期/身份/指标版本约束。网站区间只在 Chrome 父区间内有效；网站和后台时长不会加到 Mac 总量。Backup JSON 使用版本化 envelope；当前支持校验并恢复已识别的版本 1–3，当前写出版本为 v3。恢复是 Replace，不是 merge。

### 迁移、界面和数据控制边界

Core Data 使用推断映射进行轻量 schema migration。测试包含旧 Timeline fixture 的聚合保留，以及增加后台 interval entity 的兼容 fixture；仓库没有真实旧版生产数据库，因此真实旧库迁移不可验证。History 从每日聚合和当前运行快照派生；Hourly/session/transition analytics 是读取时计算，不另存事件流。Dashboard 隐藏技术诊断，Advanced Settings 提供诊断；用户文案来自 `Localizable.xcstrings`。备份、恢复、导出、范围删除和完整性检查属于本地数据控制路径，具体通过情况以目标 revision 的测试记录为准。
