# DayTrace Architecture

Status: Internal Beta Sprint 3 hardening baseline
Scope: validated tracking capabilities, local aggregate persistence, and the
small product surfaces built over that boundary

This document records the architecture currently allowed to move forward into
Internal Beta validation. Sprint 3 adds History, menu bar, launch-at-login,
export, and delete-data surfaces without changing the tracking, typing, domain,
IPC, or privacy boundaries.

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

## Stable identities

These values are intentionally frozen for the current Internal Beta foundation:

```text
App bundle ID: com.daytrace.spike
Native Messaging host name: com.daytrace.spike
Native Messaging type: stdio
```

The App bundle ID must remain stable because it is associated with macOS Input
Monitoring/TCC identity. The Native Messaging host name must remain stable
because Chrome discovers the host by that exact name.

The current unpacked development extension ID is
`mmnoopahcchjobiajnhembdlipkhbjgo`, confirmed from the active Chrome profile.
Native Messaging has one source of truth for this spike:
`extension/chrome/service-worker.js` requests `com.daytrace.spike`, and the
installer accepts only this extension ID when writing the user-level manifest.

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
