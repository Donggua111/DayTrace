import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: DayTraceViewModel
    @Binding var languageRawValue: String
    @State private var selectedRange: HistoryRange = .today
    @State private var selectedApp: AppIdentity?
    @State private var selectedWebsite: String?
    @State private var searchText = ""
    @State private var timelineDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let snapshot = model.history(for: selectedRange, at: context.date)
            let comparison = model.comparison(for: selectedRange, at: context.date)
            let heatmapSnapshot = model.history(for: .last30Days, at: context.date)
            let timeline = model.timeline(for: timelineDate, now: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceL) {
                    header(snapshot: snapshot)
                    summary(snapshot: snapshot)
                    DailyTimelineView(
                        snapshot: timeline,
                        selectedDate: timelineDate,
                        now: context.date,
                        languageRawValue: languageRawValue,
                        canGoNext: timelineDate < Calendar.autoupdatingCurrent.startOfDay(for: context.date),
                        onPrevious: { timelineDate = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -1, to: timelineDate) ?? timelineDate },
                        onNext: { timelineDate = min(Calendar.autoupdatingCurrent.startOfDay(for: context.date), Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: timelineDate) ?? timelineDate) },
                        onToday: { timelineDate = Calendar.autoupdatingCurrent.startOfDay(for: context.date) }
                    )
                    comparisonSection(comparison: comparison)
                    heatmap(snapshot: heatmapSnapshot, asOf: context.date)
                    usageSection(snapshot: snapshot)
                    typingSection(snapshot: snapshot)
                }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, DayTraceDesign.spaceXL)
                .padding(.vertical, DayTraceDesign.spaceL)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(DayTraceDesign.pageBackground)
        }
        .frame(minWidth: 720, idealWidth: 900, minHeight: 680)
        .tint(DayTraceDesign.accent)
        .searchable(text: $searchText, placement: .toolbar, prompt: "history.search")
        .sheet(item: $selectedApp) { app in
            AppDetailView(app: app, snapshot: model.history(for: selectedRange), languageRawValue: languageRawValue)
        }
        .sheet(isPresented: Binding(
            get: { selectedWebsite != nil },
            set: { if !$0 { selectedWebsite = nil } }
        )) {
            if let selectedWebsite {
                WebsiteDetailView(domain: selectedWebsite, snapshot: model.history(for: selectedRange), languageRawValue: languageRawValue)
            }
        }
    }

    private func header(snapshot: HistoryUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
            Text("history.title")
                .font(DayTraceDesign.title)
            Picker("history.range.title", selection: $selectedRange) {
                ForEach(HistoryRange.allCases) { range in
                    Text(LocalizedStringKey(range.localizationKey)).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 620)
            Text(snapshot.endDate, format: .dateTime.year().month().day())
                .font(DayTraceDesign.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summary(snapshot: HistoryUsageSnapshot) -> some View {
        UsageCard {
            HStack(alignment: .top, spacing: DayTraceDesign.spaceXL) {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceXS) {
                    Text("history.totalUsage")
                        .font(DayTraceDesign.caption)
                        .foregroundStyle(.secondary)
                    Text(duration(snapshot.totalUsage))
                        .font(DayTraceDesign.metric)
                        .monospacedDigit()
                }
                Divider()
                    .frame(height: 48)
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceXS) {
                    Text("history.typedCharacters")
                        .font(DayTraceDesign.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.typingMetrics.typedCharacters, format: .number)
                        .font(DayTraceDesign.metricSmall)
                        .monospacedDigit()
                }
            }
        }
    }

    private func usageSection(snapshot: HistoryUsageSnapshot) -> some View {
        UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                DayTraceSectionHeader(title: "history.apps.title", systemImage: "macwindow")
                Divider()
                if filteredApps(snapshot).isEmpty {
                    Text(LocalizedStringKey(snapshot.appUsageByApp.isEmpty ? "history.apps.empty" : "history.search.empty"))
                        .font(DayTraceDesign.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredApps(snapshot), id: \.self) { app in
                        Button { selectedApp = app } label: {
                            AppUsageRow(app: app, duration: Text(duration(snapshot.appUsageByApp[app, default: 0])))
                        }
                        .buttonStyle(.plain)
                        }
                    }
                    if !categoryTotals(snapshot).isEmpty {
                        Divider()
                        DayTraceSectionHeader(title: "history.categories.title", systemImage: "folder")
                        ForEach(categoryTotals(snapshot).sorted(by: { $0.value > $1.value }), id: \.key) { category, value in
                            HStack {
                                Text(category)
                                Spacer()
                                Text(duration(value)).monospacedDigit()
                            }
                            .font(DayTraceDesign.body)
                        }
                    }
                    Divider()
                DayTraceSectionHeader(title: "history.websites.title", systemImage: "globe")
                if filteredDomains(snapshot).isEmpty {
                    Text(LocalizedStringKey(snapshot.websiteUsageByDomain.isEmpty ? "history.websites.empty" : "history.search.empty"))
                        .font(DayTraceDesign.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredDomains(snapshot), id: \.self) { domain in
                        Button { selectedWebsite = domain } label: {
                            WebsiteUsageRow(domain: domain, duration: Text(duration(snapshot.websiteUsageByDomain[domain, default: 0])))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func comparisonSection(comparison: UsagePeriodComparison) -> some View {
        return UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                DayTraceSectionHeader(title: "history.comparison.title", systemImage: "arrow.left.arrow.right")
                HStack(spacing: DayTraceDesign.spaceXL) {
                    comparisonMetric(title: "history.totalUsage", delta: comparison.totalUsage) { duration(abs($0)) }
                    comparisonMetric(title: "history.typedCharacters", delta: comparison.typedCharacters) { String(Int($0.rounded())) }
                }
                let changes = (comparison.topAppChanges + comparison.topWebsiteChanges)
                    .sorted {
                        if abs($0.delta) != abs($1.delta) { return abs($0.delta) > abs($1.delta) }
                        return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
                    }
                    .prefix(5)
                if !changes.isEmpty {
                    Divider()
                    Text("history.changes.title").font(DayTraceDesign.bodyMedium)
                    ForEach(Array(changes)) { change in
                        HStack(spacing: DayTraceDesign.spaceS) {
                            Image(systemName: change.kind == .app ? "macwindow" : "globe")
                                .foregroundStyle(.secondary).frame(width: 20)
                            Text(change.name).lineLimit(1)
                            Spacer()
                            Image(systemName: change.delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(change.delta >= 0 ? DayTraceDesign.positive : DayTraceDesign.attention)
                            Text(duration(abs(change.delta))).monospacedDigit()
                        }
                        .font(DayTraceDesign.caption)
                    }
                }
            }
        }
    }

    private func comparisonMetric(
        title: LocalizedStringKey,
        delta: AnalyticsDelta,
        format: (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceXS) {
            Text(title).font(DayTraceDesign.caption).foregroundStyle(.secondary)
            Text(delta.absolute == 0 ? "—" : format(delta.absolute))
                .font(DayTraceDesign.metricSmall).monospacedDigit()
            Text(LocalizedStringKey(
                delta.absolute == 0
                    ? "history.noChange"
                    : (delta.absolute > 0 ? "history.increased" : "history.decreased")
            ))
                .font(DayTraceDesign.caption)
                .foregroundStyle(delta.absolute >= 0 ? DayTraceDesign.positive : DayTraceDesign.attention)
        }
    }

    private func heatmap(snapshot: HistoryUsageSnapshot, asOf date: Date) -> some View {
        let maximum = snapshot.dailyTotals.map(\.totalUsage).max() ?? 0
        return UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                DayTraceSectionHeader(title: "history.heatmap.title", systemImage: "calendar")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                    ForEach(snapshot.dailyTotals) { day in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(DayTraceDesign.accent.opacity(maximum > 0 ? 0.12 + 0.78 * min(day.totalUsage / maximum, 1) : 0.12))
                            .frame(height: 22)
                            .accessibilityLabel(Text(day.date, format: .dateTime.year().month().day()))
                            .accessibilityValue(Text(duration(day.totalUsage)))
                    }
                }
                HStack {
                    Text("history.heatmap.subtitle").font(DayTraceDesign.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("history.averageDaily").font(DayTraceDesign.caption).foregroundStyle(.secondary)
                    Text(duration(DayTraceAnalytics.average(
                        for: snapshot,
                        asOf: date,
                        calendar: Calendar.autoupdatingCurrent
                    )))
                        .font(DayTraceDesign.caption).monospacedDigit()
                }
            }
        }
    }

    private func typingSection(snapshot: HistoryUsageSnapshot) -> some View {
        UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                DayTraceSectionHeader(title: "history.typing.title", systemImage: "keyboard")
                Divider()
                HStack {
                    Text("typingActivity.estimatedWords")
                        .font(DayTraceDesign.body)
                    Spacer()
                    Text(snapshot.typingMetrics.estimatedEnglishWords, format: .number)
                        .font(DayTraceDesign.bodyMedium)
                        .monospacedDigit()
                }
                HStack {
                    Text("typingActivity.sessions")
                        .font(DayTraceDesign.body)
                    Spacer()
                    Text(snapshot.typingSessions, format: .number)
                        .font(DayTraceDesign.bodyMedium)
                        .monospacedDigit()
                }
                HStack {
                    Text("typingActivity.activeTyping")
                        .font(DayTraceDesign.body)
                    Spacer()
                    Text(duration(snapshot.activeTypingDuration))
                        .font(DayTraceDesign.bodyMedium)
                        .monospacedDigit()
                }
            }
        }
    }

    private func sortedApps(_ snapshot: HistoryUsageSnapshot) -> [AppIdentity] {
        snapshot.appUsageByApp.keys.sorted {
            let left = snapshot.appUsageByApp[$0, default: 0]
            let right = snapshot.appUsageByApp[$1, default: 0]
            if left != right { return left > right }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func filteredApps(_ snapshot: HistoryUsageSnapshot) -> [AppIdentity] {
        HistorySearch.apps(sortedApps(snapshot), matching: searchText)
    }

    private func categoryTotals(_ snapshot: HistoryUsageSnapshot) -> [String: TimeInterval] {
        snapshot.appUsageByApp.reduce(into: [:]) { totals, entry in
            if let category = model.metadataStore.category(for: entry.key) {
                totals[category, default: 0] += entry.value
            }
        }
    }

    private func sortedDomains(_ snapshot: HistoryUsageSnapshot) -> [String] {
        snapshot.websiteUsageByDomain.keys.sorted {
            let left = snapshot.websiteUsageByDomain[$0, default: 0]
            let right = snapshot.websiteUsageByDomain[$1, default: 0]
            if left != right { return left > right }
            return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func filteredDomains(_ snapshot: HistoryUsageSnapshot) -> [String] {
        HistorySearch.domains(sortedDomains(snapshot), matching: searchText)
    }

    private func duration(_ seconds: TimeInterval) -> String {
        DayTraceDurationFormatter.string(
            seconds: seconds,
            locale: (AppLanguage(rawValue: languageRawValue) ?? .system).locale
        )
    }
}

enum HistorySearch {
    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func apps(_ apps: [AppIdentity], matching query: String) -> [AppIdentity] {
        let query = normalized(query)
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    static func domains(_ domains: [String], matching query: String) -> [String] {
        let query = normalized(query)
        guard !query.isEmpty else { return domains }
        return domains.filter { $0.localizedCaseInsensitiveContains(query) }
    }
}
