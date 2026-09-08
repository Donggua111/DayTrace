import Foundation

/// Product identity values that must stay coordinated across the app, Chrome,
/// Native Messaging, diagnostics, and release tooling.
enum DayTraceIdentity {
    static let productName = "DayTrace"
    static let developmentBundleIdentifier = "com.daytrace.spike"
    static let productionBundleIdentifier: String? = nil
    static let nativeMessagingHostName = "com.daytrace.spike"
    static let chromeExtensionIdentifier = "mmnoopahcchjobiajnhembdlipkhbjgo"
    static let identityMigrationVersion = 1

    static var activeBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? developmentBundleIdentifier
    }

    static func versionInfo(from info: [String: Any]) -> (marketing: String, build: String) {
        let marketing = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        return (marketing, build)
    }

    static var versionInfo: (marketing: String, build: String) {
        versionInfo(from: Bundle.main.infoDictionary ?? [:])
    }

    enum InstallationKind: String {
        case userApplications
        case systemApplications
        case xcodeDerivedData
        case temporary
        case other
    }

    static func installationKind(for appURL: URL, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> InstallationKind {
        let path = appURL.standardizedFileURL.path
        let userApplications = homeDirectory.appendingPathComponent("Applications", isDirectory: true).standardizedFileURL.path
        if path == userApplications || path.hasPrefix(userApplications + "/") {
            return .userApplications
        }
        if path == "/Applications" || path.hasPrefix("/Applications/") {
            return .systemApplications
        }
        if path.contains("/DerivedData/") || path.hasSuffix("/DerivedData") {
            return .xcodeDerivedData
        }
        if path == "/tmp" || path.hasPrefix("/tmp/") || path == "/private/tmp" || path.hasPrefix("/private/tmp/") {
            return .temporary
        }
        return .other
    }
}
