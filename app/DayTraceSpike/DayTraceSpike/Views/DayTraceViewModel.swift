import Combine
import Foundation
import AppKit

@MainActor
final class DayTraceViewModel: ObservableObject {
    let foregroundTracker: ForegroundTracker
    let typingCounter: TypingCounter
    let domainTracker: DomainTracker
    let backgroundActivity: BackgroundActivityCoordinator
    let socketBridge: UnixSocketBridge
    let usageStore: UsageStore
    let backupManager: BackupManager
    let metadataStore: MetadataStore
    let launchAtLogin: LaunchAtLoginController
    private var cancellables: Set<AnyCancellable> = []
    private var checkpointTimer: Timer?
    private var lifecycleObserver: NSObjectProtocol?
    private var terminationStarted = false
    private var cachedSnapshotDate: Date?
    private var cachedSnapshot: DailyUsageSnapshot?
    @Published private(set) var timelineEnabled: Bool

    static let timelineEnabledKey = "daytrace.timeline.enabled"

    init(usageStore: UsageStore? = nil) {
        let store = usageStore ?? UsageStore()
        let tracker = ForegroundTracker()
        let domains = DomainTracker(foregroundTracker: tracker)
        foregroundTracker = tracker
        domainTracker = domains
        let background = BackgroundActivityCoordinator(usageStore: store, foregroundTracker: tracker)
        backgroundActivity = background
        typingCounter = TypingCounter(appProvider: { [weak tracker] in tracker?.currentApp })
        self.usageStore = store
        backupManager = BackupManager()
        metadataStore = MetadataStore()
        launchAtLogin = LaunchAtLoginController()
        timelineEnabled = UserDefaults.standard.object(forKey: Self.timelineEnabledKey) as? Bool ?? true
        let socket = UnixSocketBridge(messageHandler: { domain in
            Task { @MainActor in
                domains.receive(domain: domain)
            store.checkpoint(
                foregroundTracker: tracker,
                domainTracker: domains,
                backgroundObservations: background.detectorSnapshots,
                backgroundActivityEnabled: background.backgroundActivityEnabled,
                enabledBackgroundDetectorIdentifiers: background.enabledDetectorIdentifiers
            )
            }
        })
        socket.onStatusChanged = { status in
            guard status == .waiting || status == .notConfigured || status == .error else { return }
            domains.connectionDidClose()
        }
        socketBridge = socket

        tracker.onTransition = { app, date in
            domains.foregroundChanged(to: app, at: date)
            background.refresh(at: date)
            store.checkpoint(
                foregroundTracker: tracker,
                domainTracker: domains,
                at: date,
                backgroundObservations: background.detectorSnapshots,
                backgroundActivityEnabled: background.backgroundActivityEnabled,
                enabledBackgroundDetectorIdentifiers: background.enabledDetectorIdentifiers
            )
        }
        tracker.onCalendarChange = { date in
            // The transition callback checkpoints with the previous calendar
            // before UsageStore refreshes its local calendar.
            store.calendarDidChange(at: date)
        }
        typingCounter.onAggregateRecorded = { category, app, date in
            store.recordTyping(category: category, app: app, at: date)
        }
            [tracker.objectWillChange, typingCounter.objectWillChange, domains.objectWillChange, backgroundActivity.objectWillChange, socket.objectWillChange, store.objectWillChange, launchAtLogin.objectWillChange, metadataStore.objectWillChange]
            .forEach { publisher in
                publisher.sink { [weak self] _ in
                    self?.cachedSnapshotDate = nil
                    self?.cachedSnapshot = nil
                    self?.objectWillChange.send()
                }
                    .store(in: &cancellables)
            }

        checkpointTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkpoint() }
        }
        lifecycleObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.terminate() }
        }
        typingCounter.start()
        socketBridge.start()
        backgroundActivity.start()
    }

    deinit {
        checkpointTimer?.invalidate()
        if let lifecycleObserver {
            NotificationCenter.default.removeObserver(lifecycleObserver)
        }
    }

    func totalUsage(at date: Date = Date()) -> TimeInterval {
        liveSnapshot(at: date).totalUsage
    }

    func appUsage(for app: AppIdentity, at date: Date = Date()) -> TimeInterval {
        liveSnapshot(at: date).appUsageByApp[app, default: 0]
    }

    func appIdentities(at date: Date = Date()) -> [AppIdentity] {
        var apps = Set(liveSnapshot(at: date).appUsageByApp.keys)
        if let currentApp = foregroundTracker.currentApp {
            apps.insert(currentApp)
        }
        return Array(apps)
    }

    func websiteUsage(for domain: String, at date: Date = Date()) -> TimeInterval {
        liveSnapshot(at: date).websiteUsageByDomain[domain, default: 0]
    }

    func websiteDomains(at date: Date = Date()) -> [String] {
        var domains = Set(liveSnapshot(at: date).websiteUsageByDomain.keys)
        if domainTracker.currentDomain != "—" {
            domains.insert(domainTracker.currentDomain)
        }
        return Array(domains)
    }

    func typingActivity(at date: Date = Date()) -> TypingActivitySnapshot {
        let snapshot = liveSnapshot(at: date)
        return TypingActivitySnapshot(
            metrics: snapshot.typingMetrics,
            appMetricsByApp: snapshot.typingAppMetricsByApp,
            typingSessions: snapshot.typingSessions,
            activeTypingDuration: snapshot.activeTypingDuration
        )
    }

    @discardableResult
    func checkpoint(at date: Date = Date(), allowAutomaticBackup: Bool = true, finalizeTimeline: Bool = false) -> Bool {
        let didPersist = usageStore.checkpoint(
            foregroundTracker: foregroundTracker,
            domainTracker: domainTracker,
            at: date,
            timelineEnabled: timelineEnabled,
            finalizeTimeline: finalizeTimeline,
            backgroundObservations: backgroundActivity.detectorSnapshots,
            backgroundActivityEnabled: backgroundActivity.backgroundActivityEnabled,
            enabledBackgroundDetectorIdentifiers: backgroundActivity.enabledDetectorIdentifiers,
            finalizeBackgroundActivity: finalizeTimeline
        )
        guard didPersist else { return false }
        if allowAutomaticBackup, backupManager.isEnabled {
            let calendar = Calendar.autoupdatingCurrent
            let shouldBackup = AutomaticBackupPolicy.shouldCreateBackup(
                lastBackupAt: backupManager.lastBackupAt,
                at: date,
                calendar: calendar
            )
            if shouldBackup { _ = backupManager.createBackup(using: usageStore) }
        }
        return true
    }

    func history(for range: HistoryRange, at date: Date = Date()) -> HistoryUsageSnapshot {
        usageStore.historySnapshot(
            for: range,
            at: date,
            foregroundTracker: foregroundTracker,
            domainTracker: domainTracker
        )
    }

    func comparison(for range: HistoryRange, at date: Date = Date()) -> UsagePeriodComparison {
        let calendar = Calendar.autoupdatingCurrent
        let previousDate = UsageComparisonPeriod.referenceDate(
            for: range,
            date: date,
            calendar: calendar
        )
        return UsagePeriodComparison(
            current: history(for: range, at: date),
            previous: history(for: range, at: previousDate)
        )
    }

    func createBackup() -> URL? {
        // "Back Up Now" includes the current in-memory interval and typing
        // aggregates. Automatic backup is suppressed here so one explicit
        // action cannot create a second backup through the checkpoint path.
        guard checkpoint(allowAutomaticBackup: false) else { return nil }
        return backupManager.createBackup(using: usageStore)
    }

    @discardableResult
    func restoreBackup(from data: Data) -> RestoreResult {
        // Close live writers before replacing persisted objects. The normal
        // backup is the safety copy for this destructive replace operation.
        guard checkpoint(allowAutomaticBackup: false, finalizeTimeline: true) else {
            return .failed("Unable to checkpoint current activity")
        }
        guard backupManager.createBackup(using: usageStore) != nil else {
            return .failed("Unable to create restore safety backup")
        }
        backgroundActivity.stop()
        let result = usageStore.restore(from: data)
        if case .restored = result {
            typingCounter.resetMetrics()
            foregroundTracker.resetRuntimeState()
            domainTracker.resetRuntimeState()
            backgroundActivity.start()
            foregroundTracker.refreshNow()
            backgroundActivity.refresh()
        } else {
            backgroundActivity.start()
        }
        return result
    }

    func integrityReport() -> IntegrityReport {
        usageStore.integrityReport()
    }

    @discardableResult
    func repairIntegrity() -> Int {
        let repaired = usageStore.repairIntegrity()
        if repaired > 0 { objectWillChange.send() }
        return repaired
    }

    @discardableResult
    func deleteActivity(from start: Date, through end: Date, datasets: Set<ActivityDataset>) -> Bool {
        guard checkpoint(allowAutomaticBackup: false, finalizeTimeline: true) else { return false }
        let didDelete = usageStore.deleteActivity(from: start, through: end, datasets: datasets)
        if didDelete {
            foregroundTracker.resetRuntimeState()
            domainTracker.resetRuntimeState()
            backgroundActivity.refresh()
            foregroundTracker.refreshNow()
        }
        return didDelete
    }

    func diagnosticReportData() -> Data? {
        let timeline = usageStore.timelineStatistics(enabled: timelineEnabled)
        let background = usageStore.backgroundDataStatistics()
        let report: [String: Any] = [
            "diagnosticReportVersion": 1,
            "dayTraceVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
            "architecture": "arm64",
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "com.daytrace.spike",
            "inputMonitoring": [
                "status": typingCounter.permissionStatus.rawValue,
                "cgPreflight": typingCounter.cgPreflightListenAccess,
                "eventTapEnabled": typingCounter.eventTapEnabled
            ],
            "tracking": [
                "running": foregroundTracker.isTracking,
                "systemState": foregroundTracker.systemState.rawValue
            ],
            "chrome": [
                "ipcStatus": socketBridge.status.rawValue,
                "nativeHost": "com.daytrace.spike"
            ],
            "persistence": [
                "status": String(describing: usageStore.status),
                "timelineEnabled": timeline.enabled,
                "appIntervalCount": timeline.appIntervalCount,
                "websiteIntervalCount": timeline.websiteIntervalCount,
                "backgroundIntervalCount": background.intervalCount
            ],
            "backup": [
                "automaticEnabled": backupManager.isEnabled,
                "backupVersion": 3
            ]
        ]
        return try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    }

    func exportAggregatesJSON(includeDetailedTimeline: Bool = false) -> Data? {
        checkpoint()
        return usageStore.exportAggregatesJSON(includeDetailedTimeline: includeDetailedTimeline)
    }

    func timeline(for date: Date, now: Date = Date()) -> DailyTimelineSnapshot {
        usageStore.timeline(for: date, now: now)
    }

    func dailyAppTrend(for app: AppIdentity, range: HistoryRange, at date: Date = Date()) -> [HistoryDay] {
        usageStore.dailyAppTrend(for: app, from: range.startDate(at: date, calendar: .autoupdatingCurrent), through: date)
    }

    func dailyWebsiteTrend(for domain: String, range: HistoryRange, at date: Date = Date()) -> [HistoryDay] {
        usageStore.dailyWebsiteTrend(for: domain, from: range.startDate(at: date, calendar: .autoupdatingCurrent), through: date)
    }

    func backgroundSummary(for date: Date = Date(), now: Date = Date()) -> BackgroundActivitySummary {
        usageStore.backgroundSummary(for: date, now: now)
    }

    func backgroundStatistics() -> BackgroundDataStatistics {
        usageStore.backgroundDataStatistics()
    }

    @discardableResult
    func setBackgroundActivityEnabled(_ enabled: Bool) -> Bool {
        backgroundActivity.setBackgroundActivityEnabled(enabled)
        _ = checkpoint(allowAutomaticBackup: false)
        return true
    }

    func setBackgroundDetectorEnabled(_ enabled: Bool, identifier: String) {
        backgroundActivity.setDetectorEnabled(enabled, identifier: identifier)
        _ = checkpoint(allowAutomaticBackup: false)
    }

    @discardableResult
    func deleteBackgroundActivityHistory() -> Bool {
        backgroundActivity.stop()
        let result = usageStore.deleteBackgroundActivityHistory()
        if result { backgroundActivity.start() }
        return result
    }

    func timelineStatistics() -> TimelineDataStatistics {
        usageStore.timelineStatistics(enabled: timelineEnabled)
    }

    @discardableResult
    func setTimelineEnabled(_ enabled: Bool) -> Bool {
        guard enabled != timelineEnabled else { return true }
        let now = Date()
        if enabled {
            guard usageStore.setTimelineEnabled(true, at: now) else { return false }
        } else {
            guard checkpoint(at: now, allowAutomaticBackup: false), usageStore.setTimelineEnabled(false, at: now) else { return false }
        }
        timelineEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.timelineEnabledKey)
        return true
    }

    @discardableResult
    func deleteTimelineHistory() -> Bool {
        usageStore.deleteTimelineHistory()
    }

    @discardableResult
    func deleteAllData() -> Bool {
        guard usageStore.deleteAllData() else { return false }
        let now = Date()
        foregroundTracker.resetRuntimeState(at: now)
        domainTracker.resetRuntimeState(at: now)
        typingCounter.resetMetrics()
        backgroundActivity.start()
        cachedSnapshotDate = nil
        cachedSnapshot = nil
        return true
    }

    private func liveSnapshot(at date: Date) -> DailyUsageSnapshot {
        if cachedSnapshotDate == date, let cachedSnapshot {
            return cachedSnapshot
        }
        let snapshot = usageStore.liveSnapshot(
            at: date,
            foregroundTracker: foregroundTracker,
            domainTracker: domainTracker
        )
        cachedSnapshotDate = date
        cachedSnapshot = snapshot
        return snapshot
    }

    private func terminate() {
        guard !terminationStarted else { return }
        terminationStarted = true
        checkpointTimer?.invalidate()

        // Quiesce input first. TypingCounter keeps its accepted aggregate in
        // memory, while queued callbacks after this point are discarded.
        typingCounter.quiesce()
        backgroundActivity.stop()

        // Persist the final foreground/domain snapshot before tearing down
        // the socket. Event Tap cleanup is bounded and continues on its own
        // run loop; termination is never blocked waiting for it.
        checkpoint(finalizeTimeline: true)
        socketBridge.stop()
    }
}
