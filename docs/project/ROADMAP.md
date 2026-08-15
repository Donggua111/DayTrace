# DayTrace Roadmap

## Current status

**Product Discovery: COMPLETE**

Next gate: **Technical Spike**

---

## Stage 1 — Technical Spike

Goal: prove the highest-risk technical capabilities before freezing the production architecture.

### Spike A — macOS foreground application tracking
- [ ] Detect frontmost application changes
- [ ] Capture bundle identifier and display name
- [ ] Measure foreground intervals without one-second polling
- [ ] Exclude sleep intervals
- [ ] Exclude locked-session intervals
- [ ] Verify close-window vs quit behavior can support continuous tracking

### Spike B — privacy-preserving global typing count
- [ ] Receive global keyboard events with required macOS permissions
- [ ] Count qualifying typing keystrokes
- [ ] Ignore modifier/system-control keys
- [ ] Verify no typed content is persisted
- [ ] Verify an exact 100-key manual test
- [ ] Record count against the currently foreground app
- [ ] Measure rough CPU/memory impact while idle and typing

### Spike C — Chrome active-domain sensing and local communication
- [ ] Load a local unpacked Chrome extension
- [ ] Identify the active tab domain
- [ ] Do not persist full URL/title/content
- [ ] Communicate domain state to the local DayTrace host
- [ ] Verify domain time can remain nested within Chrome foreground time
- [ ] Avoid a public-network backend

### Spike exit gate
Do not proceed to full feature implementation until all three spikes are either:
- validated, or
- documented with a deliberate fallback decision.

After the spike:
- [ ] Write/update `docs/engineering/ARCHITECTURE.md`
- [ ] Convert validated findings into production architecture
- [ ] Remove throwaway spike-only code if applicable
- [ ] Define Internal Beta tasks

---

## Stage 2 — Internal Beta

Planned after the Technical Spike passes.

Expected scope:
- foreground app usage collector
- sleep/lock handling
- pause/resume
- local persistence
- typing analytics
- Chrome domain analytics
- menu bar
- main dashboard
- bilingual localization
- category mappings
- daily history
- settings
- launch at login
- export/delete data

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
