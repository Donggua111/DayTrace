# Privacy and Data Handling

**Languages / 语言：** [English](#english) · [简体中文](#简体中文)

## 简体中文

DayTrace 以本机活动汇总为设计目标。仓库不包含账户服务、云同步、遥测端点或公共后端。应用在当前用户的 Application Support 目录本地保存支持的数据；备份仅由用户通过应用中的明确操作创建。

### 处理的数据

- 前台应用身份和使用区间。
- 清理后的 Chrome 主机名和网站区间；网站时间仅作为 Chrome 前台使用的子项。
- 通过 listen-only 事件监听得到的聚合键盘类别计数、速度/会话指标。
- 支持的后台活动区间：NookX 可见活动与 NetEase 音频播放。
- 用户选择的展示元数据，例如固定项目、分类和本地偏好。

### 不保留的数据

DayTrace 不保留输入文本、重建的 Unicode 文本、原始按键序列、键盘历史、完整 URL、路径或查询参数、网页标题/内容、窗口内容、音频样本或剪贴板内容。键盘事件细节只用于临时分类，计入聚合后即丢弃。网站归属通过本地 Native Messaging/Unix socket 边界传递清理后的主机名或有限的状态值。

Chrome 扩展可能会临时检查活动标签页 URL 以提取主机名；它不会将完整 URL 或页面内容发送给 Native Host。当前规则是清理主机名，不做可注册域合并，因此子域可能分别统计。

### 权限与本地边界

Input Monitoring 用于 listen-only 键盘事件监听。Accessibility、Full Disk Access、Screen Recording、麦克风和网络权限不是替代方案，也不是本产品预期要求。Native Messaging 按用户级注册，并通过本地 Unix domain socket 与应用通信；没有 TCP/LAN listener 或持久 IPC 队列。

部分系统集成会读取有限元数据，例如应用身份、可见窗口元数据或音频进程是否输出。应用不读取窗口像素/内容或音频内容。检测器信号可能随系统状态不可用；此时应报告不可用，而不是猜测。

### 用户控制与限制

用户可暂停跟踪、通过支持的应用控制删除本地数据，并主动执行备份/恢复。DayTrace 没有专用数据库加密层；请依赖 macOS 账户安全和设备加密。本说明描述当前设计意图，每次发布前都应重新对照代码核验。

## English

DayTrace is designed for local activity summaries. The repository contains no account service, cloud sync, telemetry endpoint, or public backend. The app stores its supported data locally in the current user's Application Support area; backups are created only through the app's explicit backup flow.

## Data handled

- Foreground app identity and time intervals.
- Sanitized Chrome hostnames and website intervals, only as a child of Chrome foreground use.
- Aggregate keyboard category counts and timing/session metrics through a listen-only event tap.
- Separate supported background activity intervals for visible NookX activity and NetEase audio playback.
- User-selected presentation metadata such as pins/categories and local preferences.

## Data not retained

DayTrace does not retain typed text, reconstructed Unicode, raw key sequences, keyboard history, full URLs, URL paths or queries, page titles, page contents, window contents, audio samples, or clipboard contents. Keyboard event details are transiently classified, added to aggregates, and discarded. Website attribution transmits a sanitized hostname or a small approved state across the local Native Messaging/Unix socket boundary.

The Chrome extension may transiently inspect the active tab URL to derive a hostname. It does not send the full URL or page contents to the native app. Hostname normalization is not registrable-domain aggregation; for example, subdomains may remain distinct.

## Permissions and local boundaries

Input Monitoring is used for a listen-only keyboard event tap. Accessibility, Full Disk Access, Screen Recording, microphone, and network permissions are not substitutes or intended requirements. Native Messaging is registered at user level and communicates with the app over a user-only Unix domain socket; there is no TCP/LAN listener or persistent IPC queue.

Some operating-system integrations can expose limited metadata, such as app identity, visible-window metadata, or whether an audio process is outputting. The app does not read window pixels/content or audio content. Detector availability can vary by OS state.

## User control and limitations

Tracking can be paused, local data can be deleted through supported app controls, and backups/restores are explicit. Local data is not encrypted by a DayTrace-specific database encryption layer; users should rely on macOS account security and device encryption. This document describes current intended behavior and should be revalidated against code before each release.
