import CoreData
import Combine
import Foundation

struct DailyUsageSnapshot: Equatable {
    var appUsageByApp: [AppIdentity: TimeInterval] = [:]
    var websiteUsageByDomain: [String: TimeInterval] = [:]
    var typingMetrics = TypingMetrics()
    var typingAppMetricsByApp: [AppIdentity: AppTypingMetrics] = [:]
    var typingSessions = 0
    var activeTypingDuration: TimeInterval = 0
    var metricVersion = 1

    var totalUsage: TimeInterval {
        appUsageByApp.values.reduce(0, +)
    }
}

struct TypingActivitySnapshot: Equatable {
    let metrics: TypingMetrics
    let appMetricsByApp: [AppIdentity: AppTypingMetrics]
    let typingSessions: Int
    let activeTypingDuration: TimeInterval

    var charactersPerMinute: Double? {
        guard activeTypingDuration > 0 else { return nil }
        return Double(metrics.typedCharacters) / (activeTypingDuration / 60)
    }

    var mostTypedInApp: AppIdentity? {
        appMetricsByApp
            .filter { $0.value.typedCharacters > 0 }
            .sorted {
                if $0.value.typedCharacters == $1.value.typedCharacters {
                    return $0.key.displayName.localizedCaseInsensitiveCompare($1.key.displayName) == .orderedAscending
                }
                return $0.value.typedCharacters > $1.value.typedCharacters
            }
            .first?.key
    }
}

@objc(AppUsageDailyRecord)
final class AppUsageDailyRecord: NSManagedObject {}

extension AppUsageDailyRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AppUsageDailyRecord> {
        NSFetchRequest<AppUsageDailyRecord>(entityName: "AppUsageDailyRecord")
    }

    @NSManaged var dateKey: String
    @NSManaged var bundleIdentifier: String
    @NSManaged var displayName: String
    @NSManaged var durationSeconds: Double
}

@objc(WebsiteUsageDailyRecord)
final class WebsiteUsageDailyRecord: NSManagedObject {}

extension WebsiteUsageDailyRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<WebsiteUsageDailyRecord> {
        NSFetchRequest<WebsiteUsageDailyRecord>(entityName: "WebsiteUsageDailyRecord")
    }

    @NSManaged var dateKey: String
    @NSManaged var browserBundleIdentifier: String
    @NSManaged var domain: String
    @NSManaged var durationSeconds: Double
}

@objc(TypingDailyRecord)
final class TypingDailyRecord: NSManagedObject {}

extension TypingDailyRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TypingDailyRecord> {
        NSFetchRequest<TypingDailyRecord>(entityName: "TypingDailyRecord")
    }

    @NSManaged var dateKey: String
    @NSManaged var englishCharacters: Int64
    @NSManaged var numberCharacters: Int64
    @NSManaged var symbolCharacters: Int64
    @NSManaged var spaceCharacters: Int64
    @NSManaged var typingSessions: Int64
    @NSManaged var activeTypingDurationSeconds: Double
    @NSManaged var metricVersion: Int64
}

@objc(TypingAppDailyRecord)
final class TypingAppDailyRecord: NSManagedObject {}

extension TypingAppDailyRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TypingAppDailyRecord> {
        NSFetchRequest<TypingAppDailyRecord>(entityName: "TypingAppDailyRecord")
    }

    @NSManaged var dateKey: String
    @NSManaged var bundleIdentifier: String
    @NSManaged var displayName: String
    @NSManaged var englishCharacters: Int64
    @NSManaged var numberCharacters: Int64
    @NSManaged var symbolCharacters: Int64
    @NSManaged var spaceCharacters: Int64
    @NSManaged var metricVersion: Int64
}

enum UsageStoreStatus: Equatable {
    case ready
    case degraded(String)
    case failed(String)

    var isReady: Bool {
        switch self {
        case .ready, .degraded:
            return true
        case .failed:
            return false
        }
    }
}

@MainActor
final class UsageStore: ObservableObject {
    nonisolated static let currentMetricVersion = 1

    @Published private(set) var status: UsageStoreStatus
    @Published private(set) var lastCheckpointAt: Date?
    @Published private(set) var revision = 0

    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let calendarProvider: () -> Calendar
    private var calendar: Calendar
    private let saveHandler: ((NSManagedObjectContext) throws -> Void)?
    private var loadedDayKeys: Set<String> = []
    private var baseSnapshotsByDay: [String: DailyUsageSnapshot] = [:]
    private var runtimeAppDurationsByDay: [String: [AppIdentity: TimeInterval]] = [:]
    private var runtimeDomainDurationsByDay: [String: [String: TimeInterval]] = [:]
    private var runtimeTypingByDay: [String: RuntimeTypingState] = [:]
    private var foregroundProgressByInterval: [String: TimeInterval] = [:]
    private var domainProgressByInterval: [String: TimeInterval] = [:]

    init(
        storeURL: URL? = nil,
        inMemory: Bool = false,
        calendarProvider: @escaping () -> Calendar = { Calendar.autoupdatingCurrent },
        saveHandler: ((NSManagedObjectContext) throws -> Void)? = nil
    ) {
        self.calendarProvider = calendarProvider
        self.calendar = calendarProvider()
        self.saveHandler = saveHandler
        let model = UsageStoreModel.make()
        let container = NSPersistentContainer(name: "DayTrace", managedObjectModel: model)
        self.container = container
        self.context = container.viewContext
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
        } else {
            description.type = NSSQLiteStoreType
            description.url = storeURL ?? Self.defaultStoreURL()
        }
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        do {
            try container.persistentStoreCoordinator.addPersistentStore(
                ofType: description.type,
                configurationName: description.configuration,
                at: description.url,
                options: description.options
            )
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }

        loadBaseSnapshot(for: DayTraceDateKey.key(for: Date(), calendar: calendar))
    }

    func snapshot(at date: Date = Date()) -> DailyUsageSnapshot {
        let dayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        ensureBaseLoaded(for: dayKey)
        return combinedSnapshot(for: dayKey, appDurations: runtimeAppDurationsByDay, domainDurations: runtimeDomainDurationsByDay)
    }

    func liveSnapshot(
        at date: Date = Date(),
        foregroundTracker: ForegroundTracker,
        domainTracker: DomainTracker
    ) -> DailyUsageSnapshot {
        let dayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        ensureBaseLoaded(for: dayKey)

        var appDurations = runtimeAppDurationsByDay
        var domainDurations = runtimeDomainDurationsByDay
        var foregroundProgress = foregroundProgressByInterval
        var domainProgress = domainProgressByInterval
        for interval in foregroundTracker.closedIntervals {
            processForegroundInterval(interval, progress: &foregroundProgress, durations: &appDurations)
        }
        if let active = foregroundTracker.activeIntervalSnapshot(at: date) {
            processForegroundInterval(active, progress: &foregroundProgress, durations: &appDurations)
        }
        for interval in domainTracker.domainIntervals {
            processDomainInterval(interval, progress: &domainProgress, durations: &domainDurations)
        }
        if let active = domainTracker.activeIntervalSnapshot(at: date) {
            processDomainInterval(active, progress: &domainProgress, durations: &domainDurations)
        }
        return combinedSnapshot(for: dayKey, appDurations: appDurations, domainDurations: domainDurations)
    }

    func typingSnapshot(at date: Date = Date()) -> TypingActivitySnapshot {
        let value = snapshot(at: date)
        return TypingActivitySnapshot(
            metrics: value.typingMetrics,
            appMetricsByApp: value.typingAppMetricsByApp,
            typingSessions: value.typingSessions,
            activeTypingDuration: value.activeTypingDuration
        )
    }

    func recordTyping(category: TypingCategory, app: AppIdentity?, at date: Date) {
        guard category != .ignored else { return }
        let dayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        ensureBaseLoaded(for: dayKey)
        var state = runtimeTypingByDay[dayKey, default: RuntimeTypingState()]
        state.metrics.record(category)
        if let app {
            var appMetrics = removeAppMetrics(for: app, from: &state.appMetricsByApp)
            appMetrics.record(category)
            state.appMetricsByApp[app] = appMetrics
        }

        if let previous = state.lastEventAt, DayTraceDateKey.key(for: previous, calendar: calendar) == dayKey {
            let delta = date.timeIntervalSince(previous)
            if delta >= TypingCounter.typingSessionTimeout {
                state.typingSessions += 1
            } else if delta > 0 {
                state.activeTypingDuration += min(delta, TypingCounter.activeIntervalCap)
            }
        } else {
            // A new local day or a relaunch starts a new independently
            // understandable session in that day's runtime contribution.
            state.typingSessions += 1
        }
        state.lastEventAt = date
        runtimeTypingByDay[dayKey] = state
        revision += 1
    }

    func checkpoint(at date: Date = Date()) {
        ensureBaseLoaded(for: DayTraceDateKey.key(for: date, calendar: calendar))
        persistRuntimeSnapshots(at: date)
    }

    func calendarDidChange(at _: Date) {
        calendar = calendarProvider()
        revision += 1
    }

    // Minimal test seam for verifying that incompatible historical typing
    // records are ignored rather than merged into the current metric.
    func seedTypingRecordForTesting(
        at date: Date,
        metricVersion: Int,
        englishCharacters: Int,
        numberCharacters: Int = 0,
        symbolCharacters: Int = 0,
        spaceCharacters: Int = 0
    ) {
        guard status.isReady else { return }
        let dayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        let record = TypingDailyRecord(context: context)
        record.dateKey = dayKey
        record.englishCharacters = Int64(englishCharacters)
        record.numberCharacters = Int64(numberCharacters)
        record.symbolCharacters = Int64(symbolCharacters)
        record.spaceCharacters = Int64(spaceCharacters)
        record.typingSessions = 1
        record.activeTypingDurationSeconds = 0
        record.metricVersion = Int64(metricVersion)
        try? context.save()
        loadedDayKeys.remove(dayKey)
        baseSnapshotsByDay.removeValue(forKey: dayKey)
    }

    func seedTypingAppRecordForTesting(
        at date: Date,
        app: AppIdentity,
        metricVersion: Int,
        englishCharacters: Int
    ) {
        guard status.isReady else { return }
        let dayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        let record = TypingAppDailyRecord(context: context)
        record.dateKey = dayKey
        record.bundleIdentifier = app.bundleIdentifier
        record.displayName = app.displayName
        record.englishCharacters = Int64(englishCharacters)
        record.numberCharacters = 0
        record.symbolCharacters = 0
        record.spaceCharacters = 0
        record.metricVersion = Int64(metricVersion)
        try? context.save()
        loadedDayKeys.remove(dayKey)
        baseSnapshotsByDay.removeValue(forKey: dayKey)
    }

    func checkpoint(
        foregroundTracker: ForegroundTracker,
        domainTracker: DomainTracker,
        at date: Date = Date()
    ) {
        var candidateForegroundProgress = foregroundProgressByInterval
        var candidateDomainProgress = domainProgressByInterval
        var candidateAppDurations = runtimeAppDurationsByDay
        var candidateDomainDurations = runtimeDomainDurationsByDay
        accumulateRuntime(
            foregroundTracker: foregroundTracker,
            domainTracker: domainTracker,
            at: date,
            foregroundProgress: &candidateForegroundProgress,
            domainProgress: &candidateDomainProgress,
            appDurations: &candidateAppDurations,
            domainDurations: &candidateDomainDurations
        )
        if persistRuntimeSnapshots(
            at: date,
            appDurations: candidateAppDurations,
            domainDurations: candidateDomainDurations
        ) {
            // A persistence cursor is committed only after context.save()
            // succeeds. A failed save leaves the prior cursor and runtime
            // maps untouched so the same delta can be retried.
            foregroundProgressByInterval = candidateForegroundProgress
            domainProgressByInterval = candidateDomainProgress
            runtimeAppDurationsByDay = candidateAppDurations
            runtimeDomainDurationsByDay = candidateDomainDurations
        }
    }

    // These aggregate-only helpers make deterministic day-boundary tests
    // possible without synthesizing AppKit notifications.
    func recordForegroundInterval(_ interval: ForegroundInterval) {
        processForegroundInterval(interval, progress: &foregroundProgressByInterval, durations: &runtimeAppDurationsByDay)
        revision += 1
    }

    func recordWebsiteInterval(_ interval: DomainInterval, browserBundleIdentifier: String = "com.google.Chrome") {
        guard browserBundleIdentifier == "com.google.Chrome" else { return }
        processDomainInterval(interval, progress: &domainProgressByInterval, durations: &runtimeDomainDurationsByDay)
        revision += 1
    }

    private func accumulateRuntime(
        foregroundTracker: ForegroundTracker,
        domainTracker: DomainTracker,
        at date: Date,
        foregroundProgress: inout [String: TimeInterval],
        domainProgress: inout [String: TimeInterval],
        appDurations: inout [String: [AppIdentity: TimeInterval]],
        domainDurations: inout [String: [String: TimeInterval]]
    ) {
        for interval in foregroundTracker.closedIntervals {
            processForegroundInterval(interval, progress: &foregroundProgress, durations: &appDurations)
        }
        if let active = foregroundTracker.activeIntervalSnapshot(at: date) {
            processForegroundInterval(active, progress: &foregroundProgress, durations: &appDurations)
        }

        for interval in domainTracker.domainIntervals {
            processDomainInterval(interval, progress: &domainProgress, durations: &domainDurations)
        }
        if let active = domainTracker.activeIntervalSnapshot(at: date) {
            processDomainInterval(active, progress: &domainProgress, durations: &domainDurations)
        }
    }

    @discardableResult
    private func persistRuntimeSnapshots(
        at date: Date,
        appDurations: [String: [AppIdentity: TimeInterval]]? = nil,
        domainDurations: [String: [String: TimeInterval]]? = nil
    ) -> Bool {
        let appDurations = appDurations ?? runtimeAppDurationsByDay
        let domainDurations = domainDurations ?? runtimeDomainDurationsByDay
        let currentDayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        ensureBaseLoaded(for: currentDayKey)
        guard status.isReady else {
            revision += 1
            return false
        }

        let affectedDays = Set(appDurations.keys)
            .union(domainDurations.keys)
            .union(runtimeTypingByDay.keys)
            .union([currentDayKey])

        normalizeDuplicateRecords(for: affectedDays)
        for dayKey in affectedDays {
            ensureBaseLoaded(for: dayKey)
            upsert(
                snapshot(for: dayKey, appDurations: appDurations, domainDurations: domainDurations),
                dayKey: dayKey
            )
        }

        do {
            if let saveHandler {
                try saveHandler(context)
            } else {
                try context.save()
            }
            status = .ready
            lastCheckpointAt = date
            revision += 1
            return true
        } catch {
            // Candidate maps and progress are local to the tracker checkpoint,
            // so they are discarded here. Roll back only the failed Core Data
            // transaction; the next checkpoint writes the same absolute
            // aggregate again without duplication.
            context.rollback()
            status = .degraded(error.localizedDescription)
            revision += 1
            return false
        }
    }

    private func combinedSnapshot(
        for dayKey: String,
        appDurations: [String: [AppIdentity: TimeInterval]],
        domainDurations: [String: [String: TimeInterval]]
    ) -> DailyUsageSnapshot {
        var result = baseSnapshotsByDay[dayKey, default: DailyUsageSnapshot()]
        for (app, duration) in appDurations[dayKey, default: [:]] {
            mergeAppDuration(app, duration: duration, into: &result.appUsageByApp)
        }
        for (domain, duration) in domainDurations[dayKey, default: [:]] {
            result.websiteUsageByDomain[domain, default: 0] += duration
        }
        let typing = runtimeTypingByDay[dayKey, default: RuntimeTypingState()]
        result.typingMetrics = TypingMetrics(
            englishCharacters: result.typingMetrics.englishCharacters + typing.metrics.englishCharacters,
            numberCharacters: result.typingMetrics.numberCharacters + typing.metrics.numberCharacters,
            symbolCharacters: result.typingMetrics.symbolCharacters + typing.metrics.symbolCharacters,
            spaceCharacters: result.typingMetrics.spaceCharacters + typing.metrics.spaceCharacters
        )
        for (app, metrics) in typing.appMetricsByApp {
            var combined = removeAppMetrics(for: app, from: &result.typingAppMetricsByApp)
            combined.adding(metrics)
            result.typingAppMetricsByApp[app] = combined
        }
        result.typingSessions += typing.typingSessions
        result.activeTypingDuration += typing.activeTypingDuration
        result.metricVersion = Self.currentMetricVersion
        return result
    }

    private func snapshot(
        for dayKey: String,
        appDurations: [String: [AppIdentity: TimeInterval]],
        domainDurations: [String: [String: TimeInterval]]
    ) -> DailyUsageSnapshot {
        return combinedSnapshot(for: dayKey, appDurations: appDurations, domainDurations: domainDurations)
    }

    private func ensureBaseLoaded(for dayKey: String) {
        guard !loadedDayKeys.contains(dayKey) else { return }
        loadBaseSnapshot(for: dayKey)
    }

    private func loadBaseSnapshot(for dayKey: String) {
        guard !loadedDayKeys.contains(dayKey) else { return }
        baseSnapshotsByDay[dayKey] = fetchSnapshot(for: dayKey)
        loadedDayKeys.insert(dayKey)
    }

    private func fetchSnapshot(for dayKey: String) -> DailyUsageSnapshot {
        guard status.isReady else { return DailyUsageSnapshot() }
        var result = DailyUsageSnapshot()

        let apps = AppUsageDailyRecord.fetchRequest()
        apps.predicate = NSPredicate(format: "dateKey == %@", dayKey)
        if let records = try? context.fetch(apps) {
            for record in records {
                let app = AppIdentity(bundleIdentifier: record.bundleIdentifier, displayName: record.displayName)
                if let existing = result.appUsageByApp.keys.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                    let existingDuration = result.appUsageByApp[existing, default: 0]
                    if record.durationSeconds > existingDuration {
                        result.appUsageByApp.removeValue(forKey: existing)
                        result.appUsageByApp[app] = record.durationSeconds
                    }
                } else {
                    result.appUsageByApp[app] = record.durationSeconds
                }
            }
        }

        let websites = WebsiteUsageDailyRecord.fetchRequest()
        websites.predicate = NSPredicate(format: "dateKey == %@", dayKey)
        if let records = try? context.fetch(websites) {
            for record in records {
                result.websiteUsageByDomain[record.domain] = max(
                    result.websiteUsageByDomain[record.domain, default: 0],
                    record.durationSeconds
                )
            }
        }

        let typing = TypingDailyRecord.fetchRequest()
        typing.predicate = NSPredicate(format: "dateKey == %@ AND metricVersion == %d", dayKey, Self.currentMetricVersion)
        if let record = try? context.fetch(typing).sorted(by: {
            if $0.totalCharacters != $1.totalCharacters { return $0.totalCharacters > $1.totalCharacters }
            return $0.activeTypingDurationSeconds > $1.activeTypingDurationSeconds
        }).first {
            result.typingMetrics = TypingMetrics(
                englishCharacters: Int(record.englishCharacters),
                numberCharacters: Int(record.numberCharacters),
                symbolCharacters: Int(record.symbolCharacters),
                spaceCharacters: Int(record.spaceCharacters)
            )
            result.typingSessions = Int(record.typingSessions)
            result.activeTypingDuration = record.activeTypingDurationSeconds
            result.metricVersion = Int(record.metricVersion)
        }

        let typingApps = TypingAppDailyRecord.fetchRequest()
        typingApps.predicate = NSPredicate(format: "dateKey == %@ AND metricVersion == %d", dayKey, Self.currentMetricVersion)
        if let records = try? context.fetch(typingApps) {
            for record in records {
                let app = AppIdentity(bundleIdentifier: record.bundleIdentifier, displayName: record.displayName)
                let metrics = AppTypingMetrics(
                    englishCharacters: Int(record.englishCharacters),
                    numberCharacters: Int(record.numberCharacters),
                    symbolCharacters: Int(record.symbolCharacters),
                    spaceCharacters: Int(record.spaceCharacters)
                )
                if let existing = result.typingAppMetricsByApp.keys.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                    let existingCount = result.typingAppMetricsByApp[existing, default: AppTypingMetrics()].typedCharacters
                    if metrics.typedCharacters > existingCount {
                        result.typingAppMetricsByApp.removeValue(forKey: existing)
                        result.typingAppMetricsByApp[app] = metrics
                    }
                } else {
                    result.typingAppMetricsByApp[app] = metrics
                }
            }
        }
        return result
    }

    private func upsert(_ snapshot: DailyUsageSnapshot, dayKey: String) {
        for (app, duration) in snapshot.appUsageByApp {
            let record = fetchAppRecord(dayKey: dayKey, bundleIdentifier: app.bundleIdentifier) ?? AppUsageDailyRecord(context: context)
            record.dateKey = dayKey
            record.bundleIdentifier = app.bundleIdentifier
            record.displayName = app.displayName
            record.durationSeconds = duration
        }

        for (domain, duration) in snapshot.websiteUsageByDomain {
            let record = fetchWebsiteRecord(dayKey: dayKey, domain: domain) ?? WebsiteUsageDailyRecord(context: context)
            record.dateKey = dayKey
            record.browserBundleIdentifier = "com.google.Chrome"
            record.domain = domain
            record.durationSeconds = duration
        }

        let typing = fetchTypingRecord(dayKey: dayKey) ?? TypingDailyRecord(context: context)
        typing.dateKey = dayKey
        typing.englishCharacters = Int64(snapshot.typingMetrics.englishCharacters)
        typing.numberCharacters = Int64(snapshot.typingMetrics.numberCharacters)
        typing.symbolCharacters = Int64(snapshot.typingMetrics.symbolCharacters)
        typing.spaceCharacters = Int64(snapshot.typingMetrics.spaceCharacters)
        typing.typingSessions = Int64(snapshot.typingSessions)
        typing.activeTypingDurationSeconds = snapshot.activeTypingDuration
        typing.metricVersion = Int64(snapshot.metricVersion)

        for (app, metrics) in snapshot.typingAppMetricsByApp {
            let record = fetchTypingAppRecord(dayKey: dayKey, bundleIdentifier: app.bundleIdentifier) ?? TypingAppDailyRecord(context: context)
            record.dateKey = dayKey
            record.bundleIdentifier = app.bundleIdentifier
            record.displayName = app.displayName
            record.englishCharacters = Int64(metrics.englishCharacters)
            record.numberCharacters = Int64(metrics.numberCharacters)
            record.symbolCharacters = Int64(metrics.symbolCharacters)
            record.spaceCharacters = Int64(metrics.spaceCharacters)
            record.metricVersion = Int64(snapshot.metricVersion)
        }
    }

    private func fetchAppRecord(dayKey: String, bundleIdentifier: String) -> AppUsageDailyRecord? {
        let request = AppUsageDailyRecord.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@ AND bundleIdentifier == %@", dayKey, bundleIdentifier)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchWebsiteRecord(dayKey: String, domain: String) -> WebsiteUsageDailyRecord? {
        let request = WebsiteUsageDailyRecord.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@ AND domain == %@", dayKey, domain)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchTypingRecord(dayKey: String) -> TypingDailyRecord? {
        let request = TypingDailyRecord.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@ AND metricVersion == %d", dayKey, Self.currentMetricVersion)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchTypingAppRecord(dayKey: String, bundleIdentifier: String) -> TypingAppDailyRecord? {
        let request = TypingAppDailyRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "dateKey == %@ AND bundleIdentifier == %@ AND metricVersion == %d",
            dayKey,
            bundleIdentifier,
            Self.currentMetricVersion
        )
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func normalizeDuplicateRecords(for dayKeys: Set<String>) {
        guard !dayKeys.isEmpty else { return }
        let keys = Array(dayKeys)

        let apps = NSFetchRequest<AppUsageDailyRecord>(entityName: "AppUsageDailyRecord")
        apps.predicate = NSPredicate(format: "dateKey IN %@", keys)
        if let records = try? context.fetch(apps) {
            for duplicates in Dictionary(grouping: records, by: { "\($0.dateKey)|\($0.bundleIdentifier)" }).values where duplicates.count > 1 {
                let canonical = duplicates.sorted {
                    if $0.durationSeconds != $1.durationSeconds { return $0.durationSeconds > $1.durationSeconds }
                    return $0.displayName < $1.displayName
                }.first!
                duplicates.filter { $0 !== canonical }.forEach(context.delete)
            }
        }

        let websites = NSFetchRequest<WebsiteUsageDailyRecord>(entityName: "WebsiteUsageDailyRecord")
        websites.predicate = NSPredicate(format: "dateKey IN %@", keys)
        if let records = try? context.fetch(websites) {
            for duplicates in Dictionary(
                grouping: records,
                by: { "\($0.dateKey)|\($0.browserBundleIdentifier)|\($0.domain)" }
            ).values where duplicates.count > 1 {
                let canonical = duplicates.sorted {
                    if $0.durationSeconds != $1.durationSeconds { return $0.durationSeconds > $1.durationSeconds }
                    return $0.domain < $1.domain
                }.first!
                duplicates.filter { $0 !== canonical }.forEach(context.delete)
            }
        }

        let typing = NSFetchRequest<TypingDailyRecord>(entityName: "TypingDailyRecord")
        typing.predicate = NSPredicate(format: "dateKey IN %@", keys)
        if let records = try? context.fetch(typing) {
            for duplicates in Dictionary(grouping: records, by: { "\($0.dateKey)|\($0.metricVersion)" }).values where duplicates.count > 1 {
                let canonical = duplicates.sorted {
                    if $0.totalCharacters != $1.totalCharacters { return $0.totalCharacters > $1.totalCharacters }
                    return $0.activeTypingDurationSeconds > $1.activeTypingDurationSeconds
                }.first!
                duplicates.filter { $0 !== canonical }.forEach(context.delete)
            }
        }

        let typingApps = NSFetchRequest<TypingAppDailyRecord>(entityName: "TypingAppDailyRecord")
        typingApps.predicate = NSPredicate(format: "dateKey IN %@", keys)
        if let records = try? context.fetch(typingApps) {
            for duplicates in Dictionary(
                grouping: records,
                by: { "\($0.dateKey)|\($0.bundleIdentifier)|\($0.metricVersion)" }
            ).values where duplicates.count > 1 {
                let canonical = duplicates.sorted {
                    if $0.totalCharacters != $1.totalCharacters { return $0.totalCharacters > $1.totalCharacters }
                    return $0.displayName < $1.displayName
                }.first!
                duplicates.filter { $0 !== canonical }.forEach(context.delete)
            }
        }
    }

    private func processForegroundInterval(
        _ interval: ForegroundInterval,
        progress: inout [String: TimeInterval],
        durations: inout [String: [AppIdentity: TimeInterval]]
    ) {
        let key = "\(interval.app.bundleIdentifier)|\(interval.start.timeIntervalSinceReferenceDate)"
        let previous = progress[key, default: 0]
        let duration = max(0, interval.duration)
        guard duration > previous else { return }
        let delta = duration - previous
        let start = interval.start.addingTimeInterval(previous)
        let end = start.addingTimeInterval(delta)
        for (dayKey, segmentDuration) in DayTraceDateKey.segments(
            start: start,
            end: end,
            duration: delta,
            calendar: calendar
        ) {
            mergeAppDuration(
                interval.app,
                duration: segmentDuration,
                into: &durations[dayKey, default: [:]]
            )
            ensureBaseLoaded(for: dayKey)
        }
        progress[key] = duration
    }

    private func mergeAppDuration(
        _ app: AppIdentity,
        duration: TimeInterval,
        into durations: inout [AppIdentity: TimeInterval]
    ) {
        if let existing = durations.keys.first(where: { $0.bundleIdentifier == app.bundleIdentifier }), existing.displayName != app.displayName {
            let existingDuration = durations.removeValue(forKey: existing) ?? 0
            durations[app] = existingDuration + duration
        } else {
            durations[app, default: 0] += duration
        }
    }

    private func removeAppMetrics(
        for app: AppIdentity,
        from metrics: inout [AppIdentity: AppTypingMetrics]
    ) -> AppTypingMetrics {
        guard let existing = metrics.keys.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) else {
            return AppTypingMetrics()
        }
        return metrics.removeValue(forKey: existing) ?? AppTypingMetrics()
    }

    private func processDomainInterval(
        _ interval: DomainInterval,
        progress: inout [String: TimeInterval],
        durations: inout [String: [String: TimeInterval]]
    ) {
        let key = "\(interval.domain)|\(interval.start.timeIntervalSinceReferenceDate)"
        let previous = progress[key, default: 0]
        let duration = max(0, interval.duration)
        guard duration > previous else { return }
        let delta = duration - previous
        let start = interval.start.addingTimeInterval(previous)
        let end = start.addingTimeInterval(delta)
        for (dayKey, segmentDuration) in DayTraceDateKey.segments(
            start: start,
            end: end,
            duration: delta,
            calendar: calendar
        ) {
            durations[dayKey, default: [:]][interval.domain, default: 0] += segmentDuration
            ensureBaseLoaded(for: dayKey)
        }
        progress[key] = duration
    }

    private static func defaultStoreURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = base.appendingPathComponent("DayTrace", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("DayTrace.sqlite")
    }
}

private struct RuntimeTypingState {
    var metrics = TypingMetrics()
    var appMetricsByApp: [AppIdentity: AppTypingMetrics] = [:]
    var typingSessions = 0
    var activeTypingDuration: TimeInterval = 0
    var lastEventAt: Date?
}

private enum DayTraceDateKey {
    static func key(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func segments(
        start: Date,
        end: Date,
        duration: TimeInterval,
        calendar: Calendar
    ) -> [(String, TimeInterval)] {
        guard end > start, duration > 0 else { return [] }
        let wallDuration = end.timeIntervalSince(start)
        var cursor = start
        var result: [(String, TimeInterval)] = []
        while cursor < end {
            let dayStart = calendar.startOfDay(for: cursor)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? end
            let segmentEnd = min(end, nextDay)
            let wallSegment = segmentEnd.timeIntervalSince(cursor)
            let segmentDuration = segmentEnd == end
                ? duration - result.reduce(0) { $0 + $1.1 }
                : duration * wallSegment / wallDuration
            result.append((key(for: cursor, calendar: calendar), max(0, segmentDuration)))
            cursor = segmentEnd
        }
        return result
    }
}

private enum UsageStoreModel {
    // Reuse one model instance for the process. Core Data associates managed
    // subclasses with their model; constructing a separate model for every
    // in-memory test store makes class lookup ambiguous and emits duplicate
    // entity warnings.
    private static let shared = makeModel()

    static func make() -> NSManagedObjectModel {
        shared
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            entity(
                name: "AppUsageDailyRecord",
                managedClassName: "AppUsageDailyRecord",
                attributes: [
                    attribute("dateKey", .stringAttributeType),
                    attribute("bundleIdentifier", .stringAttributeType),
                    attribute("displayName", .stringAttributeType),
                    attribute("durationSeconds", .doubleAttributeType)
                ],
                uniquenessConstraints: [["dateKey", "bundleIdentifier"]]
            ),
            entity(
                name: "WebsiteUsageDailyRecord",
                managedClassName: "WebsiteUsageDailyRecord",
                attributes: [
                    attribute("dateKey", .stringAttributeType),
                    attribute("browserBundleIdentifier", .stringAttributeType),
                    attribute("domain", .stringAttributeType),
                    attribute("durationSeconds", .doubleAttributeType)
                ],
                uniquenessConstraints: [["dateKey", "browserBundleIdentifier", "domain"]]
            ),
            entity(
                name: "TypingDailyRecord",
                managedClassName: "TypingDailyRecord",
                attributes: [
                    attribute("dateKey", .stringAttributeType),
                    attribute("englishCharacters", .integer64AttributeType),
                    attribute("numberCharacters", .integer64AttributeType),
                    attribute("symbolCharacters", .integer64AttributeType),
                    attribute("spaceCharacters", .integer64AttributeType),
                    attribute("typingSessions", .integer64AttributeType),
                    attribute("activeTypingDurationSeconds", .doubleAttributeType),
                    attribute("metricVersion", .integer64AttributeType, defaultValue: Int64(UsageStore.currentMetricVersion))
                ],
                uniquenessConstraints: [["dateKey", "metricVersion"]]
            ),
            entity(
                name: "TypingAppDailyRecord",
                managedClassName: "TypingAppDailyRecord",
                attributes: [
                    attribute("dateKey", .stringAttributeType),
                    attribute("bundleIdentifier", .stringAttributeType),
                    attribute("displayName", .stringAttributeType),
                    attribute("englishCharacters", .integer64AttributeType),
                    attribute("numberCharacters", .integer64AttributeType),
                    attribute("symbolCharacters", .integer64AttributeType),
                    attribute("spaceCharacters", .integer64AttributeType),
                    attribute("metricVersion", .integer64AttributeType, defaultValue: Int64(UsageStore.currentMetricVersion))
                ],
                uniquenessConstraints: [["dateKey", "bundleIdentifier", "metricVersion"]]
            )
        ]
        return model
    }

    private static func entity(
        name: String,
        managedClassName: String,
        attributes: [NSAttributeDescription],
        uniquenessConstraints: [[String]] = []
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = managedClassName
        entity.properties = attributes
        entity.uniquenessConstraints = uniquenessConstraints
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = false
        attribute.defaultValue = defaultValue
        return attribute
    }
}

private extension AppTypingMetrics {
    mutating func adding(_ other: AppTypingMetrics) {
        self = AppTypingMetrics(
            englishCharacters: englishCharacters + other.englishCharacters,
            numberCharacters: numberCharacters + other.numberCharacters,
            symbolCharacters: symbolCharacters + other.symbolCharacters,
            spaceCharacters: spaceCharacters + other.spaceCharacters
        )
    }
}

private extension TypingDailyRecord {
    var totalCharacters: Int64 {
        englishCharacters + numberCharacters + symbolCharacters + spaceCharacters
    }
}

private extension TypingAppDailyRecord {
    var totalCharacters: Int64 {
        englishCharacters + numberCharacters + symbolCharacters + spaceCharacters
    }
}
