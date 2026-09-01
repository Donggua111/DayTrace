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
    private var cancellables: Set<AnyCancellable> = []
    private var checkpointTimer: Timer?
    private var lifecycleObserver: NSObjectProtocol?
    private var terminationStarted = false

    init(usageStore: UsageStore? = nil) {
        let store = usageStore ?? UsageStore()
        let tracker = ForegroundTracker()
        let domains = DomainTracker(foregroundTracker: tracker)
        foregroundTracker = tracker
        domainTracker = domains
        typingCounter = TypingCounter(appProvider: { [weak tracker] in tracker?.currentApp })
        self.usageStore = store
        socketBridge = UnixSocketBridge(messageHandler: { domain in
            Task { @MainActor in
                domains.receive(domain: domain)
                store.checkpoint(foregroundTracker: tracker, domainTracker: domains)
            }
        })

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
        [tracker.objectWillChange, typingCounter.objectWillChange, domains.objectWillChange, socketBridge.objectWillChange, store.objectWillChange]
            .forEach { publisher in
                publisher.sink { [weak self] _ in self?.objectWillChange.send() }
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
        usageStore.liveSnapshot(at: date, foregroundTracker: foregroundTracker, domainTracker: domainTracker).totalUsage
    }

    func appUsage(for app: AppIdentity, at date: Date = Date()) -> TimeInterval {
        usageStore.liveSnapshot(at: date, foregroundTracker: foregroundTracker, domainTracker: domainTracker)
            .appUsageByApp[app, default: 0]
    }

    func appIdentities(at date: Date = Date()) -> [AppIdentity] {
        var apps = Set(usageStore.liveSnapshot(at: date, foregroundTracker: foregroundTracker, domainTracker: domainTracker).appUsageByApp.keys)
        if let currentApp = foregroundTracker.currentApp {
            apps.insert(currentApp)
        }
        return Array(apps)
    }

    func websiteUsage(for domain: String, at date: Date = Date()) -> TimeInterval {
        usageStore.liveSnapshot(at: date, foregroundTracker: foregroundTracker, domainTracker: domainTracker)
            .websiteUsageByDomain[domain, default: 0]
    }

    func websiteDomains(at date: Date = Date()) -> [String] {
        var domains = Set(usageStore.liveSnapshot(at: date, foregroundTracker: foregroundTracker, domainTracker: domainTracker).websiteUsageByDomain.keys)
        if domainTracker.currentDomain != "—" {
            domains.insert(domainTracker.currentDomain)
        }
        return Array(domains)
    }

    func typingActivity(at date: Date = Date()) -> TypingActivitySnapshot {
        let snapshot = usageStore.liveSnapshot(at: date, foregroundTracker: foregroundTracker, domainTracker: domainTracker)
        return TypingActivitySnapshot(
            metrics: snapshot.typingMetrics,
            appMetricsByApp: snapshot.typingAppMetricsByApp,
            typingSessions: snapshot.typingSessions,
            activeTypingDuration: snapshot.activeTypingDuration
        )
    }

    func checkpoint(at date: Date = Date()) {
        usageStore.checkpoint(foregroundTracker: foregroundTracker, domainTracker: domainTracker, at: date)
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
