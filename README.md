# DayTrace

DayTrace is a local-first macOS activity analytics application for tracking how the Mac is used without recording the user's actual typed content.

## Current stage

**Product Discovery complete → Technical Spike next**

The product requirements are frozen enough to begin technical validation. Production architecture is intentionally **not** frozen until the high-risk technical capabilities have been validated.

## V1 direction

- macOS only
- Native macOS app
- Dock presence + menu bar presence while running
- Optional Launch at Login
- Local-only storage
- No account system
- No cloud sync
- App foreground usage time
- Chrome → website/domain breakdown
- Daily typing analytics
- Estimated Chinese character count
- Estimated English word count
- Raw typing keystroke count as lower-level metric
- Categories such as AI / Development / Study
- Simplified Chinese + English UI, freely switchable
- Pause / Resume tracking

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
│   └── TECHNICAL_SPIKE_01.md
├── app/                    # Created by Codex during the spike
├── extension/              # Created only when needed by the spike
│   └── chrome/
└── scripts/                # Created only when useful
```

## Repository rules

- Do not create version-copy folders such as `v0.1/`, `v0.2/`, `final/`, `final2/`, or backups of the whole repository.
- Use Git history for versioning and rollback.
- Do not place implementation files in the repository root.
- Do not create speculative folders that have no files/use yet.
- Do not add cloud, authentication, payment, telemetry, or public-network services unless a future product decision explicitly requires them.
- All user-facing UI strings must be localizable from the beginning.
