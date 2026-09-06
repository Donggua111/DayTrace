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

    var body: some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceL) {
            HStack(spacing: DayTraceDesign.spaceM) {
                AppIconView(app: app)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceXS) {
                    Text(app.displayName).font(DayTraceDesign.title)
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
            Spacer()
        }
        .padding(DayTraceDesign.spaceXL)
        .frame(width: 460, height: 300, alignment: .topLeading)
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

    var body: some View {
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceL) {
            Label(domain, systemImage: "globe").font(DayTraceDesign.title)
            Text("history.websiteDetail.subtitle").font(DayTraceDesign.body).foregroundStyle(.secondary)
            UsageCard {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                    detailRow("history.totalUsage", duration(snapshot.websiteUsageByDomain[domain, default: 0]))
                    detailRow("history.shareOfChrome", percentage)
                }
            }
            Spacer()
        }
        .padding(DayTraceDesign.spaceXL)
        .frame(width: 460, height: 250, alignment: .topLeading)
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
