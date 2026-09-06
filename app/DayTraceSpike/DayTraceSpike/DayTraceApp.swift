import SwiftUI

@main
struct DayTraceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup("DayTrace", id: "dashboard") {
            ZStack {
                ContentView(model: appDelegate.model, languageRawValue: $languageRawValue)
                DashboardWindowBridge(controller: appDelegate.dashboardWindowController)
            }
                .environment(\.locale, selectedLanguage.locale)
        }

        Settings {
            SettingsView(model: appDelegate.model, languageRawValue: $languageRawValue)
                .environment(\.locale, selectedLanguage.locale)
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }
}
