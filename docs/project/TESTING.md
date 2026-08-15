# DayTrace Testing Strategy

This file defines how product behavior is verified. Add regression tests when real bugs are found.

---

## 1. Testing layers

### Automated tests
Use for deterministic logic:
- interval aggregation,
- non-overlap rules,
- category aggregation,
- daily bucketing,
- typing counter classification,
- settings logic where practical.

### Manual functional tests
Use for macOS permissions and OS/browser integration.

### Dogfooding
Run DayTrace during normal daily Mac use and compare results with observed behavior.

---

## 2. Technical Spike manual tests

### T-APP-001 — Foreground switching
1. Start DayTrace spike build.
2. Bring Chrome to foreground for approximately 2 minutes.
3. Switch to VS Code for approximately 2 minutes.
4. Inspect recorded intervals.

Expected:
- Chrome ≈ 2 minutes
- VS Code ≈ 2 minutes
- no overlap in foreground usage intervals

### T-APP-002 — Sleep exclusion
1. Keep Chrome foreground.
2. Put Mac to sleep for at least 2 minutes.
3. Wake Mac.
4. Inspect Chrome interval.

Expected:
- sleeping interval is not added to Chrome usage time.

### T-APP-003 — Lock exclusion
1. Keep Chrome foreground.
2. Lock the Mac for at least 2 minutes.
3. Unlock.
4. Inspect Chrome interval.

Expected:
- locked interval is not assigned to Chrome.

### T-KEY-001 — Exact 100 typing keystrokes
1. Record current typing-keystroke counter.
2. Press exactly 100 qualifying typing keys.
3. Read the counter.

Expected:
- counter increases by exactly 100.

### T-KEY-002 — Modifier exclusion
1. Record current counter.
2. Press Shift, Command, Control, Option and Caps Lock repeatedly without text keys.
3. Read the counter.

Expected:
- no increase from these modifier/system-control keys alone.

### T-KEY-003 — Content privacy
Inspect:
- application logs,
- local files,
- stored database/prototype state.

Expected:
- no typed character stream,
- no reconstructed text,
- no password-like content.

### T-WEB-001 — Active Chrome domain
1. Load the extension locally.
2. Make `chatgpt.com` the active Chrome tab.
3. Make Chrome foreground.
4. Inspect reported website identity.

Expected:
- reported identity is `chatgpt.com` only.

### T-WEB-002 — Domain switches
1. Keep Chrome foreground.
2. Switch active tab from `chatgpt.com` to `github.com`.
3. Inspect domain-state transitions.

Expected:
- website identity changes to `github.com`.
- no full URL or title is persisted.

### T-WEB-003 — Browser nesting
1. Keep Chrome foreground for 10 minutes.
2. Spend 6 minutes on domain A and 4 minutes on domain B.

Expected:
- Chrome ≈ 10 minutes
- A ≈ 6 minutes
- B ≈ 4 minutes
- total Mac usage increases by ≈ 10 minutes, not 20 minutes.

---

## 3. Internal Beta acceptance tests

Add these once the production architecture exists:
- Pause/Resume tracking
- close dashboard while continuing tracking
- full Quit behavior
- launch at login
- local persistence after restart
- language switching
- menu bar display modes
- category override persistence
- export data
- delete data

---

## 4. Regression rule

When a bug is fixed:
1. document minimal reproduction,
2. add an automated test when deterministic,
3. otherwise add a named manual regression test,
4. verify the bug no longer reproduces before marking the task complete.
