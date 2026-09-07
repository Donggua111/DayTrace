import SwiftUI

struct DailyTimelineView: View {
    let snapshot: DailyTimelineSnapshot
    let selectedDate: Date
    let now: Date
    let languageRawValue: String
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                HStack {
                    DayTraceSectionHeader(title: "timeline.title", systemImage: "timeline.selection")
                    Spacer()
                    Button(action: onPrevious) { Image(systemName: "chevron.left") }
                        .buttonStyle(.borderless)
                    Button(action: onToday) { Text("timeline.today") }
                        .buttonStyle(.borderless)
                    Button(action: onNext) { Image(systemName: "chevron.right") }
                        .buttonStyle(.borderless)
                        .disabled(!canGoNext)
                }
                Text(selectedDate, format: .dateTime.year().month().day())
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
                Divider()
                if snapshot.isRecorded {
                    timelineStrip
                    Divider()
                    LazyVStack(alignment: .leading, spacing: DayTraceDesign.spaceS) {
                        ForEach(snapshot.appIntervals) { app in
                            TimelineAppRow(
                                interval: app,
                                websites: snapshot.websiteIntervals.filter { $0.parentAppIntervalID == app.id || overlaps($0, app) },
                                gaps: app.app.bundleIdentifier == "com.google.Chrome" ? snapshot.chromeGaps.filter { overlaps($0, app) } : [],
                                languageRawValue: languageRawValue
                            )
                        }
                    }
                } else {
                    Text("timeline.empty")
                        .font(DayTraceDesign.body)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, DayTraceDesign.spaceM)
                }
            }
        }
    }

    private var timelineStrip: some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceXS) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(DayTraceDesign.secondarySurface)
                    ForEach(snapshot.appIntervals) { interval in
                        let position = stripPosition(interval.start, width: proxy.size.width)
                        let width = max(2, proxy.size.width * stripDuration(interval.duration))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(DayTraceDesign.accent.opacity(0.75))
                            .frame(width: min(width, proxy.size.width - position))
                            .offset(x: position)
                            .accessibilityLabel(Text(interval.app.displayName))
                            .accessibilityValue(Text(duration(interval.duration)))
                    }
                }
            }
            .frame(height: 18)
            HStack {
                Text("timeline.midnight"); Spacer(); Text("timeline.now")
            }
            .font(DayTraceDesign.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func stripPosition(_ date: Date, width: CGFloat) -> CGFloat {
        let start = Calendar.autoupdatingCurrent.startOfDay(for: selectedDate)
        return CGFloat(max(0, min(1, date.timeIntervalSince(start) / 86_400))) * width
    }

    private func stripDuration(_ value: TimeInterval) -> CGFloat {
        CGFloat(max(0, min(1, value / 86_400)))
    }

    private func overlaps(_ website: TimelineWebsiteInterval, _ app: TimelineAppInterval) -> Bool {
        website.start < app.end && website.end > app.start
    }

    private func overlaps(_ gap: TimelineGap, _ app: TimelineAppInterval) -> Bool {
        gap.start < app.end && gap.end > app.start
    }

    private func duration(_ value: TimeInterval) -> String {
        DayTraceDurationFormatter.string(
            seconds: value,
            locale: (AppLanguage(rawValue: languageRawValue) ?? .system).locale
        )
    }
}

private struct TimelineAppRow: View {
    let interval: TimelineAppInterval
    let websites: [TimelineWebsiteInterval]
    let gaps: [TimelineGap]
    let languageRawValue: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceS) {
            Button { expanded.toggle() } label: {
                HStack(spacing: DayTraceDesign.spaceS) {
                    Image(systemName: interval.app.bundleIdentifier == "com.google.Chrome" ? "globe" : "app.fill")
                        .foregroundStyle(DayTraceDesign.accent)
                        .frame(width: 22)
                    Text(interval.app.displayName).lineLimit(1)
                    Spacer()
                    Text(duration(interval.duration)).monospacedDigit()
                    if interval.app.bundleIdentifier == "com.google.Chrome" && (!websites.isEmpty || !gaps.isEmpty) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(DayTraceDesign.body)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(timeRange(interval.start, interval.end)))
            if expanded {
                ForEach(websites) { website in
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text(website.domain)
                        Spacer()
                        Text(duration(website.duration)).monospacedDigit()
                    }
                    .font(DayTraceDesign.caption)
                    .padding(.leading, DayTraceDesign.spaceL)
                }
                ForEach(gaps) { gap in
                    HStack {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text("timeline.unattributedChrome")
                        Spacer()
                        Text(duration(gap.duration)).monospacedDigit()
                    }
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DayTraceDesign.spaceL)
                }
            }
        }
    }

    private func duration(_ value: TimeInterval) -> String {
        DayTraceDurationFormatter.string(seconds: value, locale: (AppLanguage(rawValue: languageRawValue) ?? .system).locale)
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = (AppLanguage(rawValue: languageRawValue) ?? .system).locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
