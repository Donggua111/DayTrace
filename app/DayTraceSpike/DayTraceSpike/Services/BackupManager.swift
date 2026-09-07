import Combine
import Foundation

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
        guard store.status == .ready, let exported = store.exportAggregatesJSON(includeDetailedTimeline: true) else {
            lastError = "Unable to export aggregate data"
            return nil
        }

        do {
            try fileManager.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
            let envelope: [String: Any] = [
                "backupVersion": 2,
                "schemaVersion": 2,
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
