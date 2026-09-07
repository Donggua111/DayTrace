import SwiftUI

struct BackgroundActivityCard: View {
    @ObservedObject var model: DayTraceViewModel
    let date: Date

    var body: some View {
        let summary = model.backgroundSummary(for: date, now: date)
        UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                DayTraceSectionHeader(title: "background.dashboard.title", systemImage: "waveform")
                Text("background.dashboard.note")
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
                Divider()
                if summary.durationsByApp.isEmpty {
                    Text("background.dashboard.empty")
                        .font(DayTraceDesign.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.durationsByApp.sorted { lhs, rhs in
                        if lhs.value != rhs.value { return lhs.value > rhs.value }
                        return lhs.key.displayName.localizedCaseInsensitiveCompare(rhs.key.displayName) == .orderedAscending
                    }, id: \.key) { app, duration in
                        HStack(spacing: DayTraceDesign.spaceS) {
                            Image(systemName: "waveform")
                                .foregroundStyle(DayTraceDesign.accent)
                                .frame(width: 22)
                            Text(app.displayName)
                                .font(DayTraceDesign.body)
                                .lineLimit(1)
                            Spacer()
                            Text(DayTraceDurationFormatter.string(seconds: duration, locale: selectedLocale))
                                .font(DayTraceDesign.bodyMedium)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var selectedLocale: Locale {
        (AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.system.rawValue) ?? .system).locale
    }
}

struct BackgroundCurrentActivityView: View {
    @ObservedObject var model: DayTraceViewModel
    let date: Date

    var body: some View {
        let active = model.backgroundActivity.detectorSnapshots.filter { $0.isActive }
        if !active.isEmpty {
            UsageCard {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceS) {
                    DayTraceSectionHeader(title: "background.current.title", systemImage: "waveform.circle.fill")
                    ForEach(active) { snapshot in
                        HStack(spacing: DayTraceDesign.spaceS) {
                            Image(systemName: snapshot.activityKind == .audioPlayback ? "speaker.wave.2.fill" : "rectangle.on.rectangle")
                                .foregroundStyle(DayTraceDesign.positive)
                                .frame(width: 22)
                            Text(snapshot.app.displayName)
                                .font(DayTraceDesign.bodyMedium)
                            Text(LocalizedStringKey(snapshot.activityKind.localizationKey))
                                .font(DayTraceDesign.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(snapshot.observedAt, format: .dateTime.hour().minute().second())
                                .font(DayTraceDesign.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("background.current.note")
                        .font(DayTraceDesign.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct BackgroundActivityTimelineView: View {
    @ObservedObject var model: DayTraceViewModel
    let date: Date
    let now: Date

    var body: some View {
        let summary = model.backgroundSummary(for: date, now: now)
        UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                DayTraceSectionHeader(title: "background.timeline.title", systemImage: "rectangle.split.3x1")
                Text("background.timeline.note")
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
                Divider()
                if summary.intervals.isEmpty {
                    Text("background.timeline.empty")
                        .font(DayTraceDesign.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.intervals) { interval in
                        HStack(spacing: DayTraceDesign.spaceS) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(interval.activityKind == .audioPlayback ? DayTraceDesign.accent : DayTraceDesign.attention)
                                .frame(width: 4, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(interval.app.displayName)
                                    .font(DayTraceDesign.bodyMedium)
                                Text(LocalizedStringKey(interval.activityKind.localizationKey))
                                    .font(DayTraceDesign.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(DayTraceDurationFormatter.string(seconds: interval.duration, locale: selectedLocale))
                                .font(DayTraceDesign.bodyMedium)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var selectedLocale: Locale {
        (AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.system.rawValue) ?? .system).locale
    }
}

struct BackgroundActivitySettingsContent: View {
    @ObservedObject var model: DayTraceViewModel
    @State private var deleteConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
            Toggle("background.settings.enabled", isOn: Binding(
                get: { model.backgroundActivity.backgroundActivityEnabled },
                set: { _ = model.setBackgroundActivityEnabled($0) }
            ))
            Text("background.settings.note")
                .font(DayTraceDesign.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(model.backgroundActivity.detectors, id: \.identifier) { detector in
                Toggle(isOn: Binding(
                    get: { model.backgroundActivity.isDetectorEnabled(detector) },
                    set: { model.setBackgroundDetectorEnabled($0, identifier: detector.identifier) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detector.app.displayName)
                        Text(LocalizedStringKey(detector.activityKind.localizationKey))
                            .font(DayTraceDesign.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!model.backgroundActivity.backgroundActivityEnabled)
                HStack {
                    Text("background.settings.detectorState")
                        .font(DayTraceDesign.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(LocalizedStringKey(detectorStateKey(for: detector)))
                        .font(DayTraceDesign.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("background.settings.intervals")
                Spacer()
                Text(model.backgroundStatistics().intervalCount, format: .number)
                    .monospacedDigit()
            }
            .font(DayTraceDesign.caption)
            Button("background.settings.delete", role: .destructive) {
                deleteConfirmationPresented = true
            }
        }
        .alert("background.settings.deleteTitle", isPresented: $deleteConfirmationPresented) {
            Button("settings.deleteData.cancel", role: .cancel) {}
            Button("settings.deleteData.confirm", role: .destructive) {
                _ = model.deleteBackgroundActivityHistory()
            }
        } message: {
            Text("background.settings.deleteMessage")
        }
    }

    private func detectorStateKey(for detector: BackgroundActivityDetector) -> String {
        guard let snapshot = model.backgroundActivity.detectorSnapshots.first(where: { $0.identifier == detector.identifier }) else {
            return "background.detector.notObserved"
        }
        switch snapshot.state {
        case .active: return "background.detector.active"
        case .inactive: return "background.detector.inactive"
        case .unavailable: return "background.detector.unavailable"
        }
    }
}
