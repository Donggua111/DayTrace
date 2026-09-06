import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var lastError: String?

    var isEnabled: Bool {
        status == .enabled
    }

    var statusLocalizationKey: String {
        switch status {
        case .enabled:
            return "launchAtLogin.status.enabled"
        case .requiresApproval:
            return "launchAtLogin.status.requiresApproval"
        case .notRegistered:
            return "launchAtLogin.status.disabled"
        case .notFound:
            return "launchAtLogin.status.unknown"
        @unknown default:
            return "launchAtLogin.status.unknown"
        }
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }
}
