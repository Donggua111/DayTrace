# DayTrace Roadmap

## Current status

**Product Discovery: COMPLETE**
**Technical Spike 01: COMPLETE**
**Internal Beta Foundation Sprint 1A/1B: COMPLETE**
**Internal Beta Sprint 2B Core Persistence: STABILIZED**
**Sprint 3 Product Hardening: IMPLEMENTED — AUTOMATED REGRESSION PASSED**
**F-008 Event Tap Lifecycle: IMPLEMENTED — REAL-MAC REGRESSION PASSED**
**Timeline V2: IMPLEMENTED — 107 AUTOMATED TESTS PASSED; SIGNED MANUAL GATE PENDING**

Next gate: **Timeline V2 validation and independent re-review**

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
- stable `com.daytrace.spike` App identity retained for TCC continuity
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

Remaining Internal Beta work, intentionally deferred here:
- backup restore/import workflows
- privacy zones, automatic category rules, cloud/accounts, and production distribution

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
