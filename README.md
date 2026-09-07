# DayTrace

DayTrace is a local-first macOS activity analytics application for tracking how the Mac is used without recording the user's actual typed content.

## Current stage

**Technical Spike complete → Internal Beta Foundation → Sprint 3 hardening**

Technical Spike 01 has validated the first implementation boundary. Sprint 1A
and 1B establish the first source-controlled, formally named engineering
baseline without changing the validated tracking or communication behavior.

## Validated foundation

- macOS only
- Native macOS app
- App foreground usage time
- Chrome → website/domain breakdown
- Privacy-preserving aggregate typing keystrokes
- Chrome Native Messaging over a user-only Unix domain socket
- No typed content, full URL, title, or page content storage
- Dashboard, native Settings scene, localization, and AppIcon
- Simplified Chinese + English UI, freely switchable
- Pause / Resume tracking
- History views for today, yesterday, rolling seven days, week, and month
- History usage rhythm heatmap, period comparisons, daily averages, and local summaries
- Drill-down views for Apps and sanitized Websites, local search, pinned items, and optional App categories
- Menu bar summary with pause/resume and display modes
- Launch-at-login control through the native ServiceManagement API
- Aggregate-only JSON export and an explicit delete-all-data flow
- Optional logical aggregate backups with deterministic retention; restore is intentionally deferred
- Detailed Timeline V2 with local app intervals and sanitized Chrome website child intervals
- Background Activity V1 with separate interval lanes for supported NookX visible activity and NetEase audio playback

Core Data + SQLite local persistence is part of the implemented Internal Beta
core. Daily aggregates remain canonical for totals and analytics; Timeline V2
adds a separate interval history for chronological detail without retaining
raw activity events.

Metadata such as pins and App categories is stored separately in UserDefaults
and never changes usage identity or historical aggregate values. Detailed
backups may include background interval metadata when explicitly requested;
typed content, full URLs, page content, audio samples, window content, and
clipboard data are not stored.

Background Activity V1 is a separate interval-only stream. It never adds time
to foreground totals, Chrome website parents, or typing metrics. NookX uses
public visible-window metadata, while NetEase uses a public CoreAudio process
output-running property. Detector availability is reported honestly when the
operating system cannot provide a reliable signal; no new sensitive permission
or private media API is used.

## Repository structure

```text
DayTrace/
├── README.md
├── docs/
│   ├── product/
│   │   └── PRD.md
│   ├── engineering/
│   │   └── DECISIONS.md
│   └── project/
│       ├── ROADMAP.md
│       └── TESTING.md
├── prompts/
│   └── TECHNICAL_SPIKE_01.md   # Historical spike brief
├── app/
│   └── DayTraceSpike/           # Transitional physical path; formal Xcode identity is DayTrace
│       ├── DayTrace.xcodeproj
│       ├── DayTraceSpike/       # Existing source directory; no broad directory move in Sprint 1
│       ├── DayTraceNativeHost/
│       └── DayTraceSpikeTests/
├── extension/
│   └── chrome/
├── scripts/
│   ├── design/
│   └── spike/
└── design/
```

## Repository rules

- Do not create version-copy folders such as `v0.1/`, `v0.2/`, `final/`, `final2/`, or backups of the whole repository.
- Use Git history for versioning and rollback.
- Do not place implementation files in the repository root.
- Do not create speculative folders that have no files/use yet.
- Do not add cloud, authentication, payment, telemetry, or public-network services unless a future product decision explicitly requires them.
- All user-facing UI strings must be localizable from the beginning.
- Do not track `DerivedData`, `xcuserdata`, `.xcuserstate`, `.xcresult`, build
  products, or `.DS_Store` files.

## Stable development identities

The current development identity is intentionally stable while the code-side
names are formalized:

```text
App bundle ID: com.daytrace.spike
Native Messaging host: com.daytrace.spike
```

These values must not be changed casually because they are connected to macOS
Input Monitoring/TCC identity and Chrome Native Messaging discovery.

## Build and test

For automated unsigned validation:

```text
xcodebuild -project app/DayTraceSpike/DayTrace.xcodeproj \
  -scheme DayTrace -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

xcodebuild -project app/DayTraceSpike/DayTrace.xcodeproj \
  -scheme DayTrace -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
```

Manual Input Monitoring verification must use an Apple Development-signed
Xcode Run build. An unsigned automation artifact is not a valid permission
runtime.
