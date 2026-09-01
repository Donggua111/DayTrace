import Foundation

struct AppIdentity: Hashable, Codable, Identifiable {
    let bundleIdentifier: String
    let displayName: String

    var id: String { bundleIdentifier }

    // Bundle ID is the stable identity. Display name is mutable presentation
    // metadata and must not split an aggregate when an app is renamed.
    static func == (lhs: AppIdentity, rhs: AppIdentity) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}

struct ForegroundInterval: Identifiable, Codable {
    let id: UUID
    let app: AppIdentity
    let start: Date
    let end: Date
    let duration: TimeInterval
}

enum TrackingSystemState: String {
    case awake
    case sleeping
    case locked
    case paused
    case unavailable
}

enum InputMonitoringStatus: String {
    case notRequested
    case requesting
    case notGranted
    case granted
    case denied
    case systemSettingsRequired
    case eventTapFailed

    var displayName: String {
        switch self {
        case .notRequested: return String(localized: "status.inputNotRequested")
        case .requesting: return String(localized: "status.inputRequesting")
        case .notGranted: return String(localized: "status.inputNotGranted")
        case .granted: return String(localized: "status.inputGranted")
        case .denied: return String(localized: "status.inputDenied")
        case .systemSettingsRequired: return String(localized: "status.inputSystemSettings")
        case .eventTapFailed: return String(localized: "status.inputEventTapFailed")
        }
    }

    var localizationKey: String {
        switch self {
        case .notRequested: return "status.inputNotRequested"
        case .requesting: return "status.inputRequesting"
        case .notGranted: return "status.inputNotGranted"
        case .granted: return "status.inputGranted"
        case .denied: return "status.inputDenied"
        case .systemSettingsRequired: return "status.inputSystemSettings"
        case .eventTapFailed: return "status.inputEventTapFailed"
        }
    }
}

enum InputMonitoringDiagnosticStatus: String {
    case granted
    case denied
    case unknown

    var displayName: String {
        switch self {
        case .granted: return String(localized: "diagnostic.granted")
        case .denied: return String(localized: "diagnostic.denied")
        case .unknown: return String(localized: "diagnostic.unknown")
        }
    }

    var localizationKey: String {
        switch self {
        case .granted: return "diagnostic.granted"
        case .denied: return "diagnostic.denied"
        case .unknown: return "diagnostic.unknown"
        }
    }
}

enum IPCStatus: String {
    case notConfigured
    case waiting
    case connected
    case error

    var displayName: String {
        switch self {
        case .notConfigured: return String(localized: "status.ipcNotConfigured")
        case .waiting: return String(localized: "status.ipcWaiting")
        case .connected: return String(localized: "status.ipcConnected")
        case .error: return String(localized: "status.ipcError")
        }
    }

    var localizationKey: String {
        switch self {
        case .notConfigured: return "status.ipcNotConfigured"
        case .waiting: return "status.ipcWaiting"
        case .connected: return "status.ipcConnected"
        case .error: return "status.ipcError"
        }
    }
}
