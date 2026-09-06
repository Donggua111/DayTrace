import AppKit
import SwiftUI

enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Equatable {
    case iconOnly
    case usage
    case typing
    case usageAndTyping

    static let storageKey = "daytrace.menuBarDisplayMode"
    static let defaultValue: Self = .usage

    var id: String { rawValue }

    static func resolved(rawValue: String?) -> Self {
        guard let rawValue, let value = Self(rawValue: rawValue) else {
            return defaultValue
        }
        return value
    }

    var localizationKey: String {
        switch self {
        case .iconOnly: return "menuBar.display.iconOnly"
        case .usage: return "menuBar.display.usage"
        case .typing: return "menuBar.display.typing"
        case .usageAndTyping: return "menuBar.display.usageAndTyping"
        }
    }

    var requiresLiveRefresh: Bool {
        self != .iconOnly
    }
}

struct MenuBarView: View {
    @ObservedObject var model: DayTraceViewModel
    @AppStorage(MenuBarDisplayMode.storageKey) private var displayModeRawValue = MenuBarDisplayMode.defaultValue.rawValue
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let snapshot = model.typingActivity()
        VStack(alignment: .leading, spacing: DayTraceDesign.spaceS) {
            Text("menuBar.today")
                .font(DayTraceDesign.caption)
                .foregroundStyle(.secondary)
            Text(DayTraceDurationFormatter.string(seconds: model.totalUsage(), locale: selectedLocale))
                .font(DayTraceDesign.metricSmall)
                .monospacedDigit()
            HStack(spacing: DayTraceDesign.spaceS) {
                Image(systemName: model.foregroundTracker.isTracking ? "record.circle.fill" : "pause.circle.fill")
                    .foregroundStyle(model.foregroundTracker.isTracking ? DayTraceDesign.positive : DayTraceDesign.attention)
                Text(LocalizedStringKey(model.foregroundTracker.isTracking ? "status.running" : "status.paused"))
                    .font(DayTraceDesign.bodyMedium)
            }
            Divider()
            Button("menuBar.openDashboard", action: showDashboard)
            Button(model.foregroundTracker.isTracking ? "tracking.pause" : "tracking.resume") {
                if model.foregroundTracker.isTracking {
                    model.foregroundTracker.pause()
                } else {
                    model.foregroundTracker.resume()
                }
            }
            Menu("menuBar.display.title") {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    Button {
                        displayModeRawValue = mode.rawValue
                    } label: {
                        HStack {
                            Text(LocalizedStringKey(mode.localizationKey))
                            if mode.rawValue == displayModeRawValue {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Divider()
            Text("menuBar.typingValue", comment: "Menu bar typing summary")
            Text(snapshot.metrics.typedCharacters, format: .number)
                .font(DayTraceDesign.bodyMedium)
                .monospacedDigit()
            Button("menuBar.settings", action: showSettings)
            Button("menuBar.quit", action: quit)
        }
        .padding(DayTraceDesign.spaceS)
        .frame(width: 220)
    }

    private var selectedLocale: Locale {
        (AppLanguage(rawValue: languageRawValue) ?? .system).locale
    }

    private func showDashboard() {
        openWindow(id: "dashboard")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var model: DayTraceViewModel
    @AppStorage(MenuBarDisplayMode.storageKey) private var displayModeRawValue = MenuBarDisplayMode.defaultValue.rawValue
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue

    var body: some View {
        let mode = MenuBarDisplayMode.resolved(rawValue: displayModeRawValue)
        let icon = Image(systemName: "clock.arrow.circlepath")
        switch mode {
        case .iconOnly:
            icon
        case .usage:
            HStack(spacing: 4) {
                icon
                Text(DayTraceDurationFormatter.string(seconds: model.totalUsage(), locale: selectedLocale))
            }
        case .typing:
            HStack(spacing: 4) {
                Image(systemName: "keyboard")
                Text(model.typingActivity().metrics.typedCharacters, format: .number)
            }
        case .usageAndTyping:
            HStack(spacing: 4) {
                icon
                Text("\(DayTraceDurationFormatter.string(seconds: model.totalUsage(), locale: selectedLocale)) · \(model.typingActivity().metrics.typedCharacters)")
            }
        }
    }

    private var selectedLocale: Locale {
        (AppLanguage(rawValue: languageRawValue) ?? .system).locale
    }
}
