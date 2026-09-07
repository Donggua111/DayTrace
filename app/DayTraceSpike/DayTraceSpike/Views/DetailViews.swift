import Charts
import SwiftUI

enum UsageDetailMetrics {
    static func share(of value: TimeInterval, total: TimeInterval) -> Double? {
        guard value.isFinite, total.isFinite, total > 0 else { return nil }
        let percentage = max(0, value) / total * 100
        return percentage.isFinite ? percentage : nil
    }
}

struct AppDetailView: View {
    let app: AppIdentity
    let snapshot: HistoryUsageSnapshot
    let languageRawValue: String
    let model: DayTraceViewModel
    let range: HistoryRange

    var body: some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceL) {
            HStack(spacing: DayTraceDesign.spaceM) {
                AppIconView(app: app)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceXS) {
                    Text(model.metadataStore.presentationName(for: app)).font(DayTraceDesign.title)
                    Text("history.appDetail.subtitle").font(DayTraceDesign.body).foregroundStyle(.secondary)
                }
            }
            UsageCard {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                    detailRow("history.totalUsage", duration(snapshot.appUsageByApp[app, default: 0]))
                    detailRow("history.shareOfTotal", percentage)
                    detailRow("typingActivity.typedCharacters", count)
                }
            }
            UsageCard {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                    DayTraceSectionHeader(title: "history.detail.trend", systemImage: "chart.bar")
                    let trend = model.dailyAppTrend(for: app, range: range)
                    Chart(trend) { point in
                        BarMark(x: .value("history.detail.day", point.date, unit: .day), y: .value("history.detail.duration", point.totalUsage))
                            .foregroundStyle(DayTraceDesign.accent.gradient)
                    }
                    .frame(height: 120)
                    .accessibilityLabel(Text("history.detail.trend"))
                }
            }
            Spacer()
        }
        .padding(DayTraceDesign.spaceXL)
        .frame(width: 520, height: 470, alignment: .topLeading)
    }

    private var selectedLocale: Locale { (AppLanguage(rawValue: languageRawValue) ?? .system).locale }
    private var percentage: String {
        guard let value = UsageDetailMetrics.share(
            of: snapshot.appUsageByApp[app, default: 0],
            total: snapshot.totalUsage
        ) else { return "—" }
        return String(format: "%.1f%%", value)
    }
    private var count: String { snapshot.typingAppMetricsByApp[app].map { String($0.typedCharacters) } ?? "—" }
    private func duration(_ value: TimeInterval) -> String { DayTraceDurationFormatter.string(seconds: value, locale: selectedLocale) }
    private func detailRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).monospacedDigit() }
    }
}

struct WebsiteDetailView: View {
    let domain: String
    let snapshot: HistoryUsageSnapshot
    let languageRawValue: String
    let model: DayTraceViewModel
    let range: HistoryRange

    var body: some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceL) {
            Label(model.metadataStore.presentationName(for: domain), systemImage: "globe").font(DayTraceDesign.title)
            Text("history.websiteDetail.subtitle").font(DayTraceDesign.body).foregroundStyle(.secondary)
            UsageCard {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                    detailRow("history.totalUsage", duration(snapshot.websiteUsageByDomain[domain, default: 0]))
                    detailRow("history.shareOfChrome", percentage)
                }
            }
            UsageCard {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                    DayTraceSectionHeader(title: "history.detail.trend", systemImage: "chart.bar")
                    let trend = model.dailyWebsiteTrend(for: domain, range: range)
                    Chart(trend) { point in
                        BarMark(x: .value("history.detail.day", point.date, unit: .day), y: .value("history.detail.duration", point.totalUsage))
                            .foregroundStyle(DayTraceDesign.accent.gradient)
                    }
                    .frame(height: 120)
                    .accessibilityLabel(Text("history.detail.trend"))
                }
            }
            Spacer()
        }
        .padding(DayTraceDesign.spaceXL)
        .frame(width: 520, height: 420, alignment: .topLeading)
    }

    private var selectedLocale: Locale { (AppLanguage(rawValue: languageRawValue) ?? .system).locale }
    private var chromeUsage: TimeInterval {
        snapshot.appUsageByApp.filter { $0.key.bundleIdentifier == "com.google.Chrome" }.values.reduce(0, +)
    }
    private var percentage: String {
        guard let value = UsageDetailMetrics.share(
            of: snapshot.websiteUsageByDomain[domain, default: 0],
            total: chromeUsage
        ) else { return "—" }
        return String(format: "%.1f%%", value)
    }
    private func duration(_ value: TimeInterval) -> String { DayTraceDurationFormatter.string(seconds: value, locale: selectedLocale) }
    private func detailRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).monospacedDigit() }
    }
}
