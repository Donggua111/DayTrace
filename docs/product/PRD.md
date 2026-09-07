# DayTrace Product Requirements Document

**Status:** Product Discovery complete; ready for technical validation  
**Platform:** macOS only  
**Product form:** Native macOS application + Chrome extension for website-domain sensing  
**Data model philosophy:** Local-first, privacy-first, no account required

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

### 5.1 High-level estimated writing

The primary high-level typing presentation should be:

- **Estimated Chinese Characters / 预计中文字数**
- **Estimated English Words / 预计英文单词数**

These values are estimates and must be visually marked as approximate where appropriate.

The product must never falsely present an estimate as an exact linguistic count.

### 5.2 Lower-level Typing Keystrokes

DayTrace also records an exact aggregate count of typing-related keystrokes.

Typing-related keystrokes may include:
- letters,
- numbers,
- punctuation,
- Space,
- Enter/Return,
- Tab,
- Backspace/Delete.

Modifier/system-control keys should not increase the typing-keystroke count by themselves:
- Shift
- Command
- Control
- Option
- Fn
- Caps Lock
- volume keys
- brightness keys
- function/media keys

The implementation may transiently inspect a key event only to classify it. It must not persist the actual key value or reconstruct typed text.

### 5.3 Typing breakdown

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

### 5.4 English word estimation

The exact algorithm is an engineering decision to validate later.

Desired product behavior:
- estimate English word count without retaining actual text,
- use aggregate typing signals such as word-boundary events where possible,
- store only aggregate numeric counters needed for the estimate.

### 5.5 Chinese character estimation

Chinese IME input means keystrokes do not map directly to final characters.

Desired product behavior:
1. Prefer a privacy-preserving method that can count committed character quantity without retaining character content, if macOS APIs make this technically reliable and appropriate.
2. Otherwise use a clearly labeled statistical estimate.
3. Never store reconstructed Chinese text.

This is not part of the first technical spike unless needed to validate feasibility.

---

## 6. Application hierarchy and analytical dimensions

### 6.1 Primary hierarchy: App → Website

The main usage hierarchy is software-first.

Example:

```text
Chrome
└── Websites

VS Code

ChatGPT
```

Websites remain nested under their host browser.

### 6.2 Category dimension

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

### 6.3 User overrides

DayTrace can provide default category mappings.

A user's manual category choice must override the default mapping.

V1 needs category reassignment; it does not need an unlimited/custom category-management system.

---

## 7. Application runtime behavior

### 7.1 Dock
While DayTrace is running:
- it remains visible in the Dock,
- clicking the Dock app icon opens or restores the main DayTrace window,
- if the main window already exists, it should be brought forward.

### 7.2 Menu bar
While DayTrace is running, it also maintains a menu bar presence.

The menu bar provides:
- quick daily summary,
- Open DayTrace,
- Pause Tracking / Resume Tracking,
- Settings,
- Quit DayTrace.

### 7.3 Closing the main window
Closing the dashboard window does not quit DayTrace and does not stop tracking.

### 7.4 Quitting
`Command-Q` or `Quit DayTrace` fully exits the application and stops tracking.

### 7.5 Pause Tracking
Pause Tracking stops all activity collection for the paused interval:
- app usage,
- website usage,
- typing keystrokes,
- estimated writing counters.

Resume Tracking starts collection again from that moment.

No retroactive inference should fill in the paused interval.

---

## 8. Launch at Login

Launch at Login is user-configurable.

Settings must provide:
- `Launch DayTrace at Login` on/off

DayTrace must not require launch-at-login to function.

---

## 9. Menu bar display customization

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

## 10. Main dashboard

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

## 11. Settings

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

## 12. Localization requirements

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

## 13. Privacy requirements

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

## 14. Non-goals for V1

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
- open-source publication decision

These can be reconsidered after the Mac local-first product is stable.

---

## 15. V1 completion criteria

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

## 16. Development stages

Only three major project stages should be used:

### Technical Spike
Validate the technically risky capabilities before freezing production architecture.

### Internal Beta
A usable local build that the primary user can run daily for real-world testing.

### 1.0
A stable personal-use release after dogfooding and verification.

Do not create duplicate repository copies for each stage. Use Git commits/tags/branches as appropriate.
