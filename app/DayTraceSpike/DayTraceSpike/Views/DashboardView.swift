import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: DayTraceViewModel
    @Binding var languageRawValue: String

    @State private var appSort: AppSortOption = .usage
    @State private var showAllApps = false

    private let topAppLimit = 5

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceL) {
                    header(at: context.date)
                    currentActivityCard(at: context.date)
                    BackgroundCurrentActivityView(model: model, date: context.date)
                    favoritesCard(at: context.date)
                    appUsageCard(at: context.date)
                    TypingActivityView(
                        snapshot: model.typingActivity(at: context.date),
                        languageRawValue: languageRawValue
                    )
                    websiteUsageCard(at: context.date)
                    BackgroundActivityCard(model: model, date: context.date)
                }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, DayTraceDesign.spaceXL)
                .padding(.vertical, DayTraceDesign.spaceL)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(DayTraceDesign.pageBackground)
        }
        .frame(minWidth: 720, idealWidth: 900, minHeight: 680)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    if model.foregroundTracker.isTracking {
                        model.foregroundTracker.pause()
                    } else {
                        model.foregroundTracker.resume()
                    }
                } label: {
                    Label(
                        LocalizedStringKey(model.foregroundTracker.isTracking ? "tracking.pause" : "tracking.resume"),
                        systemImage: model.foregroundTracker.isTracking ? "pause.fill" : "play.fill"
                    )
                }
                .help(LocalizedStringKey(model.foregroundTracker.isTracking ? "tracking.pause" : "tracking.resume"))

                Button {
                    model.foregroundTracker.refreshNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("action.refresh")

                languageMenu
                settingsButton
            }
        }
        .tint(DayTraceDesign.accent)
    }

    private func header(at date: Date) -> some View {
        HStack(alignment: .top, spacing: DayTraceDesign.spaceL) {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceS) {
                Text("header.title")
                    .font(DayTraceDesign.title)
                Text("dashboard.subtitle")
                    .font(DayTraceDesign.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DayTraceDesign.spaceM)

            VStack(alignment: .trailing, spacing: DayTraceDesign.spaceS) {
                Text("dashboard.today")
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)
                durationText(model.totalUsage(at: date))
                    .font(DayTraceDesign.metric)
                    .monospacedDigit()
                DayTraceStatusBadge(
                    title: LocalizedStringKey(model.foregroundTracker.isTracking ? "status.running" : "status.paused"),
                    systemImage: model.foregroundTracker.isTracking ? "record.circle.fill" : "pause.circle.fill",
                    color: model.foregroundTracker.isTracking ? DayTraceDesign.positive : DayTraceDesign.attention
                )
            }
        }
    }

    private var languageMenu: some View {
        Menu {
            Picker("language.menu", selection: $languageRawValue) {
                ForEach(AppLanguage.allCases) { language in
                    Text(LocalizedStringKey(language.localizationKey))
                        .tag(language.rawValue)
                }
            }
        } label: {
            Label("language.menu", systemImage: "globe")
        }
        .help("language.menuHelp")
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            NativeSettingsButton()
        } else {
            Button {
                openSettingsLegacy()
            } label: {
                Label("settings.title", systemImage: "gearshape")
            }
        }
    }

    private func appUsageCard(at date: Date) -> some View {
        UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                HStack(alignment: .firstTextBaseline) {
                    DayTraceSectionHeader(title: "dashboard.apps.title", systemImage: "macwindow")

                    Menu {
                        Picker("dashboard.apps.sort", selection: $appSort) {
                            ForEach(AppSortOption.allCases) { option in
                                Text(LocalizedStringKey(option.localizationKey))
                                    .tag(option)
                            }
                        }
                    } label: {
                        Label("dashboard.apps.sort", systemImage: "arrow.up.arrow.down")
                            .font(DayTraceDesign.caption)
                    }
                    .menuStyle(.borderlessButton)
                }

                Divider()

                if sortedApps(at: date).isEmpty {
                    Text("dashboard.apps.empty")
                        .font(DayTraceDesign.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(displayedApps(at: date), id: \.self) { app in
                        AppUsageRow(app: app, duration: durationText(model.appUsage(for: app, at: date)))
                            .contextMenu {
                                Button {
                                    model.metadataStore.toggleFavorite(app: app)
                                } label: {
                                    Label(
                                        model.metadataStore.isFavorite(app: app) ? "metadata.unpin" : "metadata.pin",
                                        systemImage: model.metadataStore.isFavorite(app: app) ? "pin.slash" : "pin"
                                    )
                                }
                                if !model.metadataStore.customCategories.isEmpty {
                                    Menu("metadata.category") {
                                        Button("metadata.uncategorized") {
                                            model.metadataStore.setCategory(nil, for: app)
                                        }
                                        ForEach(model.metadataStore.customCategories, id: \.self) { category in
                                            Button(category) {
                                                model.metadataStore.setCategory(category, for: app)
                                            }
                                        }
                                    }
                                }
                            }
                    }

                    if sortedApps(at: date).count > topAppLimit {
                        Button(showAllApps ? "dashboard.apps.showLess" : "dashboard.apps.showAll") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showAllApps.toggle()
                            }
                        }
                        .buttonStyle(.link)
                        .font(DayTraceDesign.bodyMedium)
                    }
                }
            }
        }
    }

    private func currentActivityCard(at date: Date) -> some View {
        UsageCard {
            HStack(spacing: DayTraceDesign.spaceM) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(DayTraceDesign.accent)
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceXS) {
                    Text("dashboard.currentActivity.title").font(DayTraceDesign.caption).foregroundStyle(.secondary)
                    if let app = model.foregroundTracker.currentApp {
                        Text(app.displayName).font(DayTraceDesign.bodyMedium)
                        if model.domainTracker.currentDomain != "—" {
                            Text(model.domainTracker.currentDomain)
                                .font(DayTraceDesign.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("dashboard.currentActivity.none").font(DayTraceDesign.body)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: DayTraceDesign.spaceXS) {
                    Text("dashboard.currentActivity.session").font(DayTraceDesign.caption).foregroundStyle(.secondary)
                    Text(DayTraceDurationFormatter.string(seconds: model.foregroundTracker.currentElapsed(at: date), locale: selectedLocale))
                        .font(DayTraceDesign.bodyMedium).monospacedDigit()
                }
            }
        }
    }

    private func websiteUsageCard(at date: Date) -> some View {
        UsageCard {
            VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                DayTraceSectionHeader(title: "dashboard.websites.title", systemImage: "globe")

                Label("dashboard.websites.note", systemImage: "arrow.down.right")
                    .font(DayTraceDesign.caption)
                    .foregroundStyle(.secondary)

                Divider()

                if domainNames(at: date).isEmpty {
                    Text("dashboard.websites.empty")
                        .font(DayTraceDesign.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(domainNames(at: date), id: \.self) { domain in
                        WebsiteUsageRow(
                            domain: domain,
                            duration: durationText(model.websiteUsage(for: domain, at: date))
                        )
                        .contextMenu {
                            Button {
                                model.metadataStore.toggleFavorite(website: domain)
                            } label: {
                                Label(
                                    model.metadataStore.isFavorite(website: domain) ? "metadata.unpin" : "metadata.pin",
                                    systemImage: model.metadataStore.isFavorite(website: domain) ? "pin.slash" : "pin"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func favoritesCard(at date: Date) -> some View {
        let apps = sortedApps(at: date).filter { model.metadataStore.isFavorite(app: $0) }
        let domains = domainNames(at: date).filter { model.metadataStore.isFavorite(website: $0) }
        if !apps.isEmpty || !domains.isEmpty {
            UsageCard {
                VStack(alignment: .leading, spacing: DayTraceDesign.spaceM) {
                    DayTraceSectionHeader(title: "metadata.favorites", systemImage: "pin.fill")
                    ForEach(apps, id: \.self) { app in
                        AppUsageRow(app: app, duration: durationText(model.appUsage(for: app, at: date)))
                    }
                    ForEach(domains, id: \.self) { domain in
                        WebsiteUsageRow(domain: domain, duration: durationText(model.websiteUsage(for: domain, at: date)))
                    }
                }
            }
        }
    }

    private func sortedApps(at date: Date) -> [AppIdentity] {
        let apps = Set(model.appIdentities(at: date))

        switch appSort {
        case .usage:
            return apps.sorted {
                let left = model.appUsage(for: $0, at: date)
                let right = model.appUsage(for: $1, at: date)
                if left == right { return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                return left > right
            }
        case .name:
            return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    private func displayedApps(at date: Date) -> [AppIdentity] {
        let apps = sortedApps(at: date)
        return showAllApps ? apps : Array(apps.prefix(topAppLimit))
    }

    private func domainNames(at date: Date) -> [String] {
        let domains = Set(model.websiteDomains(at: date))
        return domains.sorted {
            let left = model.websiteUsage(for: $0, at: date)
            let right = model.websiteUsage(for: $1, at: date)
            if left == right { return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            return left > right
        }
    }

    private func durationText(_ seconds: TimeInterval) -> Text {
        let locale = (AppLanguage(rawValue: languageRawValue) ?? .system).locale
        return Text(verbatim: DayTraceDurationFormatter.string(seconds: seconds, locale: locale))
    }

    private var selectedLocale: Locale {
        (AppLanguage(rawValue: languageRawValue) ?? .system).locale
    }

    private func openSettingsLegacy() {
        let menuAction = Selector(("menuAction:"))
        if let settingsItem = NSApp.mainMenu?.items.first?.submenu?.items.first(where: { $0.action == menuAction }) {
            NSApp.sendAction(menuAction, to: settingsItem.target, from: settingsItem)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}

@available(macOS 14.0, *)
private struct NativeSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button {
            openSettings()
        } label: {
            Label("settings.title", systemImage: "gearshape")
        }
    }
}

private enum AppSortOption: String, CaseIterable, Identifiable {
    case usage
    case name

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .usage: return "dashboard.apps.sortUsage"
        case .name: return "dashboard.apps.sortName"
        }
    }
}
