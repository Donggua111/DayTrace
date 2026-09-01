import SwiftUI

@main
struct DayTraceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = DayTraceViewModel()
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, languageRawValue: $languageRawValue)
                .environment(\.locale, selectedLanguage.locale)
        }

        Settings {
            SettingsView(model: model, languageRawValue: $languageRawValue)
                .environment(\.locale, selectedLanguage.locale)
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageRawValue) ?? .system
    }
}
