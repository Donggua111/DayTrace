import Combine
import Foundation
import AppKit

@MainActor
final class DayTraceViewModel: ObservableObject {
    let foregroundTracker: ForegroundTracker
    let typingCounter: TypingCounter
    let domainTracker: DomainTracker
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

    init(usageStore: UsageStore? = nil) {
        let store = usageStore ?? UsageStore()
        let tracker = ForegroundTracker()
        let domains = DomainTracker(foregroundTracker: tracker)
        foregroundTracker = tracker
        domainTracker = domains
        typingCounter = TypingCounter(appProvider: { [weak tracker] in tracker?.currentApp })
        self.usageStore = store
        backupManager = BackupManager()
        metadataStore = MetadataStore()
        launchAtLogin = LaunchAtLoginController()
        let socket = UnixSocketBridge(messageHandler: { domain in
            Task { @MainActor in
                domains.receive(domain: domain)
                store.checkpoint(foregroundTracker: tracker, domainTracker: domains)
            }
        })
        socket.onStatusChanged = { status in
            guard status == .waiting || status == .notConfigured || status == .error else { return }
            domains.connectionDidClose()
        }
        socketBridge = socket

        tracker.onTransition = { app, date in
            domains.foregroundChanged(to: app, at: date)
            store.checkpoint(foregroundTracker: tracker, domainTracker: domains, at: date)
        }
        tracker.onCalendarChange = { date in
            // The transition callback checkpoints with the previous calendar
            // before UsageStore refreshes its local calendar.
            store.calendarDidChange(at: date)
        }
        typingCounter.onAggregateRecorded = { category, app, date in
            store.recordTyping(category: category, app: app, at: date)
        }
        [tracker.objectWillChange, typingCounter.objectWillChange, domains.objectWillChange, socket.objectWillChange, store.objectWillChange, launchAtLogin.objectWillChange, metadataStore.objectWillChange]
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
    func checkpoint(at date: Date = Date(), allowAutomaticBackup: Bool = true) -> Bool {
        let didPersist = usageStore.checkpoint(
            foregroundTracker: foregroundTracker,
            domainTracker: domainTracker,
            at: date
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

    func exportAggregatesJSON() -> Data? {
        checkpoint()
        return usageStore.exportAggregatesJSON()
    }

    @discardableResult
    func deleteAllData() -> Bool {
        guard usageStore.deleteAllData() else { return false }
        let now = Date()
        foregroundTracker.resetRuntimeState(at: now)
        domainTracker.resetRuntimeState(at: now)
        typingCounter.resetMetrics()
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

        // Persist the final foreground/domain snapshot before tearing down
        // the socket. Event Tap cleanup is bounded and continues on its own
        // run loop; termination is never blocked waiting for it.
        checkpoint()
        socketBridge.stop()
    }
}
