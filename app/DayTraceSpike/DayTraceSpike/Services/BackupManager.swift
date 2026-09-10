import Combine
import Foundation

enum RestoreResult: Equatable {
    case restored(appRecords: Int, websiteRecords: Int, timelineRecords: Int)
    case rejected(String)
    case failed(String)
}

enum BackupValidationError: LocalizedError, Equatable {
    case invalid(String)

    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

struct RestoredAppRecord: Equatable {
    let dateKey: String
    let bundleIdentifier: String
    let displayName: String
    let durationSeconds: Double
}

struct RestoredWebsiteRecord: Equatable {
    let dateKey: String
    let domain: String
    let durationSeconds: Double
}

struct RestoredTypingRecord: Equatable {
    let dateKey: String
    let englishCharacters: Int64
    let numberCharacters: Int64
    let symbolCharacters: Int64
    let spaceCharacters: Int64
    let typingSessions: Int64
    let activeTypingDurationSeconds: Double
    let metricVersion: Int64
}

struct RestoredTypingAppRecord: Equatable {
    let dateKey: String
    let bundleIdentifier: String
    let displayName: String
    let englishCharacters: Int64
    let numberCharacters: Int64
    let symbolCharacters: Int64
    let spaceCharacters: Int64
    let metricVersion: Int64
}

struct RestoredAppInterval: Equatable {
    let idString: String?
    let dateKey: String
    let start: Date
    let end: Date
    let durationSeconds: Double
    let bundleIdentifier: String
    let displayName: String
}

struct RestoredWebsiteInterval: Equatable {
    let idString: String?
    let dateKey: String
    let start: Date
    let end: Date
    let durationSeconds: Double
    let browserBundleIdentifier: String
    let domain: String
    let parentAppIntervalID: String?
}

struct RestoredBackgroundInterval: Equatable {
    let idString: String?
    let dateKey: String
    let start: Date
    let end: Date
    let durationSeconds: Double
    let bundleIdentifier: String
    let displayName: String
    let activityKindRawValue: String
    let detectorIdentifier: String?
}

struct ValidatedBackupPayload: Equatable {
    let backupVersion: Int
    let appUsage: [RestoredAppRecord]
    let websiteUsage: [RestoredWebsiteRecord]
    let typing: [RestoredTypingRecord]
    let typingByApp: [RestoredTypingAppRecord]
    let appIntervals: [RestoredAppInterval]
    let websiteIntervals: [RestoredWebsiteInterval]
    let backgroundIntervals: [RestoredBackgroundInterval]
}

enum DayTraceBackupCodec {
    static let currentVersion = 3

    static func validate(_ data: Data) -> Result<ValidatedBackupPayload, BackupValidationError> {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.invalid("Backup JSON is malformed"))
        }
        let version = (object["backupVersion"] as? Int) ?? (object["schemaVersion"] as? Int) ?? 1
        guard (1...currentVersion).contains(version) else {
            return .failure(.invalid("Unsupported backup version"))
        }
        let aggregateObject = (object["aggregates"] as? [String: Any]) ?? object
        guard let apps = aggregateObject["appUsage"] as? [[String: Any]],
              let websites = aggregateObject["websiteUsage"] as? [[String: Any]],
              let typing = aggregateObject["typing"] as? [[String: Any]],
              let typingByApp = aggregateObject["typingByApp"] as? [[String: Any]] else {
            return .failure(.invalid("Backup is missing required activity datasets"))
        }
        guard apps.count + websites.count + typing.count + typingByApp.count < 200_000 else {
            return .failure(.invalid("Backup is too large to import safely"))
        }

        do {
            let decodedApps = try apps.map(parseApp)
            let decodedWebsites = try websites.map(parseWebsite)
            let decodedTyping = try typing.map(parseTyping)
            let decodedTypingApps = try typingByApp.map(parseTypingApp)
            let timeline = try parseTimeline(aggregateObject["detailedTimeline"] as? [String: Any])
            return .success(ValidatedBackupPayload(
                backupVersion: version,
                appUsage: decodedApps,
                websiteUsage: decodedWebsites,
                typing: decodedTyping,
                typingByApp: decodedTypingApps,
                appIntervals: timeline.apps,
                websiteIntervals: timeline.websites,
                backgroundIntervals: timeline.background
            ))
        } catch {
            return .failure(.invalid(error.localizedDescription))
        }
    }

    private static func parseApp(_ value: [String: Any]) throws -> RestoredAppRecord {
        RestoredAppRecord(
            dateKey: try dateKey(value["date"]),
            bundleIdentifier: try identity(value["bundleIdentifier"]),
            displayName: try displayName(value["displayName"]),
            durationSeconds: try duration(value["durationSeconds"])
        )
    }

    private static func parseWebsite(_ value: [String: Any]) throws -> RestoredWebsiteRecord {
        RestoredWebsiteRecord(
            dateKey: try dateKey(value["date"]),
            domain: try domain(value["domain"]),
            durationSeconds: try duration(value["durationSeconds"])
        )
    }

    private static func parseTyping(_ value: [String: Any]) throws -> RestoredTypingRecord {
        RestoredTypingRecord(
            dateKey: try dateKey(value["date"]),
            englishCharacters: try count(value["englishCharacters"]),
            numberCharacters: try count(value["numberCharacters"]),
            symbolCharacters: try count(value["symbolCharacters"]),
            spaceCharacters: try count(value["spaceCharacters"]),
            typingSessions: try count(value["typingSessions"]),
            activeTypingDurationSeconds: try duration(value["activeTypingDurationSeconds"]),
            metricVersion: try count(value["metricVersion"])
        )
    }

    private static func parseTypingApp(_ value: [String: Any]) throws -> RestoredTypingAppRecord {
        RestoredTypingAppRecord(
            dateKey: try dateKey(value["date"]),
            bundleIdentifier: try identity(value["bundleIdentifier"]),
            displayName: try displayName(value["displayName"]),
            englishCharacters: try count(value["englishCharacters"]),
            numberCharacters: try count(value["numberCharacters"]),
            symbolCharacters: try count(value["symbolCharacters"]),
            spaceCharacters: try count(value["spaceCharacters"]),
            metricVersion: try count(value["metricVersion"])
        )
    }

    private static func parseTimeline(_ object: [String: Any]?) throws -> (apps: [RestoredAppInterval], websites: [RestoredWebsiteInterval], background: [RestoredBackgroundInterval]) {
        guard let object else { return ([], [], []) }
        let apps = try (object["apps"] as? [[String: Any]] ?? []).map { value in
            let start = try isoDate(value["start"])
            let end = try isoDate(value["end"])
            return RestoredAppInterval(
                idString: value["id"] as? String,
                dateKey: try dateKey(value["date"]), start: start, end: end,
                durationSeconds: try intervalDuration(value["durationSeconds"], start: start, end: end),
                bundleIdentifier: try identity(value["bundleIdentifier"]),
                displayName: try displayName(value["displayName"])
            )
        }
        let websites = try (object["websites"] as? [[String: Any]] ?? []).map { value in
            let start = try isoDate(value["start"])
            let end = try isoDate(value["end"])
            return RestoredWebsiteInterval(
                idString: value["id"] as? String,
                dateKey: try dateKey(value["date"]), start: start, end: end,
                durationSeconds: try intervalDuration(value["durationSeconds"], start: start, end: end),
                browserBundleIdentifier: try identity(value["browser"]),
                domain: try domain(value["domain"]),
                parentAppIntervalID: value["parentAppIntervalID"] as? String
            )
        }
        let background = try (object["backgroundIntervals"] as? [[String: Any]] ?? []).map { value in
            let start = try isoDate(value["start"])
            let end = try isoDate(value["end"])
            return RestoredBackgroundInterval(
                idString: value["id"] as? String,
                dateKey: try dateKey(value["date"]), start: start, end: end,
                durationSeconds: try intervalDuration(value["durationSeconds"], start: start, end: end),
                bundleIdentifier: try identity(value["bundleIdentifier"]),
                displayName: try displayName(value["displayName"]),
                activityKindRawValue: try identity(value["activityKind"]),
                detectorIdentifier: value["detectorIdentifier"] as? String
            )
        }
        return (apps, websites, background)
    }

    private static func dateKey(_ value: Any?) throws -> String {
        guard let value = value as? String, value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            throw NSError(domain: "DayTraceBackup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid date key"])
        }
        return value
    }

    private static func identity(_ value: Any?) throws -> String {
        guard let value = value as? String, !value.isEmpty, value.count <= 512 else {
            throw NSError(domain: "DayTraceBackup", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid identity"])
        }
        return value
    }

    private static func displayName(_ value: Any?) throws -> String {
        guard let value = value as? String, !value.isEmpty, value.count <= 512 else {
            throw NSError(domain: "DayTraceBackup", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid display name"])
        }
        return value
    }

    private static func domain(_ value: Any?) throws -> String {
        guard let value = value as? String, !value.isEmpty, value.count <= 253,
              !value.contains("/"), !value.contains(":"),
              value.split(separator: ".").allSatisfy({ !$0.isEmpty }) else {
            throw NSError(domain: "DayTraceBackup", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid website domain"])
        }
        return value
    }

    private static func count(_ value: Any?) throws -> Int64 {
        let number = (value as? NSNumber)?.int64Value
        guard let number, number >= 0 else {
            throw NSError(domain: "DayTraceBackup", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid count"])
        }
        return number
    }

    private static func duration(_ value: Any?) throws -> Double {
        guard let number = (value as? NSNumber)?.doubleValue, number.isFinite, number >= 0 else {
            throw NSError(domain: "DayTraceBackup", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid duration"])
        }
        return number
    }

    private static func intervalDuration(_ value: Any?, start: Date, end: Date) throws -> Double {
        let duration = try duration(value)
        guard end > start, duration > 0 else {
            throw NSError(domain: "DayTraceBackup", code: 7, userInfo: [NSLocalizedDescriptionKey: "Invalid interval"])
        }
        return duration
    }

    private static func isoDate(_ value: Any?) throws -> Date {
        guard let value = value as? String,
              let date = ISO8601DateFormatter().date(from: value) else {
            throw NSError(domain: "DayTraceBackup", code: 8, userInfo: [NSLocalizedDescriptionKey: "Invalid timestamp"])
        }
        return date
    }
}

enum AutomaticBackupPolicy {
    static func shouldCreateBackup(lastBackupAt: Date?, at date: Date, calendar: Calendar) -> Bool {
        guard let lastBackupAt else { return true }
        return !calendar.isDate(lastBackupAt, inSameDayAs: date)
    }
}

@MainActor
final class BackupManager: ObservableObject {
    @Published private(set) var lastBackupAt: Date?
    @Published private(set) var lastError: String?

    static let enabledKey = "daytrace.backups.enabled"
    static let retentionKey = "daytrace.backups.retention"
    static let lastBackupKey = "daytrace.backups.lastBackupAt"

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let directoryOverride: URL?
    private let nowProvider: () -> Date
    private let dataWriter: (Data, URL) throws -> Void

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        directoryOverride: URL? = nil,
        now: @escaping () -> Date = Date.init,
        dataWriter: @escaping (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: .atomic)
        }
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.directoryOverride = directoryOverride
        self.nowProvider = now
        self.dataWriter = dataWriter
        self._lastBackupAt = Published(initialValue: defaults.object(forKey: Self.lastBackupKey) as? Date)
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set {
            defaults.set(newValue, forKey: Self.enabledKey)
            objectWillChange.send()
        }
    }

    var retention: Int {
        get {
            let value = defaults.integer(forKey: Self.retentionKey)
            return value > 0 ? min(value, 20) : 10
        }
        set { defaults.set(min(max(newValue, 5), 20), forKey: Self.retentionKey) }
    }

    var backupDirectoryURL: URL {
        if let directoryOverride { return directoryOverride }
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("DayTrace/Backups", isDirectory: true)
    }

    @discardableResult
    func createBackup(using store: UsageStore) -> URL? {
        lastError = nil
        let now = nowProvider()
        var destinationURL: URL?
        // A degraded store can still be readable and exportable. It represents
        // a recoverable persistence warning, while a failed store means the
        // persistent container is unavailable. Manual backup should preserve
        // the readable snapshot in the former case.
        guard store.status.isReady, let exported = store.exportAggregatesJSON(includeDetailedTimeline: true) else {
            lastError = "Unable to export aggregate data"
            return nil
        }

        do {
            try fileManager.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
            let envelope: [String: Any] = [
                "backupVersion": DayTraceBackupCodec.currentVersion,
                "schemaVersion": 3,
                "createdAt": ISO8601DateFormatter().string(from: now),
                "aggregates": try JSONSerialization.jsonObject(with: exported)
            ]
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys])
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
            let timestamp = formatter.string(from: now)
            let url = backupDirectoryURL.appendingPathComponent("DayTrace-\(timestamp)-\(UUID().uuidString).json")
            destinationURL = url
            try dataWriter(data, url)
            pruneBackups()
            lastBackupAt = now
            defaults.set(now, forKey: Self.lastBackupKey)
            return url
        } catch {
            if let destinationURL { try? fileManager.removeItem(at: destinationURL) }
            lastError = error.localizedDescription
            return nil
        }
    }

    func pruneBackups() {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        let backups = urls
            .filter { Self.isManagedBackupFilename($0.lastPathComponent) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for url in backups.dropFirst(retention) {
            try? fileManager.removeItem(at: url)
        }
    }

    static func isManagedBackupFilename(_ filename: String) -> Bool {
        let pattern = #"^DayTrace-[0-9]{8}-[0-9]{6}-[0-9]{3}-[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.json$"#
        return filename.range(of: pattern, options: .regularExpression) != nil
    }

    static func detectBackupVersion(from data: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["backupVersion"] as? Int else { return nil }
        return version
    }
}
