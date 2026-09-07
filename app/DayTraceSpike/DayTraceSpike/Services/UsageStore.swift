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

/// Website attribution is derived from raw observations and the matching
/// Chrome foreground total. Raw website durations remain available in the
/// store; this helper only produces a user-facing/reported view.
enum WebsiteUsageReconciliation {
    static func reconcile(
        websiteUsage: [String: TimeInterval],
        chromeUsage: TimeInterval
    ) -> [String: TimeInterval] {
        let finiteChromeUsage = chromeUsage.isFinite ? max(0, chromeUsage) : 0
        var sanitized: [String: TimeInterval] = [:]
        for (domain, duration) in websiteUsage {
            guard duration.isFinite else { continue }
            let safeDuration = max(0, duration)
            if safeDuration > 0 {
                sanitized[domain] = safeDuration
            }
        }

        guard finiteChromeUsage > 0 else { return [:] }
        let websiteTotal = sanitized.values.reduce(0, +)
        guard websiteTotal.isFinite, websiteTotal > finiteChromeUsage else {
            return sanitized
        }

        let scale = finiteChromeUsage / websiteTotal
        return sanitized.reduce(into: [:]) { result, entry in
            let scaledDuration = entry.value * scale
            if scaledDuration.isFinite, scaledDuration > 0 {
                result[entry.key] = scaledDuration
            }
        }
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

enum HistoryRange: String, CaseIterable, Identifiable {
    case today
    case yesterday
    case last7Days
    case last30Days
    case thisWeek
    case thisMonth

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .today: return "history.range.today"
        case .yesterday: return "history.range.yesterday"
        case .last7Days: return "history.range.last7Days"
        case .last30Days: return "history.range.last30Days"
        case .thisWeek: return "history.range.thisWeek"
        case .thisMonth: return "history.range.thisMonth"
        }
    }

    func startDate(at date: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: date)
        switch self {
        case .today:
            return today
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: today) ?? today
        case .last7Days:
            return calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .last30Days:
            return calendar.date(byAdding: .day, value: -29, to: today) ?? today
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? today
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: date)?.start ?? today
        }
    }
}

struct HistoryDay: Identifiable, Equatable {
    let date: Date
    let totalUsage: TimeInterval

    var id: Date { date }
}

struct HistoryUsageSnapshot: Equatable {
    let range: HistoryRange
    let startDate: Date
    let endDate: Date
    var appUsageByApp: [AppIdentity: TimeInterval] = [:]
    var websiteUsageByDomain: [String: TimeInterval] = [:]
    var typingMetrics = TypingMetrics()
    var typingAppMetricsByApp: [AppIdentity: AppTypingMetrics] = [:]
    var typingSessions = 0
    var activeTypingDuration: TimeInterval = 0
    var dailyTotals: [HistoryDay] = []

    var totalUsage: TimeInterval {
        appUsageByApp.values.reduce(0, +)
    }

    var typingActivity: TypingActivitySnapshot {
        TypingActivitySnapshot(
            metrics: typingMetrics,
            appMetricsByApp: typingAppMetricsByApp,
            typingSessions: typingSessions,
            activeTypingDuration: activeTypingDuration
        )
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
    private var timelineRuntime = TimelineRuntimeState()
    private var backgroundRuntime = BackgroundRuntimeState()

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

        recoverOpenTimelineRecords()
        recoverOpenBackgroundActivityRecords()

        loadBaseSnapshot(for: DayTraceDateKey.key(for: Date(), calendar: calendar))
    }

    var isTimelineAvailable: Bool { status.isReady }

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

    func historySnapshot(
        for range: HistoryRange,
        at date: Date = Date(),
        foregroundTracker: ForegroundTracker? = nil,
        domainTracker: DomainTracker? = nil
    ) -> HistoryUsageSnapshot {
        let startDate = range.startDate(at: date, calendar: calendar)
        let todayStart = calendar.startOfDay(for: date)
        let endDate = range == .yesterday
            ? calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            : todayStart
        let currentDayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        let resultEndDate = range == .yesterday
            ? calendar.date(byAdding: .day, value: -1, to: date) ?? date
            : date
        var result = HistoryUsageSnapshot(range: range, startDate: startDate, endDate: resultEndDate)
        var cursor = startDate

        while cursor <= endDate {
            let dayKey = DayTraceDateKey.key(for: cursor, calendar: calendar)
            let daySnapshot: DailyUsageSnapshot
            if dayKey == currentDayKey {
                if let foregroundTracker, let domainTracker {
                    daySnapshot = liveSnapshot(
                        at: date,
                        foregroundTracker: foregroundTracker,
                        domainTracker: domainTracker
                    )
                } else {
                    daySnapshot = snapshot(at: date)
                }
            } else {
                ensureBaseLoaded(for: dayKey)
                // Include runtime intervals that have not crossed a
                // checkpoint, even when the queried day is no longer today.
                daySnapshot = snapshot(
                    for: dayKey,
                    appDurations: runtimeAppDurationsByDay,
                    domainDurations: runtimeDomainDurationsByDay
                )
            }
            merge(daySnapshot, into: &result)
            result.dailyTotals.append(HistoryDay(date: cursor, totalUsage: daySnapshot.totalUsage))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? endDate.addingTimeInterval(1)
        }

        return result
    }

    func timeline(for date: Date, now: Date = Date()) -> DailyTimelineSnapshot {
        let dayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        guard status.isReady else { return .empty(for: date, calendar: calendar) }
        let request = AppUsageIntervalRecord.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", dayKey)
        let appRecords = (try? context.fetch(request)) ?? []
        let websiteRequest = WebsiteUsageIntervalRecord.fetchRequest()
        websiteRequest.predicate = NSPredicate(format: "dateKey == %@", dayKey)
        let websiteRecords = (try? context.fetch(websiteRequest)) ?? []

        var apps = appRecords.compactMap { record -> TimelineAppInterval? in
            guard let valid = TimelineIntervalNormalizer.validated(start: record.startAt, end: min(record.endAt, now)) else { return nil }
            return TimelineAppInterval(
                id: record.idString, dateKey: record.dateKey, start: valid.start, end: valid.end,
                duration: valid.duration,
                app: AppIdentity(bundleIdentifier: record.bundleIdentifier, displayName: record.displayName),
                isOpen: record.isOpen && record.endAt >= now
            )
        }
        var websites = websiteRecords.compactMap { record -> TimelineWebsiteInterval? in
            guard let valid = TimelineIntervalNormalizer.validated(start: record.startAt, end: min(record.endAt, now)) else { return nil }
            return TimelineWebsiteInterval(
                id: record.idString, dateKey: record.dateKey, start: valid.start, end: valid.end,
                duration: valid.duration, domain: record.domain,
                browserBundleIdentifier: record.browserBundleIdentifier,
                parentAppIntervalID: record.parentAppIntervalID,
                isOpen: record.isOpen && record.endAt >= now
            )
        }

        if dayKey == DayTraceDateKey.key(for: now, calendar: calendar) {
            apps.append(contentsOf: liveAppTimelineIntervals(at: now, dateKey: dayKey))
            websites.append(contentsOf: liveWebsiteTimelineIntervals(at: now, dateKey: dayKey))
        }
        apps = Array(Dictionary(grouping: apps, by: \.id).values.compactMap { records in
            records.max { lhs, rhs in
                if lhs.end != rhs.end { return lhs.end < rhs.end }
                if lhs.isOpen != rhs.isOpen { return !lhs.isOpen && rhs.isOpen }
                return lhs.start < rhs.start
            }
        })
        websites = Array(Dictionary(grouping: websites, by: \.id).values.compactMap { records in
            records.max { lhs, rhs in
                if lhs.end != rhs.end { return lhs.end < rhs.end }
                if lhs.isOpen != rhs.isOpen { return !lhs.isOpen && rhs.isOpen }
                return lhs.start < rhs.start
            }
        })
        apps = TimelineIntervalNormalizer.normalizeAppIntervals(apps)
        websites = TimelineIntervalNormalizer.normalizeWebsiteIntervals(websites)
        return DailyTimelineSnapshot(
            date: date,
            dateKey: dayKey,
            appIntervals: apps,
            websiteIntervals: websites,
            chromeGaps: TimelineIntervalNormalizer.chromeGaps(appIntervals: apps, websiteIntervals: websites),
            isRecorded: !apps.isEmpty || !websites.isEmpty
        )
    }

    func appIntervals(for date: Date) -> [TimelineAppInterval] { timeline(for: date).appIntervals }
    func websiteIntervals(for date: Date) -> [TimelineWebsiteInterval] { timeline(for: date).websiteIntervals }

    func timelineStatistics(enabled: Bool) -> TimelineDataStatistics {
        guard status.isReady else { return TimelineDataStatistics(enabled: enabled, startDate: nil, appIntervalCount: 0, websiteIntervalCount: 0, estimatedBytes: nil) }
        let apps = (try? context.fetch(AppUsageIntervalRecord.fetchRequest())) ?? []
        let websites = (try? context.fetch(WebsiteUsageIntervalRecord.fetchRequest())) ?? []
        let startDate = (apps.map(\.startAt) + websites.map(\.startAt)).min()
        return TimelineDataStatistics(
            enabled: enabled, startDate: startDate,
            appIntervalCount: apps.count, websiteIntervalCount: websites.count,
            estimatedBytes: nil
        )
    }

    func backgroundSummary(for date: Date, now: Date = Date()) -> BackgroundActivitySummary {
        let dayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        guard status.isReady else { return .empty }
        let request = BackgroundActivityIntervalRecord.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", dayKey)
        var intervals = (try? context.fetch(request))?.compactMap { backgroundInterval(from: $0, now: now) } ?? []
        if dayKey == DayTraceDateKey.key(for: now, calendar: calendar) {
            intervals.append(contentsOf: backgroundRuntime.liveIntervals(at: now, dateKey: dayKey, calendar: calendar))
        }
        intervals = Array(Dictionary(grouping: intervals, by: \.id).values.compactMap { records in
            records.max { lhs, rhs in
                if lhs.end != rhs.end { return lhs.end < rhs.end }
                return !lhs.isOpen && rhs.isOpen
            }
        }).sorted { $0.start < $1.start }
        var durationsByApp: [AppIdentity: TimeInterval] = [:]
        var durationsByKind: [BackgroundActivityKind: TimeInterval] = [:]
        for interval in intervals {
            durationsByApp[interval.app, default: 0] += interval.duration
            durationsByKind[interval.activityKind, default: 0] += interval.duration
        }
        return BackgroundActivitySummary(intervals: intervals, durationsByApp: durationsByApp, durationsByKind: durationsByKind)
    }

    func backgroundDataStatistics() -> BackgroundDataStatistics {
        guard status.isReady else { return BackgroundDataStatistics(intervalCount: 0, startDate: nil) }
        let records = (try? context.fetch(BackgroundActivityIntervalRecord.fetchRequest())) ?? []
        return BackgroundDataStatistics(intervalCount: records.count, startDate: records.map(\.startAt).min())
    }

    @discardableResult
    func updateBackgroundActivity(
        snapshots: [BackgroundDetectorSnapshot],
        foregroundApp: AppIdentity?,
        trackingState: TrackingSystemState,
        globallyEnabled: Bool,
        enabledDetectorIdentifiers: Set<String>,
        at date: Date
    ) -> Bool {
        let canRecord = globallyEnabled && trackingState == .awake
        let desired = Set(snapshots.compactMap { snapshot -> String? in
            guard canRecord,
                  enabledDetectorIdentifiers.contains(snapshot.identifier),
                  snapshot.isActive,
                  snapshot.app.bundleIdentifier != foregroundApp?.bundleIdentifier else { return nil }
            return snapshot.identifier
        })
        var transitioned = false
        let openActivities = backgroundRuntime.openByDetector
        for (identifier, active) in openActivities {
            guard !desired.contains(identifier) else { continue }
            backgroundRuntime.closed.append(active.closed(at: date))
            backgroundRuntime.openByDetector.removeValue(forKey: identifier)
            transitioned = true
        }
        for snapshot in snapshots where desired.contains(snapshot.identifier) {
            if var active = backgroundRuntime.openByDetector[snapshot.identifier] {
                active.end = max(active.end, date)
                active.app = snapshot.app
                backgroundRuntime.openByDetector[snapshot.identifier] = active
            } else {
                backgroundRuntime.openByDetector[snapshot.identifier] = BackgroundRuntimeActivity(
                    sourceID: UUID().uuidString,
                    detectorIdentifier: snapshot.identifier,
                    app: snapshot.app,
                    activityKind: snapshot.activityKind,
                    start: date,
                    end: date
                )
                transitioned = true
            }
        }
        return transitioned
    }

    func closeBackgroundActivityIntervals(at date: Date) {
        for active in backgroundRuntime.openByDetector.values {
            backgroundRuntime.closed.append(active.closed(at: date))
        }
        backgroundRuntime.openByDetector.removeAll()
    }

    @discardableResult
    func deleteTimelineHistory(at date: Date = Date()) -> Bool {
        guard status.isReady else { return false }
        do {
            for name in ["AppUsageIntervalRecord", "WebsiteUsageIntervalRecord"] {
                let objects = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name))
                objects.forEach(context.delete)
            }
            try saveContext()
            timelineRuntime = TimelineRuntimeState(anchorDate: date)
            revision += 1
            return true
        } catch {
            context.rollback()
            status = .degraded(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func setTimelineEnabled(_ enabled: Bool, at date: Date = Date()) -> Bool {
        guard status.isReady else { return false }
        do {
            if !enabled {
                let apps = try context.fetch(AppUsageIntervalRecord.fetchRequest()).filter(\.isOpen)
                apps.forEach { close($0, at: date) }
                let websites = try context.fetch(WebsiteUsageIntervalRecord.fetchRequest()).filter(\.isOpen)
                websites.forEach { close($0, at: date) }
            }
            try saveContext()
            timelineRuntime = TimelineRuntimeState(anchorDate: enabled ? date : date)
            revision += 1
            return true
        } catch {
            context.rollback()
            status = .degraded(error.localizedDescription)
            return false
        }
    }

    func exportAggregatesJSON(includeDetailedTimeline: Bool = false) -> Data? {
        guard status.isReady else { return nil }
        let appRequest = AppUsageDailyRecord.fetchRequest()
        let websiteRequest = WebsiteUsageDailyRecord.fetchRequest()
        let typingRequest = TypingDailyRecord.fetchRequest()
        let typingAppRequest = TypingAppDailyRecord.fetchRequest()

        guard let apps = try? context.fetch(appRequest),
              let websites = try? context.fetch(websiteRequest),
              let typing = try? context.fetch(typingRequest),
              let typingApps = try? context.fetch(typingAppRequest) else {
            return nil
        }

        let sortedApps = apps.sorted {
            if $0.dateKey != $1.dateKey { return $0.dateKey < $1.dateKey }
            if $0.bundleIdentifier != $1.bundleIdentifier { return $0.bundleIdentifier < $1.bundleIdentifier }
            if $0.durationSeconds != $1.durationSeconds { return $0.durationSeconds < $1.durationSeconds }
            return $0.displayName < $1.displayName
        }
        let sortedTyping = typing
            .filter { $0.metricVersion == Int64(Self.currentMetricVersion) }
            .sorted { $0.dateKey < $1.dateKey }
        let sortedTypingApps = typingApps
            .filter { $0.metricVersion == Int64(Self.currentMetricVersion) }
            .sorted {
                if $0.dateKey != $1.dateKey { return $0.dateKey < $1.dateKey }
                return $0.bundleIdentifier < $1.bundleIdentifier
            }

        // Persisted website records are raw observations. Export must use the
        // same derived attribution rule as Dashboard and History, while the
        // app and typing aggregates remain aggregate-only records.
        var chromeUsageByDay: [String: TimeInterval] = [:]
        for record in apps where record.bundleIdentifier == "com.google.Chrome" {
            guard record.durationSeconds.isFinite else { continue }
            chromeUsageByDay[record.dateKey] = max(
                chromeUsageByDay[record.dateKey, default: 0],
                max(0, record.durationSeconds)
            )
        }
        var rawWebsiteUsageByDay: [String: [String: TimeInterval]] = [:]
        for record in websites {
            guard record.durationSeconds.isFinite else { continue }
            rawWebsiteUsageByDay[record.dateKey, default: [:]][record.domain] = max(
                rawWebsiteUsageByDay[record.dateKey, default: [:]][record.domain, default: 0],
                max(0, record.durationSeconds)
            )
        }
        let derivedWebsiteUsage = rawWebsiteUsageByDay.keys.sorted().flatMap { dayKey in
            let derived = WebsiteUsageReconciliation.reconcile(
                websiteUsage: rawWebsiteUsageByDay[dayKey, default: [:]],
                chromeUsage: chromeUsageByDay[dayKey, default: 0]
            )
            return derived.keys.sorted().map { domain in
                [
                    "date": dayKey,
                    "browser": "com.google.Chrome",
                    "domain": domain,
                    "durationSeconds": derived[domain] ?? 0
                ]
            }
        }

        var object: [String: Any] = [
            "schemaVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "appUsage": sortedApps.map {
                [
                    "date": $0.dateKey,
                    "bundleIdentifier": $0.bundleIdentifier,
                    "displayName": $0.displayName,
                    "durationSeconds": $0.durationSeconds
                ]
            },
            "websiteUsage": derivedWebsiteUsage,
            "typing": sortedTyping.map {
                [
                    "date": $0.dateKey,
                    "englishCharacters": $0.englishCharacters,
                    "numberCharacters": $0.numberCharacters,
                    "symbolCharacters": $0.symbolCharacters,
                    "spaceCharacters": $0.spaceCharacters,
                    "typingSessions": $0.typingSessions,
                    "activeTypingDurationSeconds": $0.activeTypingDurationSeconds,
                    "metricVersion": $0.metricVersion
                ]
            },
            "typingByApp": sortedTypingApps.map {
                [
                    "date": $0.dateKey,
                    "bundleIdentifier": $0.bundleIdentifier,
                    "displayName": $0.displayName,
                    "englishCharacters": $0.englishCharacters,
                    "numberCharacters": $0.numberCharacters,
                    "symbolCharacters": $0.symbolCharacters,
                    "spaceCharacters": $0.spaceCharacters,
                    "metricVersion": $0.metricVersion
                ]
            }
        ]

        if includeDetailedTimeline {
            let intervalApps = (try? context.fetch(AppUsageIntervalRecord.fetchRequest())) ?? []
            let intervalWebsites = (try? context.fetch(WebsiteUsageIntervalRecord.fetchRequest())) ?? []
            let backgroundIntervals = (try? context.fetch(BackgroundActivityIntervalRecord.fetchRequest())) ?? []
            object["detailedTimeline"] = [
                "apps": intervalApps.sorted { $0.startAt < $1.startAt }.map {
                    ["date": $0.dateKey, "start": ISO8601DateFormatter().string(from: $0.startAt), "end": ISO8601DateFormatter().string(from: $0.endAt), "durationSeconds": $0.durationSeconds, "bundleIdentifier": $0.bundleIdentifier, "displayName": $0.displayName]
                },
                "websites": intervalWebsites.sorted { $0.startAt < $1.startAt }.map {
                    ["date": $0.dateKey, "start": ISO8601DateFormatter().string(from: $0.startAt), "end": ISO8601DateFormatter().string(from: $0.endAt), "durationSeconds": $0.durationSeconds, "browser": $0.browserBundleIdentifier, "domain": $0.domain]
                },
                "backgroundIntervals": backgroundIntervals.sorted { $0.startAt < $1.startAt }.map {
                    ["date": $0.dateKey, "start": ISO8601DateFormatter().string(from: $0.startAt), "end": ISO8601DateFormatter().string(from: $0.endAt), "durationSeconds": $0.durationSeconds, "bundleIdentifier": $0.bundleIdentifier, "displayName": $0.displayName, "activityKind": $0.activityKindRawValue]
                }
            ]
        }

        return try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    @discardableResult
    func deleteAllData() -> Bool {
        guard status.isReady else { return false }
        let entityNames = [
            "AppUsageDailyRecord",
            "WebsiteUsageDailyRecord",
            "TypingDailyRecord",
            "TypingAppDailyRecord",
            "AppUsageIntervalRecord",
            "WebsiteUsageIntervalRecord",
            "BackgroundActivityIntervalRecord"
        ]

        do {
            for entityName in entityNames {
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                let objects = try context.fetch(request)
                objects.forEach(context.delete)
            }
            if let saveHandler {
                try saveHandler(context)
            } else {
                try context.save()
            }
            loadedDayKeys.removeAll()
            baseSnapshotsByDay.removeAll()
            runtimeAppDurationsByDay.removeAll()
            runtimeDomainDurationsByDay.removeAll()
            runtimeTypingByDay.removeAll()
            foregroundProgressByInterval.removeAll()
            domainProgressByInterval.removeAll()
            timelineRuntime = TimelineRuntimeState(anchorDate: Date())
            backgroundRuntime = BackgroundRuntimeState(anchorDate: Date())
            lastCheckpointAt = nil
            revision += 1
            status = .ready
            return true
        } catch {
            context.rollback()
            status = .degraded(error.localizedDescription)
            revision += 1
            return false
        }
    }

    @discardableResult
    func deleteBackgroundActivityHistory() -> Bool {
        guard status.isReady else { return false }
        do {
            let records = try context.fetch(BackgroundActivityIntervalRecord.fetchRequest())
            records.forEach(context.delete)
            try saveContext()
            backgroundRuntime = BackgroundRuntimeState(anchorDate: Date())
            revision += 1
            return true
        } catch {
            context.rollback()
            status = .degraded(error.localizedDescription)
            revision += 1
            return false
        }
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

    @discardableResult
    func checkpoint(at date: Date = Date()) -> Bool {
        ensureBaseLoaded(for: DayTraceDateKey.key(for: date, calendar: calendar))
        return persistRuntimeSnapshots(at: date)
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

    func seedAppRecordForTesting(at date: Date, app: AppIdentity, duration: TimeInterval) {
        guard status.isReady else { return }
        let dayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        let record = AppUsageDailyRecord(context: context)
        record.dateKey = dayKey
        record.bundleIdentifier = app.bundleIdentifier
        record.displayName = app.displayName
        record.durationSeconds = max(0, duration)
        try? context.save()
        loadedDayKeys.remove(dayKey)
        baseSnapshotsByDay.removeValue(forKey: dayKey)
    }

    @discardableResult
    func checkpoint(
        foregroundTracker: ForegroundTracker,
        domainTracker: DomainTracker,
        at date: Date = Date(),
        timelineEnabled: Bool = true,
        finalizeTimeline: Bool = false,
        backgroundObservations: [BackgroundDetectorSnapshot] = [],
        backgroundActivityEnabled: Bool = false,
        enabledBackgroundDetectorIdentifiers: Set<String> = [],
        finalizeBackgroundActivity: Bool = false
    ) -> Bool {
        if !backgroundObservations.isEmpty || backgroundActivityEnabled || !enabledBackgroundDetectorIdentifiers.isEmpty || finalizeBackgroundActivity {
            _ = updateBackgroundActivity(
                snapshots: backgroundObservations,
                foregroundApp: foregroundTracker.currentApp,
                trackingState: foregroundTracker.isTracking ? foregroundTracker.systemState : .paused,
                globallyEnabled: backgroundActivityEnabled,
                enabledDetectorIdentifiers: enabledBackgroundDetectorIdentifiers,
                at: date
            )
        }
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
            domainDurations: candidateDomainDurations,
            timelineState: timelineRuntime,
            backgroundState: backgroundRuntime,
            foregroundTracker: foregroundTracker,
            domainTracker: domainTracker,
            timelineEnabled: timelineEnabled,
            finalizeTimeline: finalizeTimeline,
            finalizeBackgroundActivity: finalizeBackgroundActivity
        ) {
            // A persistence cursor is committed only after context.save()
            // succeeds. A failed save leaves the prior cursor and runtime
            // maps untouched so the same delta can be retried.
            foregroundProgressByInterval = candidateForegroundProgress
            domainProgressByInterval = candidateDomainProgress
            runtimeAppDurationsByDay = candidateAppDurations
            runtimeDomainDurationsByDay = candidateDomainDurations
            return true
        }
        return false
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

    func rawWebsiteDurationForTesting(at date: Date, domain: String) -> TimeInterval {
        let dayKey = DayTraceDateKey.key(for: date, calendar: calendar)
        let request = WebsiteUsageDailyRecord.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@ AND domain == %@", dayKey, domain)
        guard let records = try? context.fetch(request) else { return 0 }
        return records.map(\.durationSeconds).max() ?? 0
    }

    func seedAppIntervalForTesting(
        id: String = UUID().uuidString,
        app: AppIdentity,
        start: Date,
        end: Date,
        isOpen: Bool = false
    ) {
        guard let valid = TimelineIntervalNormalizer.validated(start: start, end: end) else { return }
        let record = fetchAppInterval(id: id) ?? AppUsageIntervalRecord(context: context)
        record.idString = id; record.dateKey = DayTraceDateKey.key(for: start, calendar: calendar)
        record.startAt = valid.start; record.endAt = valid.end; record.durationSeconds = valid.duration
        record.isOpen = isOpen; record.bundleIdentifier = app.bundleIdentifier; record.displayName = app.displayName
        try? context.save()
    }

    func seedWebsiteIntervalForTesting(
        id: String = UUID().uuidString,
        domain: String,
        start: Date,
        end: Date,
        isOpen: Bool = false
    ) {
        guard let valid = TimelineIntervalNormalizer.validated(start: start, end: end) else { return }
        let record = fetchWebsiteInterval(id: id) ?? WebsiteUsageIntervalRecord(context: context)
        record.idString = id; record.dateKey = DayTraceDateKey.key(for: start, calendar: calendar)
        record.startAt = valid.start; record.endAt = valid.end; record.durationSeconds = valid.duration
        record.isOpen = isOpen; record.browserBundleIdentifier = "com.google.Chrome"; record.domain = domain
        try? context.save()
    }

    func seedBackgroundIntervalForTesting(
        id: String = UUID().uuidString,
        app: AppIdentity,
        activityKind: BackgroundActivityKind,
        detectorIdentifier: String,
        start: Date,
        end: Date,
        isOpen: Bool = false
    ) {
        guard let valid = TimelineIntervalNormalizer.validated(start: start, end: end) else { return }
        let record = fetchBackgroundInterval(id: id) ?? BackgroundActivityIntervalRecord(context: context)
        record.idString = id
        record.dateKey = DayTraceDateKey.key(for: start, calendar: calendar)
        record.startAt = valid.start
        record.endAt = valid.end
        record.durationSeconds = valid.duration
        record.isOpen = isOpen
        record.bundleIdentifier = app.bundleIdentifier
        record.displayName = app.displayName
        record.activityKindRawValue = activityKind.rawValue
        record.detectorIdentifier = detectorIdentifier
        try? context.save()
    }

    private func fetchAppInterval(id: String) -> AppUsageIntervalRecord? {
        let request = AppUsageIntervalRecord.fetchRequest()
        request.predicate = NSPredicate(format: "idString == %@", id)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchWebsiteInterval(id: String) -> WebsiteUsageIntervalRecord? {
        let request = WebsiteUsageIntervalRecord.fetchRequest()
        request.predicate = NSPredicate(format: "idString == %@", id)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func nearestChromeAppIntervalID(start: Date, end: Date) -> String? {
        let request = AppUsageIntervalRecord.fetchRequest()
        request.predicate = NSPredicate(format: "bundleIdentifier == %@ AND startAt < %@ AND endAt > %@", "com.google.Chrome", end as NSDate, start as NSDate)
        request.fetchLimit = 1
        return try? context.fetch(request).first?.idString
    }

    private func close(_ record: AppUsageIntervalRecord, at date: Date) {
        guard date > record.startAt else { record.isOpen = false; return }
        record.endAt = min(date, record.endAt)
        record.durationSeconds = max(0, record.endAt.timeIntervalSince(record.startAt))
        record.isOpen = false
    }

    private func close(_ record: WebsiteUsageIntervalRecord, at date: Date) {
        guard date > record.startAt else { record.isOpen = false; return }
        record.endAt = min(date, record.endAt)
        record.durationSeconds = max(0, record.endAt.timeIntervalSince(record.startAt))
        record.isOpen = false
    }

    private func recoverOpenTimelineRecords() {
        guard status.isReady else { return }
        let apps = (try? context.fetch(AppUsageIntervalRecord.fetchRequest()))?.filter(\.isOpen) ?? []
        let websites = (try? context.fetch(WebsiteUsageIntervalRecord.fetchRequest()))?.filter(\.isOpen) ?? []
        guard !apps.isEmpty || !websites.isEmpty else { return }
        apps.forEach { $0.isOpen = false }
        websites.forEach { $0.isOpen = false }
        do { try saveContext() } catch { context.rollback(); status = .degraded(error.localizedDescription) }
    }

    private func recoverOpenBackgroundActivityRecords() {
        guard status.isReady else { return }
        let records = (try? context.fetch(BackgroundActivityIntervalRecord.fetchRequest()))?.filter(\.isOpen) ?? []
        guard !records.isEmpty else { return }
        records.forEach { $0.isOpen = false }
        do { try saveContext() } catch { context.rollback(); status = .degraded(error.localizedDescription) }
    }

    private func saveContext() throws {
        if let saveHandler { try saveHandler(context) } else { try context.save() }
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

    private func liveAppTimelineIntervals(at date: Date, dateKey: String) -> [TimelineAppInterval] {
        guard let app = timelineRuntime.activeApp,
              app.bundleIdentifier != "com.apple.loginwindow",
              let start = timelineRuntime.activeAppStart,
              date > start else { return [] }
        let segments = TimelineIntervalNormalizer.split(start: start, end: date, calendar: calendar)
        return segments.filter { $0.dateKey == dateKey }.compactMap { segment in
            let id = timelineRuntime.appSegmentIDs["active|\(app.bundleIdentifier)|\(start.timeIntervalSinceReferenceDate)|\(segment.dateKey)"] ?? ""
            guard !id.isEmpty else { return nil }
            return TimelineAppInterval(id: id, dateKey: segment.dateKey, start: segment.start, end: segment.end, duration: segment.duration, app: app, isOpen: segment.end == date)
        }
    }

    private func liveWebsiteTimelineIntervals(at date: Date, dateKey: String) -> [TimelineWebsiteInterval] {
        guard let domain = timelineRuntime.activeWebsiteDomain,
              let start = timelineRuntime.activeWebsiteStart,
              date > start else { return [] }
        let segments = TimelineIntervalNormalizer.split(start: start, end: date, calendar: calendar)
        return segments.filter { $0.dateKey == dateKey }.compactMap { segment in
            let id = timelineRuntime.websiteSegmentIDs["active|\(domain)|\(start.timeIntervalSinceReferenceDate)|\(segment.dateKey)"] ?? ""
            guard !id.isEmpty else { return nil }
            return TimelineWebsiteInterval(id: id, dateKey: segment.dateKey, start: segment.start, end: segment.end, duration: segment.duration, domain: domain, browserBundleIdentifier: "com.google.Chrome", parentAppIntervalID: nil, isOpen: segment.end == date)
        }
    }

    @discardableResult
    private func persistRuntimeSnapshots(
        at date: Date,
        appDurations: [String: [AppIdentity: TimeInterval]]? = nil,
        domainDurations: [String: [String: TimeInterval]]? = nil,
        timelineState: TimelineRuntimeState? = nil,
        backgroundState: BackgroundRuntimeState? = nil,
        foregroundTracker: ForegroundTracker? = nil,
        domainTracker: DomainTracker? = nil,
        timelineEnabled: Bool = true,
        finalizeTimeline: Bool = false,
        finalizeBackgroundActivity: Bool = false
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
                rawSnapshot(for: dayKey, appDurations: appDurations, domainDurations: domainDurations),
                dayKey: dayKey
            )
        }

        let timelineStateForCommit = timelineState
        var committedTimelineState: TimelineRuntimeState?
        var committedBackgroundState: BackgroundRuntimeState?
        if let foregroundTracker, let domainTracker, var candidateTimelineState = timelineStateForCommit {
            syncTimeline(
                state: &candidateTimelineState,
                foregroundTracker: foregroundTracker,
                domainTracker: domainTracker,
                at: date,
                enabled: timelineEnabled,
                finalize: finalizeTimeline
            )
            committedTimelineState = candidateTimelineState
        }
        if var candidateBackgroundState = backgroundState {
            syncBackgroundActivity(state: &candidateBackgroundState, at: date, finalize: finalizeBackgroundActivity)
            committedBackgroundState = candidateBackgroundState
        }
        normalizeDuplicateTimelineRecords()
        normalizeDuplicateBackgroundRecords()

        do {
            try saveContext()
            if let committedTimelineState { self.timelineRuntime = committedTimelineState }
            if let committedBackgroundState { self.backgroundRuntime = committedBackgroundState }
            status = .ready
            lastCheckpointAt = date
            revision += 1
            return true
        } catch {
            // Candidate maps and progress are local to the tracker checkpoint,
            // so they are discarded here. Keep only the generated segment IDs:
            // they identify the same logical interval on the next retry, while
            // processed markers must remain uncommitted so the failed work is
            // retried. Roll back only the failed Core Data transaction.
            context.rollback()
            if let committedTimelineState {
                for (key, id) in committedTimelineState.appSegmentIDs {
                    timelineRuntime.appSegmentIDs[key] = id
                }
                for (key, id) in committedTimelineState.websiteSegmentIDs {
                    timelineRuntime.websiteSegmentIDs[key] = id
                }
            }
            if let committedBackgroundState {
                for (key, id) in committedBackgroundState.segmentIDs {
                    backgroundRuntime.segmentIDs[key] = id
                }
            }
            status = .degraded(error.localizedDescription)
            revision += 1
            return false
        }
    }

    private func syncTimeline(
        state: inout TimelineRuntimeState,
        foregroundTracker: ForegroundTracker,
        domainTracker: DomainTracker,
        at date: Date,
        enabled: Bool,
        finalize: Bool
    ) {
        guard enabled else { return }
        for interval in foregroundTracker.closedIntervals where !state.processedAppIntervalIDs.contains(interval.id.uuidString) {
            guard interval.app.bundleIdentifier != "com.apple.loginwindow" else { continue }
            let start = max(interval.start, state.anchorDate ?? interval.start)
            let sourceKey = state.activeApp == interval.app && state.activeAppStart == start
                ? "active|\(interval.app.bundleIdentifier)|\(start.timeIntervalSinceReferenceDate)"
                : "closed|\(interval.id.uuidString)"
            persistAppSegments(interval.app, start: start, end: interval.end, sourceKey: sourceKey, state: &state, isOpen: false)
            state.processedAppIntervalIDs.insert(interval.id.uuidString)
            if state.activeApp == interval.app { state.activeApp = nil; state.activeAppStart = nil }
        }
        if let active = foregroundTracker.currentApp,
           active.bundleIdentifier != "com.apple.loginwindow",
           let start = foregroundTracker.currentIntervalStart,
           date > start {
            let effectiveStart = max(start, state.anchorDate ?? start)
            state.activeApp = active
            state.activeAppStart = effectiveStart
            persistAppSegments(active, start: effectiveStart, end: date, sourceKey: "active|\(active.bundleIdentifier)|\(effectiveStart.timeIntervalSinceReferenceDate)", state: &state, isOpen: !finalize)
        }
        if finalize { state.activeApp = nil; state.activeAppStart = nil }

        for interval in domainTracker.domainIntervals where !state.processedWebsiteIntervalIDs.contains(interval.id.uuidString) {
            let start = max(interval.start, state.anchorDate ?? interval.start)
            let sourceKey = state.activeWebsiteDomain == interval.domain && state.activeWebsiteStart == start
                ? "active|\(interval.domain)|\(start.timeIntervalSinceReferenceDate)"
                : "closed|\(interval.id.uuidString)"
            persistWebsiteSegments(domain: interval.domain, start: start, end: interval.end, sourceKey: sourceKey, state: &state, isOpen: false)
            state.processedWebsiteIntervalIDs.insert(interval.id.uuidString)
            if state.activeWebsiteDomain == interval.domain { state.activeWebsiteDomain = nil; state.activeWebsiteStart = nil }
        }
        if let domain = domainTracker.currentDomain == "—" ? nil : domainTracker.currentDomain,
           let start = domainTracker.activeIntervalSnapshot(at: date)?.start,
           date > start {
            let effectiveStart = max(start, state.anchorDate ?? start)
            state.activeWebsiteDomain = domain
            state.activeWebsiteStart = effectiveStart
            persistWebsiteSegments(domain: domain, start: effectiveStart, end: date, sourceKey: "active|\(domain)|\(effectiveStart.timeIntervalSinceReferenceDate)", state: &state, isOpen: !finalize)
        }
        if finalize { state.activeWebsiteDomain = nil; state.activeWebsiteStart = nil }
    }

    private func syncBackgroundActivity(state: inout BackgroundRuntimeState, at date: Date, finalize: Bool) {
        if finalize {
            for active in state.openByDetector.values {
                state.closed.append(active.closed(at: date))
            }
            state.openByDetector.removeAll()
        }
        for activity in state.closed where !state.processedSourceIDs.contains(activity.sourceID) {
            persistBackgroundSegments(activity, state: &state, isOpen: false)
            state.processedSourceIDs.insert(activity.sourceID)
        }
        for activity in state.openByDetector.values {
            persistBackgroundSegments(activity, state: &state, isOpen: !finalize)
        }
    }

    private func persistBackgroundSegments(
        _ activity: BackgroundRuntimeActivity,
        state: inout BackgroundRuntimeState,
        isOpen: Bool
    ) {
        guard activity.end > activity.start else { return }
        for segment in TimelineIntervalNormalizer.split(start: activity.start, end: activity.end, calendar: calendar) {
            let key = "\(activity.sourceID)|\(segment.dateKey)"
            let id = state.segmentIDs[key] ?? UUID().uuidString
            state.segmentIDs[key] = id
            let record = fetchBackgroundInterval(id: id) ?? BackgroundActivityIntervalRecord(context: context)
            record.idString = id
            record.dateKey = segment.dateKey
            record.startAt = segment.start
            record.endAt = segment.end
            record.durationSeconds = segment.duration
            record.isOpen = isOpen && segment.end == activity.end
            record.bundleIdentifier = activity.app.bundleIdentifier
            record.displayName = activity.app.displayName
            record.activityKindRawValue = activity.activityKind.rawValue
            record.detectorIdentifier = activity.detectorIdentifier
        }
    }

    private func fetchBackgroundInterval(id: String) -> BackgroundActivityIntervalRecord? {
        let request = BackgroundActivityIntervalRecord.fetchRequest()
        request.predicate = NSPredicate(format: "idString == %@", id)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func backgroundInterval(from record: BackgroundActivityIntervalRecord, now: Date) -> BackgroundActivityInterval? {
        guard let kind = BackgroundActivityKind(rawValue: record.activityKindRawValue),
              let valid = TimelineIntervalNormalizer.validated(start: record.startAt, end: min(record.endAt, now)) else { return nil }
        return BackgroundActivityInterval(
            id: record.idString,
            dateKey: record.dateKey,
            start: valid.start,
            end: valid.end,
            duration: valid.duration,
            app: AppIdentity(bundleIdentifier: record.bundleIdentifier, displayName: record.displayName),
            activityKind: kind,
            detectorIdentifier: record.detectorIdentifier,
            isOpen: record.isOpen && record.endAt >= now
        )
    }

    private func normalizeDuplicateBackgroundRecords() {
        let records = (try? context.fetch(BackgroundActivityIntervalRecord.fetchRequest())) ?? []
        for duplicates in Dictionary(grouping: records, by: { "\($0.dateKey)|\($0.startAt.timeIntervalSinceReferenceDate)|\($0.endAt.timeIntervalSinceReferenceDate)|\($0.bundleIdentifier)|\($0.activityKindRawValue)|\($0.detectorIdentifier)" }).values where duplicates.count > 1 {
            let canonical = duplicates.sorted {
                if $0.durationSeconds != $1.durationSeconds { return $0.durationSeconds > $1.durationSeconds }
                return $0.idString < $1.idString
            }.first!
            duplicates.filter { $0 !== canonical }.forEach(context.delete)
        }
    }

    private func normalizeDuplicateTimelineRecords() {
        let apps = (try? context.fetch(AppUsageIntervalRecord.fetchRequest())) ?? []
        for records in Dictionary(grouping: apps, by: { "\($0.dateKey)|\($0.startAt.timeIntervalSinceReferenceDate)|\($0.endAt.timeIntervalSinceReferenceDate)|\($0.bundleIdentifier)" }).values where records.count > 1 {
            let canonical = records.first(where: { !$0.objectID.isTemporaryID }) ?? records[0]
            records.filter { $0 !== canonical }.forEach(context.delete)
        }
        let websites = (try? context.fetch(WebsiteUsageIntervalRecord.fetchRequest())) ?? []
        for records in Dictionary(grouping: websites, by: { "\($0.dateKey)|\($0.startAt.timeIntervalSinceReferenceDate)|\($0.endAt.timeIntervalSinceReferenceDate)|\($0.domain)" }).values where records.count > 1 {
            let canonical = records.first(where: { !$0.objectID.isTemporaryID }) ?? records[0]
            records.filter { $0 !== canonical }.forEach(context.delete)
        }
    }

    private func persistAppSegments(
        _ app: AppIdentity,
        start: Date,
        end: Date,
        sourceKey: String,
        state: inout TimelineRuntimeState,
        isOpen: Bool
    ) {
        for segment in TimelineIntervalNormalizer.split(start: start, end: end, calendar: calendar) {
            let key = "\(sourceKey)|\(segment.dateKey)"
            let id = state.appSegmentIDs[key] ?? UUID().uuidString
            state.appSegmentIDs[key] = id
            let record = fetchAppInterval(id: id) ?? AppUsageIntervalRecord(context: context)
            record.idString = id; record.dateKey = segment.dateKey
            record.startAt = segment.start; record.endAt = segment.end; record.durationSeconds = segment.duration
            record.isOpen = isOpen && segment.end == end
            record.bundleIdentifier = app.bundleIdentifier; record.displayName = app.displayName
        }
    }

    private func persistWebsiteSegments(
        domain: String,
        start: Date,
        end: Date,
        sourceKey: String,
        state: inout TimelineRuntimeState,
        isOpen: Bool
    ) {
        guard domain != "—", !domain.isEmpty else { return }
        for segment in TimelineIntervalNormalizer.split(start: start, end: end, calendar: calendar) {
            let key = "\(sourceKey)|\(segment.dateKey)"
            let id = state.websiteSegmentIDs[key] ?? UUID().uuidString
            state.websiteSegmentIDs[key] = id
            guard let parentID = nearestChromeAppIntervalID(start: segment.start, end: segment.end) else {
                continue
            }
            let record = fetchWebsiteInterval(id: id) ?? WebsiteUsageIntervalRecord(context: context)
            record.idString = id; record.dateKey = segment.dateKey
            record.startAt = segment.start; record.endAt = segment.end; record.durationSeconds = segment.duration
            record.isOpen = isOpen && segment.end == end
            record.browserBundleIdentifier = "com.google.Chrome"; record.domain = domain
            record.parentAppIntervalID = parentID
        }
    }

    private func rawSnapshot(
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

    private func combinedSnapshot(
        for dayKey: String,
        appDurations: [String: [AppIdentity: TimeInterval]],
        domainDurations: [String: [String: TimeInterval]]
    ) -> DailyUsageSnapshot {
        var result = rawSnapshot(
            for: dayKey,
            appDurations: appDurations,
            domainDurations: domainDurations
        )
        let chromeDuration = result.appUsageByApp
            .filter { $0.key.bundleIdentifier == "com.google.Chrome" }
            .values
            .reduce(0, +)
        result.websiteUsageByDomain = WebsiteUsageReconciliation.reconcile(
            websiteUsage: result.websiteUsageByDomain,
            chromeUsage: chromeDuration
        )
        return result
    }

    private func merge(_ snapshot: DailyUsageSnapshot, into result: inout HistoryUsageSnapshot) {
        for (app, duration) in snapshot.appUsageByApp {
            mergeAppDuration(app, duration: duration, into: &result.appUsageByApp)
        }
        for (domain, duration) in snapshot.websiteUsageByDomain {
            result.websiteUsageByDomain[domain, default: 0] += duration
        }
        result.typingMetrics = TypingMetrics(
            englishCharacters: result.typingMetrics.englishCharacters + snapshot.typingMetrics.englishCharacters,
            numberCharacters: result.typingMetrics.numberCharacters + snapshot.typingMetrics.numberCharacters,
            symbolCharacters: result.typingMetrics.symbolCharacters + snapshot.typingMetrics.symbolCharacters,
            spaceCharacters: result.typingMetrics.spaceCharacters + snapshot.typingMetrics.spaceCharacters
        )
        for (app, metrics) in snapshot.typingAppMetricsByApp {
            var existing = removeAppMetrics(for: app, from: &result.typingAppMetricsByApp)
            existing.adding(metrics)
            result.typingAppMetricsByApp[app] = existing
        }
        result.typingSessions += snapshot.typingSessions
        result.activeTypingDuration += snapshot.activeTypingDuration
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

private struct TimelineRuntimeState {
    var processedAppIntervalIDs: Set<String> = []
    var processedWebsiteIntervalIDs: Set<String> = []
    var appSegmentIDs: [String: String] = [:]
    var websiteSegmentIDs: [String: String] = [:]
    var activeApp: AppIdentity?
    var activeAppStart: Date?
    var activeWebsiteDomain: String?
    var activeWebsiteStart: Date?
    var anchorDate: Date?

    init(anchorDate: Date? = nil) {
        self.anchorDate = anchorDate
    }
}

private struct BackgroundRuntimeActivity {
    let sourceID: String
    let detectorIdentifier: String
    var app: AppIdentity
    let activityKind: BackgroundActivityKind
    let start: Date
    var end: Date

    func closed(at date: Date) -> Self {
        var result = self
        result.end = max(start, min(end, date))
        return result
    }
}

private struct BackgroundRuntimeState {
    var processedSourceIDs: Set<String> = []
    var segmentIDs: [String: String] = [:]
    var openByDetector: [String: BackgroundRuntimeActivity] = [:]
    var closed: [BackgroundRuntimeActivity] = []
    var anchorDate: Date?

    init(anchorDate: Date? = nil) {
        self.anchorDate = anchorDate
    }

    func liveIntervals(at now: Date, dateKey: String, calendar: Calendar) -> [BackgroundActivityInterval] {
        let openIntervals = openByDetector.values.flatMap { activity -> [BackgroundActivityInterval] in
            TimelineIntervalNormalizer.split(start: max(activity.start, anchorDate ?? activity.start), end: now, calendar: calendar)
                .filter { $0.dateKey == dateKey }
                .compactMap { segment in
                    let key = "\(activity.sourceID)|\(segment.dateKey)"
                    guard let id = segmentIDs[key] else { return nil }
                    return BackgroundActivityInterval(
                        id: id,
                        dateKey: segment.dateKey,
                        start: segment.start,
                        end: segment.end,
                        duration: segment.duration,
                        app: activity.app,
                        activityKind: activity.activityKind,
                        detectorIdentifier: activity.detectorIdentifier,
                        isOpen: segment.end == now
                    )
                }
        }
        let closedIntervals = closed.flatMap { activity -> [BackgroundActivityInterval] in
            TimelineIntervalNormalizer.split(start: max(activity.start, anchorDate ?? activity.start), end: min(activity.end, now), calendar: calendar)
                .filter { $0.dateKey == dateKey }
                .compactMap { segment in
                    let key = "\(activity.sourceID)|\(segment.dateKey)"
                    guard let id = segmentIDs[key] else { return nil }
                    return BackgroundActivityInterval(
                        id: id,
                        dateKey: segment.dateKey,
                        start: segment.start,
                        end: segment.end,
                        duration: segment.duration,
                        app: activity.app,
                        activityKind: activity.activityKind,
                        detectorIdentifier: activity.detectorIdentifier,
                        isOpen: false
                    )
                }
        }
        return closedIntervals + openIntervals
    }
}

enum DayTraceDateKey {
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

enum UsageStoreModel {
    // Reuse one model instance for the process. Core Data associates managed
    // subclasses with their model; constructing a separate model for every
    // in-memory test store makes class lookup ambiguous and emits duplicate
    // entity warnings.
    private static let shared = makeModel()

    static func make() -> NSManagedObjectModel {
        shared
    }

    static func makePreTimeline() -> NSManagedObjectModel {
        makeModel(includeTimeline: false, includeBackground: false)
    }

    static func makePreBackground() -> NSManagedObjectModel {
        makeModel(includeTimeline: true, includeBackground: false)
    }

    private static func makeModel(includeTimeline: Bool = true, includeBackground: Bool = true) -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        var entities = [
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
        if includeTimeline {
            entities += [
            entity(
                name: "AppUsageIntervalRecord",
                managedClassName: "AppUsageIntervalRecord",
                attributes: [
                    attribute("idString", .stringAttributeType),
                    attribute("dateKey", .stringAttributeType),
                    attribute("startAt", .dateAttributeType),
                    attribute("endAt", .dateAttributeType),
                    attribute("durationSeconds", .doubleAttributeType),
                    attribute("isOpen", .booleanAttributeType),
                    attribute("bundleIdentifier", .stringAttributeType),
                    attribute("displayName", .stringAttributeType)
                ],
                uniquenessConstraints: [["idString"]]
            ),
            entity(
                name: "WebsiteUsageIntervalRecord",
                managedClassName: "WebsiteUsageIntervalRecord",
                attributes: [
                    attribute("idString", .stringAttributeType),
                    attribute("dateKey", .stringAttributeType),
                    attribute("startAt", .dateAttributeType),
                    attribute("endAt", .dateAttributeType),
                    attribute("durationSeconds", .doubleAttributeType),
                    attribute("isOpen", .booleanAttributeType),
                    attribute("browserBundleIdentifier", .stringAttributeType),
                    attribute("domain", .stringAttributeType),
                    attribute("parentAppIntervalID", .stringAttributeType, optional: true)
                ],
                uniquenessConstraints: [["idString"]]
            )
            ]
        }
        if includeBackground {
            entities += [
                entity(
                    name: "BackgroundActivityIntervalRecord",
                    managedClassName: "BackgroundActivityIntervalRecord",
                    attributes: [
                        attribute("idString", .stringAttributeType),
                        attribute("dateKey", .stringAttributeType),
                        attribute("startAt", .dateAttributeType),
                        attribute("endAt", .dateAttributeType),
                        attribute("durationSeconds", .doubleAttributeType),
                        attribute("isOpen", .booleanAttributeType),
                        attribute("bundleIdentifier", .stringAttributeType),
                        attribute("displayName", .stringAttributeType),
                        attribute("activityKindRawValue", .stringAttributeType),
                        attribute("detectorIdentifier", .stringAttributeType)
                    ],
                    uniquenessConstraints: [["idString"]]
                )
            ]
        }
        model.entities = entities
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
        defaultValue: Any? = nil,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
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
