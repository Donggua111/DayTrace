import SwiftUI

@main
struct DayTraceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup("DayTrace", id: "dashboard") {
            Group {
                if appDelegate.isPrimaryInstance {
                    ZStack {
                        ContentView(model: appDelegate.model, languageRawValue: $languageRawValue)
                        DashboardWindowBridge(controller: appDelegate.dashboardWindowController)
                    }
                } else {
                    Color.clear
                }
            }
                .environment(\.locale, selectedLanguage.locale)
        }

        Settings {
            Group {
                if appDelegate.isPrimaryInstance {
                    SettingsView(model: appDelegate.model, languageRawValue: $languageRawValue)
                } else {
                    Color.clear
                }
            }
                .environment(\.locale, selectedLanguage.locale)
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }
}
