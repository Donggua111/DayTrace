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
