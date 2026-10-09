# DayTrace Product Requirements Document

**Languages / 语言：** [English](#daytrace-product-requirements-document) · [简体中文](#简体中文)

**Status:** Product Discovery complete; ready for technical validation  
**Platform:** macOS only  
**Product form:** Native macOS application + Chrome extension for website-domain sensing  
**Data model philosophy:** Local-first, privacy-first, no account required

**Status note:** This document contains product intent, including deferred
ideas. It is not a statement that every item is implemented or validated.
Current behavior must be checked against the source and
[Testing](../project/TESTING.md). In particular, current typing metrics count
supported English letters, digits, symbols, and spaces; Backspace/Delete,
Return, Tab, modifiers, and Chinese IME composition are not counted. The
English word estimate is derived from aggregate English-letter counts (five
letters per estimated word). Chinese-character estimation remains a future
product/technical decision.

---

## 1. Product overview

DayTrace is a personal macOS activity analytics application designed to answer, with clear and trustworthy data:

- How long did I use my Mac today?
- Which applications were in the foreground, and for how long?
- When Chrome was in the foreground, which websites accounted for that time?
- How much did I type today?
- Approximately how many English words and Chinese characters did I produce?
- How is my computer time distributed across categories such as AI, Development, Study, Communication, and Entertainment?

DayTrace is not intended to monitor the content of the user's work. It must avoid recording actual typed text, complete URLs, page titles, or page content.

---

## 2. Target user

### V1 primary user
A single user on a single Mac.

### V1 assumptions
- No account is required.
- No cloud backend is required.
- No cross-device sync is required.
- No Windows, iPhone, or iPad client is required.
- The product may later become public or open source, but that decision is explicitly deferred.

---

## 3. Product principles

### 3.1 Local-first
All activity data is stored locally on the user's Mac in V1.

### 3.2 Privacy by architecture
DayTrace must not store:
- actual typed text,
- password contents,
- complete URLs,
- URL paths,
- query parameters,
- webpage titles,
- webpage content.

### 3.3 Predictable metrics
The user should be able to understand exactly why time was counted.

### 3.4 Low overhead
DayTrace is expected to remain running for long periods. CPU, memory, wakeups, disk writes, and battery impact must therefore be minimized.

### 3.5 No double-counting of human time
The same real-world foreground interval may be represented at multiple analytical levels, but must only count once toward total Mac usage time.

### 3.6 Bilingual from the beginning
All user-facing strings must support:
- Simplified Chinese
- English
- Follow System

The language must be freely switchable in Settings without reinstalling the app.

---

## 4. Core metric definitions

### 4.1 Usage Time / 使用时间

**Definition:** The amount of time an application is the frontmost macOS application.

If Chrome remains frontmost for 20 minutes, Chrome receives 20 minutes of usage time even if the user does not move the mouse or type during that interval.

V1 does **not** attempt to infer whether the user is:
- actively interacting,
- passively reading,
- waiting,
- temporarily away from the keyboard.

Therefore V1 does not expose Active Time, Passive Time, or Idle Time as separate user-facing metrics.

#### System-level exclusions
Usage time must stop when:
- the Mac sleeps,
- the screen/session is locked,
- DayTrace tracking is manually paused,
- DayTrace has fully quit.

When the Mac is awake and unlocked, the frontmost application continues accumulating foreground usage time even if there is no keyboard/mouse activity.

---

### 4.2 Total Mac Usage Time

The sum of non-overlapping foreground application intervals while tracking is enabled and the Mac is awake/unlocked.

Example:

```text
Chrome     10 min
ChatGPT    15 min
VS Code    20 min
-----------------
Total      45 min
```

---

### 4.3 Website Usage Time

Website time is a child breakdown of browser foreground time.

For V1:
- Browser supported: Chrome
- Website identity stored: domain only

Example:

```text
Chrome                  3h 12m
├── chatgpt.com          1h 05m
├── github.com             47m
├── youtube.com            36m
├── google.com             22m
└── Other                  22m
```

**Invariant:** Website time does not create additional total computer time.

If one minute is counted for `chatgpt.com`, that minute is already part of Chrome's foreground time.

#### Website time counts only when
- Chrome is frontmost,
- the tab is the active Chrome tab,
- tracking is not paused,
- the Mac is awake and unlocked.

#### Special browser states
- `chrome://...` and equivalent internal pages → `Browser Internal`
- `file://...` → `Local File`
- local file paths must not be stored

---

## 5. Detailed Timeline V2

The product may present a chronological local-day timeline in addition to its
canonical daily aggregates. Timeline intervals are detail records for
visualization and review; they do not change Total Mac Usage or any aggregate
analytics.

The App timeline stores stable app identity, display name, local date key,
start, end, duration, and open-state recovery metadata. Chrome website children
store only Chrome identity and a sanitized domain. No URL, title, path, query,
content, clipboard, screenshot, typed text, or keyboard event detail is stored.

Intervals are split at local midnight, closed at lock/sleep/pause/termination,
and checkpointed in place. An interrupted open interval is closed at its last
durable checkpoint on relaunch. Chrome gaps are derived from the Chrome parent
interval instead of stored as a separate activity stream.

Detailed Timeline storage is enabled by default and can be disabled in
Settings. Disabling stops new detail records but leaves daily aggregates and
existing timeline history intact. The user can delete detailed timeline
history without deleting daily aggregates. Aggregate export remains compatible
by default; detailed timeline export is opt-in and backups use a versioned
envelope.

### 5.1 Background Activity V1

Background Activity is a separate interval stream for activity that may
continue while another application is foreground. It is never added to Total
Mac Usage, foreground app totals, Chrome website parent time, or typing
metrics. The V1 surface is a compact Dashboard card and a parallel History
lane; background intervals can be deleted independently.

The first supported identities are NookX visible activity and NetEase audio
playback. Detection uses public process/window metadata and public CoreAudio
process state only. DayTrace does not read window content, audio samples,
titles, URLs, or user input, and does not request Screen Recording,
Accessibility, microphone, or other additional sensitive permissions. If the
operating system cannot provide a reliable public signal, the detector remains
unavailable rather than guessing.

## 6. Typing analytics

Typing analytics has two layers.

### 6.1 High-level estimated writing

The primary high-level typing presentation should be:

- **Estimated Chinese Characters / 预计中文字数**
- **Estimated English Words / 预计英文单词数**

These values are estimates and must be visually marked as approximate where appropriate.

The product must never falsely present an estimate as an exact linguistic count.

### 6.2 Current aggregate typing metric and future extensions

The implemented metric is an aggregate count of supported key-down categories:
English letters, digits, symbols, and Space. Backspace/Delete, Return, Tab,
modifiers, navigation and function keys are ignored by the current classifier.
The event is transiently classified; no character value, key sequence, Unicode
text, or text buffer is persisted.

The product may consider additional aggregate metrics later, but Enter/Return,
Tab, editing keys, Chinese IME output, and linguistic word boundaries are not
claimed by the current implementation. Any future metric requires an explicit
privacy and product decision plus tests before being described as supported.

### 6.3 Typing breakdown

Typing analytics should support:
- daily total,
- per application,
- for Chrome: per domain where technically reliable.

Example:

```text
Typing Keystrokes
Total              28,493

By App
ChatGPT             8,421
VS Code             7,302
Chrome              6,918
WeChat              3,127
Other               2,725
```

### 6.4 English word estimation

Current code estimates English words by rounding the aggregate English-letter
count divided by five. This is a rough estimate, not lexical tokenization or a
validated measure of words composed. Any future word-boundary method requires
a separate privacy and product review; no text buffer may be introduced.

### 6.5 Chinese character estimation

Chinese IME input means keystrokes do not map directly to final characters.

Desired product behavior:
1. Prefer a privacy-preserving method that can count committed character quantity without retaining character content, if macOS APIs make this technically reliable and appropriate.
2. Otherwise use a clearly labeled statistical estimate.
3. Never store reconstructed Chinese text.

This remains a future product and technical decision; the current implementation
does not claim to count committed Chinese IME characters.

---

## 7. Application hierarchy and analytical dimensions

### 7.1 Primary hierarchy: App → Website

The main usage hierarchy is software-first.

Example:

```text
Chrome
└── Websites

VS Code

ChatGPT
```

Websites remain nested under their host browser.

### 7.2 Category dimension

Categories are an independent analytical dimension and do not replace the App → Website hierarchy.

Initial V1 categories:
- AI
- Development
- Study
- Productivity
- Communication
- Entertainment
- Other

Example mappings:

```text
ChatGPT App    → AI
chatgpt.com    → AI
Claude         → AI
VS Code        → Development
github.com     → Development
WeChat         → Communication
```

### 7.3 User overrides

DayTrace can provide default category mappings.

A user's manual category choice must override the default mapping.

V1 needs category reassignment; it does not need an unlimited/custom category-management system.

---

## 8. Application runtime behavior

### 8.1 Dock
While DayTrace is running:
- it remains visible in the Dock,
- clicking the Dock app icon opens or restores the main DayTrace window,
- if the main window already exists, it should be brought forward.

### 8.2 Menu bar
While DayTrace is running, it also maintains a menu bar presence.

The menu bar provides:
- quick daily summary,
- Open DayTrace,
- Pause Tracking / Resume Tracking,
- Settings,
- Quit DayTrace.

### 8.3 Closing the main window
Closing the dashboard window does not quit DayTrace and does not stop tracking.

### 8.4 Quitting
`Command-Q` or `Quit DayTrace` fully exits the application and stops tracking.

### 8.5 Pause Tracking
Pause Tracking stops all activity collection for the paused interval:
- app usage,
- website usage,
- typing keystrokes,
- estimated writing counters.

Resume Tracking starts collection again from that moment.

No retroactive inference should fill in the paused interval.

---

## 9. Launch at Login

Launch at Login is user-configurable.

Settings must provide:
- `Launch DayTrace at Login` on/off

DayTrace must not require launch-at-login to function.

---

## 10. Menu bar display customization

The user can choose what the persistent menu bar label shows.

Initial options:
1. Icon only
2. Today's usage time
3. Today's typing keystrokes
4. Usage time + typing keystrokes

Example concepts:

```text
Icon only          [DayTrace icon]
Usage              4h 38m
Typing             28.5K
Both               4h38 · 28.5K
```

Exact visual design is deferred to the UI implementation phase.

---

## 11. Main dashboard

The dashboard should prioritize today's information.

Minimum V1 dashboard content:

### Summary
- Usage Time
- Estimated Chinese Characters
- Estimated English Words
- Typing Keystrokes

### Apps
- foreground usage by application
- expandable browser entry

### Chrome
- domain-level time breakdown
- domain-level typing breakdown where reliable

### Categories
- usage aggregated across category mappings

### History
- daily history
- basic trend visualization

Exact visual styling is not frozen by this PRD.

---

## 12. Settings

V1 Settings should include at minimum:

### General
- Language: Follow System / 简体中文 / English
- Launch at Login

### Menu Bar
- Icon only
- Usage Time
- Typing Keystrokes
- Usage Time + Typing Keystrokes

### Tracking
- Pause / Resume
- Website tracking on/off

### Categories
- view and reassign default category mappings

### Privacy / Data
- local data location or data information
- export data
- delete all activity data

---

## 13. Localization requirements

Localization is an architectural requirement from the first UI implementation.

Rules:
- No hard-coded user-facing Chinese/English strings scattered through views.
- Use standard Xcode localization resources, preferably String Catalogs.
- Internal identifiers remain language-neutral.
- Switching UI language must not alter stored analytics data.

Supported UI modes:
- Follow System
- Simplified Chinese
- English

---

## 14. Privacy requirements

V1 must be designed such that its useful database does not need to contain the user's actual typed content.

### Must not persist
- text typed by user
- key-by-key textual history
- passwords
- full URL
- URL path
- URL query
- webpage title
- webpage content

### May persist
- timestamps / time buckets
- application bundle identifier
- application display name
- domain
- aggregate typing counts
- aggregate estimates
- category mapping
- settings

### Browser extension
The Chrome extension should request only the minimum permissions required for reliable active-domain sensing.

---

## 15. Non-goals for V1

Explicitly excluded:
- user account system
- passwords/authentication
- cloud sync
- backend server
- public API
- subscriptions/payment
- Windows app
- iPhone/iPad app
- Safari extension
- team analytics
- AI productivity score
- automatic interpretation of user intent
- Active/Passive/Idle attention classification
- AI background-generation-time tracking
- App Store/public release requirements
- open-source license and publication terms (tracked separately in
  `docs/project/OPEN_SOURCE_PREPARATION.md`)

These can be reconsidered after the Mac local-first product is stable.

---

## 16. V1 completion criteria

V1 should not be considered complete merely because the project builds.

Minimum functional requirements:
- app foreground usage tracking,
- sleep exclusion,
- lock-screen exclusion,
- pause/resume exclusion,
- daily usage aggregation,
- typing-keystroke tracking,
- estimated Chinese/English writing metrics,
- Chrome domain tracking,
- Chrome → website hierarchy,
- category aggregation,
- bilingual UI,
- menu bar,
- Dock/main-window behavior,
- configurable launch at login,
- local persistence,
- daily history,
- data export,
- data deletion.

Minimum verification behaviors:
1. 100 qualifying typing keystrokes increase the typing counter by exactly 100.
2. Chrome 5 minutes → VS Code 5 minutes must not produce overlapping foreground usage.
3. 30 minutes of Mac sleep must not add 30 minutes to the previously foreground app.
4. Locked-screen time must not be assigned to an app.
5. Closing the dashboard must not stop background tracking.
6. Quitting DayTrace must stop tracking.
7. Restarting DayTrace must preserve prior local history.
8. Website time must remain nested inside Chrome time rather than increasing total usage time.
9. Pause Tracking must record no app, website, or typing activity for the paused interval.
10. Chinese/English language switching must not change analytics data.

---

## 17. Development stages

Only three major project stages should be used:

### Technical Spike
Validate the technically risky capabilities before freezing production architecture.

### Internal Beta
A usable local build that the primary user can run daily for real-world testing.

### 1.0
A stable personal-use release after dogfooding and verification.

Do not create duplicate repository copies for each stage. Use Git commits/tags/branches as appropriate.

## 18. Product Completion V1 surface

The Internal Beta product surface now includes descriptive Analytics V3 in
History (hourly activity, sessions, transitions, and App/Website daily trends),
versioned local Replace Restore, range-based activity deletion, manual Data
Integrity checks, privacy-safe diagnostic export, concise first-run onboarding,
exact category rules, and presentation-only Hide Identity.

Restore never merges or executes imported content. It validates the complete
JSON payload, creates a safety backup, replaces supported activity datasets in
one persistence transaction, and re-anchors runtime tracking. Diagnostic
exports intentionally omit activity history, domains, URLs, paths, and typed
content. Exclude Tracking and identity-specific historical deletion remain
future decisions because their runtime semantics require additional safety
coverage.

## 19. Productionization V1 boundary

Productionization V1 is installation and trust infrastructure, not a new
tracking feature. The app remains local-first, preserves the current accounting
semantics, and keeps the existing Native Messaging host for compatibility. A
future Bundle ID cutover must preserve UserDefaults and activity history and
may require one-time Input Monitoring reauthorization; DayTrace must never
modify TCC data directly.

## 简体中文

**状态说明：** 本文包含产品意图及延期设想，不代表所有条目都已实现或验证。当前行为应以源码和[测试策略](../project/TESTING.md)为准。特别是：现有输入统计仅计入支持的英文字符键、数字、符号和空格；Backspace/Delete、Return、Tab、修饰键和中文输入法组合不计数。英文词数按聚合英文字符数量估算（每 5 个英文字符估算 1 个词）。中文字符估算仍是未来产品/技术决策。

### 产品概览

DayTrace 是一款个人 macOS 活动分析应用，目标是清楚地回答：今天使用 Mac 多久、哪些 App 在前台及其时长、Chrome 前台时间分布在哪些网站、输入活动统计如何，以及使用时间如何分布在不同类别。它不用于监控工作内容，必须避免记录实际输入文本、完整 URL、网页标题或网页内容。

### 目标用户与产品原则

V1 面向单台 Mac 上的单个用户；不要求账户、云后端或跨设备同步。原则包括：本地优先、按架构保护隐私、指标定义可理解、长期运行时关注资源开销、不重复计算同一段真实使用时间，以及界面支持简体中文/English/跟随系统切换。

### 核心时间指标

- **前台使用时间：** 某 App 成为 macOS 最前台应用的时间。V1 不推断用户是否正在主动操作、阅读或离开键盘，因此不把 Active/Passive/Idle 当作产品指标。
- **排除条件：** 睡眠、锁屏、用户暂停跟踪和 DayTrace 完全退出期间不增加前台时间。唤醒且解锁后，即使没有键鼠活动，前台 App 仍会继续计时。
- **Mac 总使用时间：** 跟踪开启、系统唤醒且会话活跃期间，所有不重叠前台 App 区间之和。
- **网站时间：** 仅支持 Chrome，保存清理后的域名；只在 Chrome 前台、标签页活动且系统允许统计时作为子项累计，不增加 Mac 总时间。内部页面记为 `Browser Internal`，本地文件记为 `Local File`，不保存文件路径。

### Timeline 与后台活动

Timeline 是本地日历日的区间明细，不改变每日规范聚合。App 明细保存身份、显示名、本地日期键、起止和恢复元数据；Chrome 子项只保存清理域名。区间跨午夜拆分，在锁屏、睡眠、暂停、退出时关闭；崩溃后开放区间只恢复到最后可靠 checkpoint。详细 Timeline 默认开启，可单独停用或删除；聚合导出默认不包含详细记录，详细导出需明确选择。

后台活动是独立区间流，绝不加到前台、Chrome 网站或输入指标。当前 V1 检测器为 NookX 可见活动与 NetEase 音频播放；使用公开窗口/进程元数据和 CoreAudio 进程状态，不读取窗口内容或音频样本。系统无法给出可靠信号时标记不可用，不猜测。

### 输入活动

实现中的低层指标按英文字符键、数字、符号和空格聚合，按 App 归属。当前分类忽略删除、Return、Tab、修饰键、导航键和功能键。只通过 listen-only Event Tap 临时分类；不得保存字符值、按键序列、Unicode 文本或文本缓冲区。英文词数按聚合英文字符数量除以五并四舍五入，是粗略估算，不是词法解析或经验证的词数。中文 IME 输出不支持统计；任何中文字符估算都属于待决定事项，不应对外宣称已实现。

### App 层级、运行与界面

主要层级为 App → Website；分类、用户覆盖规则和展示元数据不应改变历史使用身份。支持本地 Dashboard、History、设置、菜单栏摘要、暂停/继续、启动时运行、数据导出/删除以及用户主动的备份/替换恢复。关闭主窗口不等同退出；正常退出会停止跟踪并保存状态。具体功能状态须按当前代码和测试再次核验。

### 分类、菜单栏与设置

分类是独立分析维度，不替代 App → Website 层级。初始类别为 AI、Development、Study、Productivity、Communication、Entertainment、Other；默认映射可由用户重新分配，手动选择优先。V1 不要求无限制自定义分类系统。

产品意图要求 DayTrace 在 Dock 保持可见；点击 Dock 图标打开或恢复主窗口。菜单栏提供每日摘要、打开 App、暂停/继续、设置和退出。关闭窗口继续跟踪；Command-Q/退出才完全停止。Pause 会停止 App、网站和输入活动采集，恢复时从当时开始，不补算暂停时段。

登录启动应由用户选择，App 不依赖它才能运行。菜单栏展示模式为仅图标、今日使用时长、今日输入量或两者组合。Dashboard 需求包括今日摘要、App 排名、Chrome 域名/网站统计、分类汇总及历史趋势；Settings 需求包括语言、登录启动、菜单栏模式、暂停/网站跟踪开关、类别映射、本地数据说明、导出与删除。以上是产品规格，不应被理解为每一项都已经通过验收。

### 本地化、数据控制与完成标准

用户文案不得散落硬编码；使用 Xcode localization resources/String Catalog，内部标识保持语言中立。Follow System、简体中文和 English 切换不得改变分析数据。产品完成需验证睡眠/锁屏/Pause 排除、前台不重叠、退出停止、重启保留数据、网站嵌套不增加总量、语言切换不重置指标、输入隐私，以及数据导出/删除。

### 隐私要求

不得持久化输入文本、逐键文本历史、密码、完整 URL、路径、查询参数、网页标题或网页内容。可持久化时间戳/时间桶、App 标识、清理域名、聚合输入计数、分类和设置。Chrome 扩展仅应申请活动标签归属所需的最小权限。

### 不在 V1 范围及完成标准

账户、云同步、公共 API、支付、Windows/iOS 客户端、Safari 扩展、团队分析、AI 效率评分、意图推断和注意力分类均不属于当前 V1 范围。产品完成不只看能否构建；还需验证前台无重叠、睡眠/锁屏/暂停排除、退出停止、重启保留本地历史、网站嵌套不增加总量、输入隐私边界和语言切换不改数据。

### 开发阶段与生产化边界

技术 Spike 用于验证高风险系统集成；Internal Beta 用于真实日常试用；1.0 需在长期使用和验证后决定。生产化工作是安装与信任基础设施，不是新增跟踪功能。未来 Bundle ID 变更必须保留偏好与历史数据，可能需要重新授权 Input Monitoring；应用绝不直接修改 TCC 数据。

当前产品完成面还包括基于已有聚合/Timeline 的小时、会话、切换和趋势分析，版本化 Replace Restore、按日期范围删除、手动完整性检查、隐私安全诊断导出、首次引导、精确分类规则及展示层 Hide Identity。恢复必须先完整校验备份、建立安全备份，再在受控事务中替换；不得默默合并或执行导入内容。未来是否加入 Exclude Tracking 和实体级历史删除仍需单独定义与安全覆盖。
