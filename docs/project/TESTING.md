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

### Foundation source baseline

The repository tracks source, project configuration, resources, extension
files, scripts, and design sources. It excludes `DerivedData`, `xcuserdata`,
`.xcuserstate`, `.xcresult`, build products, and `.DS_Store` through the root
`.gitignore`.

The formal App project and scheme are:

```text
app/DayTraceSpike/DayTrace.xcodeproj
scheme: DayTrace
```

---

## 2. Technical Spike manual tests

### T-APP-001 — Foreground switching
1. Start the DayTrace build.
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

### T-APP-004 — Wake while still locked
1. Keep an app foreground and note the current interval start.
2. Lock the Mac.
3. Put the Mac to sleep while it is locked.
4. Wake the Mac, but do not unlock it yet.
5. Inspect DayTrace before unlocking.
6. Unlock the Mac and wait for the next foreground event.
7. Inspect the interval list and current interval again.

Expected:
- The wake event alone does not start a new foreground interval.
- The locked/sleeping gap is absent from usage totals.
- No interval is attributed to `loginwindow`.
- A fresh interval starts only after the session becomes active/unlocked.

### T-APP-005 — Calendar and time-zone change re-anchor
1. Keep an app foreground and note its current interval.
2. Change the system time zone, calendar day boundary, or system clock.
3. Inspect the current interval and daily aggregate.

Expected:
- The pre-change interval closes once at the change timestamp.
- A new interval is anchored after the change when the session is active.
- Existing aggregate seconds are not duplicated or reinterpreted solely by the
  calendar notification.

### T-KEY-001 — Exact 100 typed-character events
1. Record the current Typed Characters (Estimated) value.
2. Press exactly 100 supported English letter, number, symbol, or space keys.
3. Read the value again.

Expected:
- Typed Characters (Estimated) increases by exactly 100.
- The matching English Letters, Numbers, Symbols, or Spaces aggregate also
  increases by the corresponding amount.

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

### T-KEY-004 — Event Tap lifecycle and relaunch
1. Build and launch an Apple Development-signed Debug build.
2. Grant DayTrace Input Monitoring access and relaunch it.
3. Confirm Settings diagnostics reports the Event Tap as Running.
4. Quit DayTrace from the application menu.
5. Confirm the process exits without a crash or a stuck helper process.
6. Relaunch DayTrace and type in two foreground applications.
7. Quit and relaunch once more, then type a short sequence again.

Expected:
- each launch has at most one active Event Tap;
- the Event Tap status transitions to Running after authorization;
- quitting does not hang while the Event Tap RunLoop is active;
- relaunching does not create duplicate typing counts;
- no typed content, key sequence, or event payload appears in logs or storage.

This test requires the real macOS Input Monitoring permission and cannot be
fully substituted by the XCTest suite. The deterministic suite covers the
aggregate and privacy boundary; this test covers the Core Graphics lifecycle
and application teardown.

### Sprint 2A typing activity smoke test

Run this against an Apple Development-signed Debug build after granting Input
Monitoring. The Typing Activity section is runtime-only and resets when the
app is restarted.

A. Open the Dashboard and confirm the main metric reads Typed Characters
(Estimated), with English Letters, Numbers, Symbols, and Spaces below it.

B. Type English letters, digits, punctuation, and spaces. Confirm only the
corresponding category and the total increase.

C. Type Backspace, Delete, Return, Tab, Shift, Command, Control, and Option.
Confirm none of these increase the total or category counts.

D. Type a short sequence with a pause of less than five minutes. Confirm
Typing Speed, Active Typing, and Typing Sessions become meaningful values;
hover the Active Typing and Typing Sessions rows to read their explanations.

E. Type in two foreground apps. Confirm Most Typed In App and Top Typed Apps
reflect the app with the larger aggregate, showing only app names and counts.

F. Use a Chinese IME and commit Chinese characters. Confirm the dashboard does
not claim those final characters were counted; this V1 limitation is expected.

G. Open the information button beside Typing Activity. Confirm the explanation
states that measurement is local, content is not stored, and pasted/app-
generated text is not currently counted.

H. Confirm the privacy line says counts only and that no typed text, key codes,
or key sequence appears in the Dashboard, Settings diagnostics, logs, or local
files.

I. Switch between Follow System, 简体中文, and English. Confirm every Typing
Activity label, explanation, privacy line, unit, and duration updates without
resetting the current runtime aggregates.

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

### T-WEB-004 — Native Messaging discovery and website attribution
1. Open `chrome://extensions` with Developer Mode enabled.
2. Record the exact DayTrace extension ID and confirm it matches the installed
   Native Messaging `allowed_origins` value.
3. Reload the extension and open its Service Worker console.
4. Confirm there is no `Specified native messaging host not found` error.
5. Open DayTrace and confirm IPC status becomes Connected.
6. Switch between at least two normal HTTPS domains while Chrome is
   foreground.

Expected:
- Native Messaging discovery succeeds without a host-not-found error.
- Website Usage changes using sanitized domains only.
- Full URL, title, and page content never appear.

### Automated Chrome attribution checks

The XCTest suite covers sanitized-domain validation, background-to-foreground
handoff, child-domain switching, non-overlapping aggregation, and rejection of
full-URL payloads. The native host boundary can be checked independently with:

```text
scripts/spike/verify-native-host.sh <native-host-executable>
```

That check uses a temporary user-local Unix socket, verifies that only the
minimal sanitized payload is forwarded, and verifies that an unexpected URL
field is rejected. It does not install the Chrome host manifest.

### Runtime language smoke test

Use the Language menu in the running app to check:
- Follow System
- 简体中文
- English

The window should update immediately, while foreground and typing aggregates
continue in the same process. Restart once after choosing a language to verify
that the raw preference value persists.

### Final stabilization manual regressions

#### T-KEY-004 — Event Tap lifecycle and relaunch
1. Launch the Apple Development-signed DayTrace build with Input Monitoring
   already authorized.
2. Type a short known-count sample and confirm the count increases once.
3. Quit normally and confirm there is no hang or crash.
4. Relaunch, type again, and confirm there is no duplicate count.
5. Repeat quit/relaunch twice and confirm normal tracking each time.

#### T-APP-004 — Wake while locked
1. Record current usage and lock the Mac.
2. Sleep while locked, then wake and remain on the lock screen for 30–60
   seconds.
3. Unlock and inspect the recorded usage.

Expected:
- Locked and sleeping time is excluded.
- `loginwindow` is not recorded.
- Usage resumes only after unlock.

#### T-PERSIST-004 — Restart retention
1. Generate App, Website, and Typing data and wait longer than one checkpoint
   interval.
2. Quit and relaunch DayTrace.
3. Confirm Today is retained and subsequent activity adds without duplication.

#### T-TIME-004 — Time-zone re-anchor
1. Generate a short foreground usage interval.
2. Change the system time zone, continue using the Mac, then restore the
   original time zone.

Expected:
- There is no giant interval or duplicated duration.
- The old local-day record remains unchanged; new activity uses the new local
  calendar.
- Tracking remains functional.

### Product UI smoke test

Use the main DayTrace window after launching the current Debug build:

1. Confirm the first screen shows today's total usage, Tracking / Paused state,
   top app usage, Typing Activity, and website usage in that order without
   showing Bundle IDs or permission diagnostics. Website Usage must be below
   Typing.
2. Switch between Most Used and Name in the App Usage sort menu. Confirm the
   rows remain compact, show system app icons when available, and Show All only
   appears when more than the top five apps exist.
3. Confirm Chrome websites appear as sanitized domains below the Typing section.
   The section may show the light note that it is based on Chrome foreground
   time. Full URLs, page titles, and page content must not appear.
4. Bring another app to the foreground and confirm the total usage and the
   corresponding app row continue updating while the window is open.
5. Open the native Settings window from the toolbar. Confirm Language,
   Tracking, and Privacy / Input Monitoring are present. Confirm Advanced →
   Diagnostics is collapsed by default; expand it only to inspect permission,
   Event Tap, IPC, Native Messaging, identifiers, and timestamps.
6. Switch between Follow System, 简体中文, and English. Confirm the Dashboard
   and Settings labels update without resetting any live aggregates.
7. Open the Input Monitoring action from Settings when permission is
   unavailable. Confirm the user-facing explanation remains aggregate-only and
   no typed content is displayed.

### Sprint 2B persistence smoke test

Run these checks against an Apple Development-signed Debug build. The
application stores daily aggregates locally; it does not store raw keyboard
events, typed text, URLs, titles, or page content.

1. Use two foreground apps for at least 65 seconds total, then leave the app
   running for one checkpoint interval. Confirm the dashboard still updates in
   seconds and the stored app totals do not jump by more than the elapsed
   foreground time.
2. Switch the frontmost app shortly before local midnight, then inspect the
   two calendar days. Confirm the interval is split at midnight and each day
   receives only its own seconds.
3. Type letters, digits, symbols, and spaces. After a checkpoint, quit and
   relaunch DayTrace. Confirm today's typing aggregates, per-app counts,
   sessions, and metric version are restored without duplication.
4. In Chrome, visit two sanitized domains for separate intervals. Confirm
   website time is nested under Chrome, does not increase total Mac usage, and
   survives a quit/relaunch after checkpointing. Confirm only the domains are
   visible.
5. Lock the Mac and put it to sleep for a few minutes while an app is active.
   After unlock/wake, confirm those intervals are absent and a fresh interval
   begins. Confirm `loginwindow` never appears as an app row.
6. Pause tracking, wait, resume, and confirm paused time is absent. Repeat a
   checkpoint without new activity and confirm values do not increase.
7. Switch between Follow System, 简体中文, and English. Confirm duration
   labels and persistence-related UI copy update without resetting runtime
   aggregates.
8. Repeat a checkpoint after a transient persistence failure in a test build,
   when available. Confirm the runtime snapshot remains usable and the next
   successful checkpoint does not duplicate the pre-failure interval.
9. Inspect the local Application Support store and runtime logs only for
   aggregate records and diagnostic status. Confirm no typed text, key codes,
   key sequences, URL, title, or page content is present.

Automated coverage for the persistence boundary includes same-day seconds,
local-midnight splitting, website exclusion from total usage, aggregate typing
and metric version, idempotent checkpointing, restart merge, injected time
zones, and runtime continuity after a persistence-open failure.

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

---

## 5. Technical Spike 01 implementation setup

Build the DayTrace App from the repository root:

```text
xcodebuild -project app/DayTraceSpike/DayTrace.xcodeproj \\
  -scheme DayTrace -configuration Debug build
```

Run the app from Xcode's Run action or LaunchServices. Directly executing the
unsigned bundle executable from a restricted automation shell can fail before
application code runs while AppKit registers the process with WindowServer;
that is an environment launch failure, not a tracker result.

Build the Native Messaging host separately, then load `extension/chrome/` as an
unpacked extension in `chrome://extensions` with Developer mode enabled. Use the
extension ID shown by Chrome when running:

```text
scripts/spike/install-native-host.sh <native-host-executable> <extension-id>
```

The app must be running before the host can deliver a domain message. The host
fails quickly when the app is unavailable and does not cache messages.

For typing validation, grant DayTrace access under System
Settings → Privacy & Security → Input Monitoring, relaunch the app, and execute
`T-KEY-001` and `T-KEY-002`. The implementation only exposes aggregate counts;
it does not print or persist key details.

The automated build may use `CODE_SIGNING_ALLOWED=NO` for compile and XCTest
validation only. It is not a valid human Input Monitoring runtime. Manual
permission and typing tests must launch the Apple Development-signed app from
Xcode Run with the stable bundle identifier `com.daytrace.spike`.
