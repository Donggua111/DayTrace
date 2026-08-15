# DayTrace Engineering & Product Decisions

This file records durable decisions that future agents should not silently reverse.

---

## 2026-08-15 — macOS-only V1

**Decision:** V1 targets macOS only.

**Reason:** The current product goal is personal Mac activity analytics. Cross-platform support would increase scope before the core measurement model is validated.

---

## 2026-08-15 — Local-first V1

**Decision:** No account, cloud sync, or backend server in V1.

**Reason:** Reduce operational complexity, security exposure, and privacy risk.

---

## 2026-08-15 — App-first usage hierarchy

**Decision:** Foreground application is the primary usage layer. Browser websites are children of their host browser.

Example:

```text
Chrome 3h
└── chatgpt.com 1h
```

Website time must not increase total computer usage time.

---

## 2026-08-15 — Foreground time is Usage Time

**Decision:** V1 Usage Time equals frontmost-application time while tracking is enabled and the Mac is awake/unlocked.

**Decision:** V1 does not expose Active, Passive, or Idle time.

**Reason:** The user wants a simple, predictable foreground-time metric rather than behavioral inference.

---

## 2026-08-15 — Sleep and lock excluded

**Decision:** Time while macOS is asleep or locked is not assigned to the previous foreground app.

---

## 2026-08-15 — Typing privacy boundary

**Decision:** DayTrace must not persist actual typed text.

**Decision:** The lower-level exact typing metric is aggregate Typing Keystrokes.

**Decision:** High-level Chinese-character and English-word values are estimates unless a privacy-preserving exact-count API is proven feasible.

---

## 2026-08-15 — Chrome stores domain only

**Decision:** V1 website tracking stores domain only.

Do not store:
- complete URL,
- path,
- query,
- page title,
- page content.

---

## 2026-08-15 — Categories are a separate dimension

**Decision:** AI / Development / Study / Productivity / Communication / Entertainment / Other are analytical categories, not replacements for the App → Website hierarchy.

**Decision:** User category overrides take priority over default mappings.

---

## 2026-08-15 — Native Mac app with Dock + menu bar

**Decision:** While running, DayTrace remains available in both the Dock and menu bar.

Closing the main window does not stop tracking. Quit does.

---

## 2026-08-15 — User-configurable launch at login

**Decision:** Launch at Login is controlled by the user in Settings.

---

## 2026-08-15 — User-configurable menu bar display

**Decision:** V1 menu bar display supports:
- Icon only
- Usage Time
- Typing Keystrokes
- Usage Time + Typing Keystrokes

---

## 2026-08-15 — Bilingual UI from first implementation

**Decision:** Simplified Chinese and English are first-class V1 requirements.

Supported modes:
- Follow System
- Simplified Chinese
- English

All user-facing strings must be localizable from the beginning.

---

## 2026-08-15 — Minimal stage/version model

**Decision:** Use only:
- Technical Spike
- Internal Beta
- 1.0

Do not create copied repositories or directories for many intermediate versions. Use Git history for versioning.

---

## 2026-08-15 — Open-source decision deferred

**Decision:** Do not assume the project will be open source or closed source. No irreversible product decision should depend on either path yet.
