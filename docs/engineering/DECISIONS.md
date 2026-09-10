# DayTrace Engineering Decisions

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

- Use `com.wudonggua.daytrace` as the production Mac App Bundle ID.
- Retain `com.daytrace.spike` as the legacy Bundle ID for UserDefaults
  migration and controlled rollback.
- Keep the Native Messaging host name `com.daytrace.spike` for compatibility.
- Treat `mmnoopahcchjobiajnhembdlipkhbjgo` as the canonical current unpacked
  Chrome extension ID.
- Keep activity data and backups in Bundle-ID-independent Application Support
  locations.
- Migrate only known UserDefaults keys on a future identity cutover, preserving
  production precedence and the legacy store.
- Keep unsigned automation, signed Development, and Developer ID Distribution
  artifacts distinct.
- Never modify TCC databases or store Apple credentials in source.
