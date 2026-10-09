# DayTrace Roadmap

**Languages / 语言：** [English](#daytrace-roadmap) · [简体中文](#简体中文)

> Status note: the completion statements below are historical project snapshots,
> not proof that the current checkout has passed those validations. Verify the
> exact revision with the procedures in [Testing](TESTING.md).

## Current status

**Product Discovery: COMPLETE**
**Technical Spike 01: COMPLETE**
**Internal Beta Foundation Sprint 1A/1B: COMPLETE**
**Internal Beta Sprint 2B Core Persistence: STABILIZED**
**Sprint 3 Product Hardening: IMPLEMENTED — AUTOMATED REGRESSION PASSED**
**F-008 Event Tap Lifecycle: IMPLEMENTED — REAL-MAC REGRESSION PASSED**
**Timeline V2: IMPLEMENTED — historical test count is recorded in Testing; signed manual gate status must be checked for the target revision**
**Background Activity V1: IMPLEMENTED — AUTOMATED REGRESSION PASSED; REAL-APP DETECTOR GATE PENDING**

Next gate: **No current release gate is asserted by this historical roadmap. See `OPEN_SOURCE_PREPARATION.md` and the test record for current blockers.**

---

## Stage 1 — Technical Spike

Goal: prove the highest-risk technical capabilities before freezing the production architecture.

### Spike A — macOS foreground application tracking
- [x] Detect frontmost application changes
- [x] Capture bundle identifier and display name
- [x] Measure foreground intervals without one-second polling
- [x] Exclude sleep intervals
- [x] Exclude locked-session intervals
- [x] Verify close-window vs quit behavior can support continuous tracking

### Spike B — privacy-preserving global typing count
- [x] Receive global keyboard events with required macOS permissions
- [x] Count qualifying typing keystrokes
- [x] Ignore modifier/system-control keys
- [x] Verify no typed content is persisted
- [x] Verify an exact 100-key manual test
- [x] Record count against the currently foreground app
- [x] Measure rough CPU/memory impact while idle and typing

### Spike C — Chrome active-domain sensing and local communication
- [x] Load a local unpacked Chrome extension
- [x] Identify the active tab domain
- [x] Do not persist full URL/title/content
- [x] Communicate domain state to the local DayTrace host
- [x] Verify domain time can remain nested within Chrome foreground time
- [x] Avoid a public-network backend

### Spike exit gate
All three spikes are validated and their current boundaries are recorded in
`docs/engineering/ARCHITECTURE.md`.

After the spike:
- [x] Write/update `docs/engineering/ARCHITECTURE.md`
- [x] Convert validated findings into the Internal Beta foundation architecture
- [x] Remove generated build/user-state artifacts from the source baseline
- [x] Define Internal Beta tasks

## Stage 1.5 — Internal Beta Foundation

Completed in Sprint 1A/1B:

- formal DayTrace Xcode project, target, scheme, module, and test names
- production App identity selected; legacy identity retained for migration
  and rollback
- stable `com.daytrace.spike` Native Messaging host identity retained
- source baseline prepared for Git tracking
- generated artifacts excluded from the repository
- architecture and testing documentation synchronized

This foundation stage does not add persistence, history, categories, account,
cloud, export, menu bar, launch-at-login, or other new product capabilities.

---

## Stage 2 — Internal Beta product work

Sprint 2B established the first local persistence baseline. Sprint 3 adds a
small product surface over those daily aggregates without changing the
tracking or IPC architecture.

Completed in the current persistence fast track:
- foreground app usage collector
- sleep/lock handling
- pause/resume
- local persistence
- typing analytics
- Chrome domain analytics
- second-precision local-day aggregation
- periodic and termination checkpointing
- restart recovery and idempotent upserts
- Event Tap RunLoop-owned cleanup and relaunch safety
- history ranges over daily aggregate records
- menu bar summary and native launch-at-login control
- aggregate-only JSON export and delete-all-data reset
- live snapshot caching and application icon caching for lower refresh cost

Implemented in the current Insights & Control batch:
- period comparisons, safe delta math, daily averages, and a 30-day usage heatmap
- App/website detail surfaces, local search, pinned items, and optional App categories
- current activity on the Dashboard
- local privacy summary, data-location shortcut, and optional logical aggregate backups
- Timeline V2 interval history for apps and sanitized Chrome website children
- Timeline retention toggle, interval-only deletion, and versioned detailed export/backup
- Background Activity V1 interval lane, NookX visible-surface detector, NetEase public CoreAudio detector, and separate settings/delete/export paths

Product Completion V1 foundations now implemented:
- hourly activity, session and transition analytics with native Charts presentation
- App/Website daily trends and descriptive App detail analytics
- validated version 1–3 replace restore with safety backup and rollback-on-save-failure
- range-based dataset deletion with current-day runtime re-anchor
- on-demand integrity check and deterministic stale-open-interval repair
- privacy-safe diagnostic export and first-run onboarding
- exact category rules and presentation-only Hide Identity metadata

Remaining Internal Beta work, intentionally deferred here:
- Exclude Tracking runtime semantics and entity-specific historical deletion
- more background detectors; V1 is limited to the two inspected app identities
- production identity, distribution, cloud/accounts, and merge import

## Stage 2.5 — Productionization V1 foundation

Implemented infrastructure:

- centralized development/product identity map with production Bundle ID pending
- known-key UserDefaults identity migration seam and migration tests
- Bundle-ID-independent stable storage location abstraction
- single-instance kernel lock for store/socket ownership
- deliberate user-level Development install workflow
- atomic Native Messaging executable and manifest updates
- deterministic Release, DMG, notarization, and Gatekeeper tooling
- artifact-class and rollback documentation

Still pending before distribution:

- explicit final production Bundle ID
- available Apple Development / Developer ID credentials as applicable
- real signed Mac acceptance matrix and Chrome runtime validation

---

## Stage 3 — 1.0

Exit only after real daily dogfooding.

Required:
- [ ] Core data remains plausible over normal multi-hour use
- [ ] No known major double-counting
- [ ] Sleep/lock/pause behavior verified
- [ ] No typed text stored
- [ ] Chrome domain privacy verified
- [ ] Chinese and English UI both reviewed
- [ ] Resource use acceptable for all-day operation
- [ ] Restart persistence verified
- [ ] Export/delete behavior verified

## 简体中文

> 状态说明：以下完成项是历史项目快照，不代表当前 checkout 已通过相应验证。目标 revision 的实际状态应按[测试策略](TESTING.md)重新核验。

### 当前方向

产品探索、Technical Spike 和 Internal Beta 基础工程阶段已完成；Core Data 持久化、Timeline、Background Activity、Insights/Control、备份恢复和生产化基础设施已在代码中实现。具体是否通过测试或真实 Mac 验收，以对应 revision 的测试记录为准。公开发布前仍有开发者身份配置、Git 历史隐私、许可证选择和发布渠道等阻塞。

### 阶段 1：Technical Spike

- **Spike A：前台应用跟踪**——基于应用激活事件记录 bundle ID、显示名和区间；设计为排除睡眠和锁屏时长。
- **Spike B：隐私保护的输入聚合**——通过系统权限与全局键盘事件监听做类别聚合；禁止保存输入内容；真实权限行为需在签名 Mac 上验证。
- **Spike C：Chrome 域名与本地通信**——扩展获取活动标签域名，仅向本机传递清理结果；不保存完整 URL/标题/内容。
- Spike 通过标准和决策见架构文档；历史 Spike 验证不能代替当前代码的回归测试。

### 阶段 1.5：Internal Beta Foundation

已建立正式 Xcode target/scheme、源代码 Git 基线、生成物忽略规则和架构/测试文档。历史身份迁移与 Native Messaging Host 兼容性必须谨慎维护。此阶段不代表已经开放公开分发。

### 阶段 2：Internal Beta 产品工作

实现内容包括：前台/睡眠/锁屏/Pause 处理、Core Data 本地聚合、输入和 Chrome 网站统计、本地日切、周期与退出 checkpoint、重启恢复、Event Tap 生命周期、History、菜单栏、登录启动、聚合导出和清空数据；后续产品面还包括比较与趋势、App/网站详情、本地搜索、固定项、分类、Timeline、后台活动、数据完整性、诊断导出、首次引导及 Replace Restore。

统计边界：每日聚合是总量来源，Timeline 是明细；网站时间属于 Chrome 子项；后台活动单独记录，不加进前台总量。现有实现和手工验收状态应分别核对，不由路线图推断。

仍延期或需决定的事项包括：Exclude Tracking 语义和实体级历史删除、增加其他后台检测器、贡献者身份配置、许可证及公开分发。账户、云同步和合并导入不属于本路线阶段的已承诺能力。

### 阶段 2.5：Productionization 基础

本阶段聚焦安装与信任基础设施：区分未签名自动化、Apple Development 和 Developer ID 分发产物；以用户级方式安装 Native Host；保留回滚；提供 Release/DMG/公证/Gatekeeper 工具。真实签名、权限、Chrome、生命周期验收必须有实际运行证据。

### 阶段 3：1.0 退出门槛

只有经过真实日常使用后才可进入 1.0：核心数据在长时使用中合理；没有已知重大重复计时；睡眠/锁屏/Pause 语义经过验证；没有保存输入文本；Chrome 域名隐私通过检查；中英界面经过审阅；全天资源开销可接受；重启持久化、导出和删除行为已验证。
