import AppKit
import Combine
import Foundation

@MainActor
final class ForegroundTracker: ObservableObject {
    @Published private(set) var currentApp: AppIdentity?
    @Published private(set) var currentIntervalStart: Date?
    @Published private(set) var closedIntervals: [ForegroundInterval] = []
    @Published private(set) var foregroundAggregateByApp: [AppIdentity: TimeInterval] = [:]
    @Published private(set) var lastForegroundEventAt: Date?
    @Published private(set) var systemState: TrackingSystemState = .awake
    @Published private(set) var isTracking = true

    var onTransition: ((AppIdentity?, Date) -> Void)?
    var onCalendarChange: ((Date) -> Void)?

    private var activeStartDate: Date?
    private var activeStartUptime: TimeInterval?
    private var sessionIsActive = true
    private var activeObserverTokens: [NSObjectProtocol] = []
    private var distributedObserverTokens: [NSObjectProtocol] = []
    private let processRuntimeID = UUID()

    init() {
        observeSystemEvents()
        refreshFrontmostApplication(at: Date())
    }

    deinit {
        activeObserverTokens.forEach(NotificationCenter.default.removeObserver)
        distributedObserverTokens.forEach(DistributedNotificationCenter.default().removeObserver)
    }

    func pause() {
        guard isTracking else { return }
        isTracking = false
        closeActiveInterval(at: Date())
        systemState = .paused
        onTransition?(nil, Date())
    }

    func resume() {
        guard !isTracking else { return }
        isTracking = true
        systemState = .awake
        refreshFrontmostApplication(at: Date())
    }

    func currentElapsed(at date: Date = Date()) -> TimeInterval {
        guard let start = activeStartDate else { return 0 }
        return max(0, date.timeIntervalSince(start))
    }

    func aggregate(for app: AppIdentity, at date: Date = Date()) -> TimeInterval {
        let closed = foregroundAggregateByApp[app, default: 0]
        let active = currentApp == app ? currentElapsed(at: date) : 0
        return closed + active
    }

    func totalUsage(at date: Date = Date()) -> TimeInterval {
        foregroundAggregateByApp.values.reduce(0, +) + currentElapsed(at: date)
    }

    func activeIntervalSnapshot(at date: Date = Date()) -> ForegroundInterval? {
        guard let currentApp, let currentIntervalStart else { return nil }
        return ForegroundInterval(
            id: UUID(),
            app: currentApp,
            start: currentIntervalStart,
            end: date,
            duration: currentElapsed(at: date)
        )
    }

    func refreshNow() {
        refreshFrontmostApplication(at: Date())
    }

    private func observeSystemEvents() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        activeObserverTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor [weak self] in
                self?.refresh(application: application, at: Date())
            }
        })

        activeObserverTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.suspend(for: .sleeping) }
        })

        activeObserverTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.resumeFromSystemEvent(state: .awake) }
        })

        activeObserverTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sessionIsActive = false
                self?.suspend(for: .locked)
            }
        })

        activeObserverTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sessionIsActive = true
                self?.resumeFromSystemEvent(state: .awake)
            }
        })

        for name in [
            Notification.Name.NSSystemTimeZoneDidChange,
            Notification.Name.NSCalendarDayChanged,
            Notification.Name.NSSystemClockDidChange
        ] {
            activeObserverTokens.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleCalendarChange(at: Date())
                }
            })
        }

        let distributed = DistributedNotificationCenter.default()
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsLockedNotification"] {
            distributedObserverTokens.append(distributed.addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.sessionIsActive = false
                    self?.suspend(for: .locked)
                }
            })
        }

        for name in ["com.apple.screenIsUnlocked", "com.apple.screenIsUnlockedNotification"] {
            distributedObserverTokens.append(distributed.addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.sessionIsActive = true
                    self?.resumeFromSystemEvent(state: .awake)
                }
            })
        }
    }

    private func refreshFrontmostApplication(at date: Date) {
        refresh(application: NSWorkspace.shared.frontmostApplication, at: date)
    }

    private func refresh(application: NSRunningApplication?, at date: Date) {
        guard isTracking, systemState == .awake else { return }
        lastForegroundEventAt = date
        guard let application, !application.isTerminated else {
            closeActiveInterval(at: date)
            currentApp = nil
            onTransition?(nil, date)
            return
        }

        let identity = AppIdentity(
            bundleIdentifier: application.bundleIdentifier
                ?? Self.processScopedFallbackIdentifier(
                    processIdentifier: application.processIdentifier,
                    runtimeID: processRuntimeID
                ),
            displayName: application.localizedName ?? application.bundleIdentifier ?? "Unknown"
        )

        refresh(identity: identity, at: date)
    }

    /// A missing-bundle process is stable for this tracker runtime, but the
    /// runtime token prevents a later app launch from merging solely because
    /// macOS reused the same PID.
    static func processScopedFallbackIdentifier(processIdentifier: Int32, runtimeID: UUID) -> String {
        "unknown-process-\(runtimeID.uuidString)-pid-\(processIdentifier)"
    }

    private func refresh(identity: AppIdentity?, at date: Date) {
        guard isTracking, systemState == .awake else { return }
        lastForegroundEventAt = date
        guard let identity else {
            closeActiveInterval(at: date)
            currentApp = nil
            onTransition?(nil, date)
            return
        }

        // Session state is the authoritative lock/login-window guard. This
        // secondary filter prevents loginwindow from entering normal app
        // aggregates if it is reported during authentication transitions.
        if identity.bundleIdentifier == "com.apple.loginwindow"
            || identity.displayName.caseInsensitiveCompare("loginwindow") == .orderedSame {
            closeActiveInterval(at: date)
            currentApp = nil
            onTransition?(nil, date)
            return
        }

        if let currentApp, currentApp.bundleIdentifier == identity.bundleIdentifier {
            if currentApp.displayName != identity.displayName {
                self.currentApp = identity
            }
            return
        }
        closeActiveInterval(at: date)
        currentApp = identity
        activeStartDate = date
        activeStartUptime = ProcessInfo.processInfo.systemUptime
        currentIntervalStart = date
        onTransition?(identity, date)
    }

    private func suspend(for state: TrackingSystemState, at date: Date = Date()) {
        guard isTracking else { return }
        closeActiveInterval(at: date)
        systemState = state
        currentApp = nil
        onTransition?(nil, date)
    }

    private func resumeFromSystemEvent(
        state: TrackingSystemState,
        at date: Date = Date(),
        frontmostApp: AppIdentity? = nil
    ) {
        guard isTracking else { return }

        // Waking the machine does not prove that the interactive session has
        // been unlocked. Keep the usage gate closed until an unlock/session
        // active signal arrives.
        if state == .awake, !sessionIsActive {
            systemState = .locked
            currentApp = nil
            currentIntervalStart = nil
            return
        }

        systemState = state
        if let frontmostApp {
            refresh(identity: frontmostApp, at: date)
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshFrontmostApplication(at: Date())
        }
    }

    private func handleCalendarChange(at date: Date) {
        guard isTracking else {
            onCalendarChange?(date)
            return
        }

        closeActiveInterval(at: date)
        currentApp = nil
        currentIntervalStart = nil
        onTransition?(nil, date)
        onCalendarChange?(date)

        guard systemState == .awake, sessionIsActive else { return }
        refreshFrontmostApplication(at: date)
    }

    enum TestSystemEvent {
        case lock
        case sleep
        case wake
        case unlock
    }

    // This seam exercises the same state transitions used by the real
    // workspace/session notifications without requiring a real lock screen.
    func handleSystemEventForTesting(
        _ event: TestSystemEvent,
        at date: Date,
        frontmostApp: AppIdentity? = nil
    ) {
        switch event {
        case .lock:
            sessionIsActive = false
            suspend(for: .locked, at: date)
        case .sleep:
            suspend(for: .sleeping, at: date)
        case .wake:
            resumeFromSystemEvent(state: .awake, at: date, frontmostApp: frontmostApp)
        case .unlock:
            sessionIsActive = true
            resumeFromSystemEvent(state: .awake, at: date, frontmostApp: frontmostApp)
        }
    }

    func calendarDidChangeForTesting(at date: Date) {
        handleCalendarChange(at: date)
    }

    func appendClosedIntervalForTesting(_ interval: ForegroundInterval) {
        closedIntervals.append(interval)
    }

    private func closeActiveInterval(at date: Date) {
        guard let app = currentApp, let start = activeStartDate, let startUptime = activeStartUptime else {
            activeStartDate = nil
            activeStartUptime = nil
            currentIntervalStart = nil
            return
        }

        let uptimeDuration = max(0, ProcessInfo.processInfo.systemUptime - startUptime)
        let wallDuration = max(0, date.timeIntervalSince(start))
        let duration = min(uptimeDuration, wallDuration + 0.25)
        closedIntervals.append(ForegroundInterval(id: UUID(), app: app, start: start, end: date, duration: duration))
        foregroundAggregateByApp[app, default: 0] += duration
        activeStartDate = nil
        activeStartUptime = nil
        currentIntervalStart = nil
    }
}
