import AppKit
import Combine
import CoreGraphics
import Foundation
import IOKit.hidsystem

struct TypingMetrics: Equatable {
    private(set) var englishCharacters = 0
    private(set) var numberCharacters = 0
    private(set) var symbolCharacters = 0
    private(set) var spaceCharacters = 0

    init(
        englishCharacters: Int = 0,
        numberCharacters: Int = 0,
        symbolCharacters: Int = 0,
        spaceCharacters: Int = 0
    ) {
        self.englishCharacters = englishCharacters
        self.numberCharacters = numberCharacters
        self.symbolCharacters = symbolCharacters
        self.spaceCharacters = spaceCharacters
    }

    var typedCharacters: Int {
        englishCharacters + numberCharacters + symbolCharacters + spaceCharacters
    }

    var estimatedEnglishWords: Int {
        Int((Double(englishCharacters) / 5.0).rounded())
    }

    mutating func record(_ category: TypingCategory) {
        switch category {
        case .english:
            englishCharacters += 1
        case .number:
            numberCharacters += 1
        case .symbol:
            symbolCharacters += 1
        case .space:
            spaceCharacters += 1
        case .ignored:
            break
        }
    }
}

struct AppTypingMetrics: Equatable {
    private(set) var englishCharacters = 0
    private(set) var numberCharacters = 0
    private(set) var symbolCharacters = 0
    private(set) var spaceCharacters = 0

    init(
        englishCharacters: Int = 0,
        numberCharacters: Int = 0,
        symbolCharacters: Int = 0,
        spaceCharacters: Int = 0
    ) {
        self.englishCharacters = englishCharacters
        self.numberCharacters = numberCharacters
        self.symbolCharacters = symbolCharacters
        self.spaceCharacters = spaceCharacters
    }

    var typedCharacters: Int {
        englishCharacters + numberCharacters + symbolCharacters + spaceCharacters
    }

    mutating func record(_ category: TypingCategory) {
        switch category {
        case .english:
            englishCharacters += 1
        case .number:
            numberCharacters += 1
        case .symbol:
            symbolCharacters += 1
        case .space:
            spaceCharacters += 1
        case .ignored:
            break
        }
    }
}

final class TypingCounter: ObservableObject {
    static let typingSessionTimeout: TimeInterval = 300
    static let activeIntervalCap: TimeInterval = 5

    @Published private(set) var metrics = TypingMetrics()
    @Published private(set) var appMetricsByApp: [AppIdentity: AppTypingMetrics] = [:]
    @Published private(set) var typingSessions = 0
    @Published private(set) var activeTypingDuration: TimeInterval = 0
    @Published private(set) var permissionStatus: InputMonitoringStatus
    @Published private(set) var cgPreflightListenAccess = false
    @Published private(set) var iohidListenAccess: InputMonitoringDiagnosticStatus
    @Published private(set) var eventTapStatus = "Not started"
    @Published private(set) var eventTapEnabled = false
    @Published private(set) var lastTypingEventAt: Date?

    /// Aggregate-only callback used by the persistence boundary. It carries
    /// no key, Unicode, or event payload.
    var onAggregateRecorded: ((TypingCategory, AppIdentity?, Date) -> Void)?

    private let eventQueue = DispatchQueue(label: "com.daytrace.spike.typing-event-tap", qos: .utility)
    // Event-tap and run-loop objects are owned by eventQueue. This lock only
    // protects lifecycle coordination that must be read by stop() from the
    // caller's thread.
    private let lifecycleLock = NSLock()
    private var lifecycle = EventTapLifecycleModel()
    private var eventTapRunLoop: CFRunLoop?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var applicationActivationObserver: NSObjectProtocol?
    private let appProvider: () -> AppIdentity?
    private var lastValidTypingEventTime: Date?
    private var acceptsEvents = true

    // Temporary compatibility properties for the pre-Task 2 Dashboard.
    // They are computed from the new aggregate source of truth.
    var total: Int { metrics.typedCharacters }
    var countsByApp: [AppIdentity: Int] {
        appMetricsByApp.mapValues(\.typedCharacters)
    }
    var typedCharacters: Int { metrics.typedCharacters }
    var estimatedEnglishWords: Int { metrics.estimatedEnglishWords }
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

    init(appProvider: @escaping () -> AppIdentity?) {
        self.appProvider = appProvider
        permissionStatus = .notRequested
        iohidListenAccess = .unknown
        refreshPermissionDiagnostics()
        applicationActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAfterApplicationActivation()
        }
    }

    deinit {
        if let applicationActivationObserver {
            NotificationCenter.default.removeObserver(applicationActivationObserver)
        }
        stop()
    }

    func requestPermission() {
        permissionStatus = .requesting
        eventTapStatus = "Waiting for Input Monitoring authorization"

        // Let SwiftUI render the observable waiting state before macOS presents
        // (or suppresses) the system authorization UI.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            self.refreshPermissionDiagnostics()
            guard self.cgPreflightListenAccess else {
                self.permissionStatus = .systemSettingsRequired
                self.eventTapStatus = "Input Monitoring permission required in System Settings"
                self.eventTapEnabled = false
                return
            }

            self.permissionStatus = .requesting
            self.eventTapStatus = "Creating listen-only event tap"
            self.startEventTap()
        }
    }

    func start() {
        acceptsEvents = true
        refreshPermissionDiagnostics()
        guard cgPreflightListenAccess else {
            permissionStatus = permissionStatus == .notRequested ? .notRequested : .systemSettingsRequired
            eventTapStatus = permissionStatus == .notRequested
                ? "Input Monitoring authorization not requested"
                : "Input Monitoring permission required in System Settings"
            eventTapEnabled = false
            return
        }
        startEventTap()
    }

    private func refreshAfterApplicationActivation() {
        refreshPermissionDiagnostics()
        guard cgPreflightListenAccess else {
            permissionStatus = permissionStatus == .notRequested ? .notRequested : .systemSettingsRequired
            eventTapStatus = permissionStatus == .notRequested
                ? "Input Monitoring authorization not requested"
                : "Input Monitoring permission required in System Settings"
            eventTapEnabled = false
            return
        }
        startEventTap()
    }

    private func startEventTap() {
        lifecycleLock.lock()
        guard lifecycle.requestStart() else {
            lifecycleLock.unlock()
            return
        }
        lifecycleLock.unlock()

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let counter = Unmanaged<TypingCounter>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = counter.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            counter.handle(event: event)
            return Unmanaged.passUnretained(event)
        }

        eventQueue.async { [weak self] in
            guard let self else { return }
            let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: refcon
            ) else {
                self.lifecycleLock.lock()
                _ = self.lifecycle.failStart()
                self.lifecycleLock.unlock()
                DispatchQueue.main.async {
                    self.permissionStatus = .eventTapFailed
                    self.eventTapEnabled = false
                    self.eventTapStatus = "Unable to create event tap"
                }
                return
            }

            self.eventTap = tap
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            self.runLoopSource = source
            guard let runLoop = CFRunLoopGetCurrent() else {
                self.eventTap = nil
                self.runLoopSource = nil
                self.lifecycleLock.lock()
                _ = self.lifecycle.failStart()
                self.lifecycleLock.unlock()
                CFMachPortInvalidate(tap)
                DispatchQueue.main.async {
                    self.permissionStatus = .eventTapFailed
                    self.eventTapEnabled = false
                    self.eventTapStatus = "Unable to create event tap run loop"
                }
                return
            }
            self.lifecycleLock.lock()
            self.eventTapRunLoop = runLoop
            let shouldStop = self.lifecycle.didCreateTap()
            self.lifecycleLock.unlock()

            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            DispatchQueue.main.async {
                self.permissionStatus = .granted
                if !shouldStop {
                    self.eventTapEnabled = true
                    self.eventTapStatus = "Running"
                }
            }

            if shouldStop {
                self.stopEventTapOnRunLoop(runLoop: runLoop)
                return
            }

            CFRunLoopRun()
            self.finishEventTapAfterRunLoopExit()
        }
    }

    func stop() {
        lifecycleLock.lock()
        guard lifecycle.requestStop() else {
            lifecycleLock.unlock()
            return
        }
        let runLoop = eventTapRunLoop
        lifecycleLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.eventTapEnabled = false
            self?.eventTapStatus = "Stopping"
        }

        // The event queue is occupied by CFRunLoopRun while the tap is live,
        // so cleanup cannot be enqueued onto that same queue. Perform the
        // cleanup block on the tap's own run loop instead.
        guard let runLoop else { return }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes as AnyObject) { [weak self] in
            self?.stopEventTapOnRunLoop(runLoop: runLoop)
        }
        CFRunLoopWakeUp(runLoop)
    }

    private func stopEventTapOnRunLoop(runLoop: CFRunLoop) {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        runLoopSource = nil
        eventTap = nil

        lifecycleLock.lock()
        eventTapRunLoop = nil
        let shouldRestart = lifecycle.finishStop()
        lifecycleLock.unlock()

        CFRunLoopStop(runLoop)
        DispatchQueue.main.async { [weak self] in
            self?.eventTapEnabled = false
            self?.eventTapStatus = "Stopped"
        }

        if shouldRestart {
            // The current run-loop block has fully invalidated the old tap.
            // Queue the requested restart behind that cleanup so there is
            // never more than one live Event Tap.
            startEventTap()
        }
    }

    private func finishEventTapAfterRunLoopExit() {
        guard eventTap != nil || runLoopSource != nil else { return }
        stopEventTapOnRunLoop(runLoop: CFRunLoopGetCurrent())
    }

    func resetMetrics() {
        metrics = TypingMetrics()
        appMetricsByApp = [:]
        typingSessions = 0
        activeTypingDuration = 0
        lastValidTypingEventTime = nil
        lastTypingEventAt = nil
    }

    private func handle(event: CGEvent) {
        let category = KeyboardEventClassifier.classify(event: event)
        guard category != .ignored else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.acceptsEvents else { return }
            self.record(category: category, app: self.appProvider(), at: Date())
        }
    }

    func record(category: TypingCategory, app: AppIdentity?, at date: Date) {
        guard acceptsEvents, category != .ignored else { return }

        metrics.record(category)
        if let app {
            let existingApp = appMetricsByApp.keys.first(where: { $0.bundleIdentifier == app.bundleIdentifier })
            var appMetrics = existingApp.flatMap { appMetricsByApp.removeValue(forKey: $0) } ?? AppTypingMetrics()
            appMetrics.record(category)
            appMetricsByApp[app] = appMetrics
        }

        if let previous = lastValidTypingEventTime {
            let delta = date.timeIntervalSince(previous)
            if delta >= Self.typingSessionTimeout {
                typingSessions += 1
            } else if delta > 0 {
                activeTypingDuration += min(delta, Self.activeIntervalCap)
            }
        } else {
            typingSessions = 1
        }

        lastValidTypingEventTime = date
        lastTypingEventAt = date
        onAggregateRecorded?(category, app, date)
    }

    /// Quiesce input before the final persistence checkpoint. Already accepted
    /// aggregate state remains available; queued event callbacks are ignored.
    func quiesce() {
        acceptsEvents = false
        stop()
    }

    private func refreshPermissionDiagnostics() {
        cgPreflightListenAccess = CGPreflightListenEventAccess()
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            iohidListenAccess = .granted
        case kIOHIDAccessTypeDenied:
            iohidListenAccess = .denied
        case kIOHIDAccessTypeUnknown:
            iohidListenAccess = .unknown
        default:
            iohidListenAccess = .unknown
        }
    }

}

enum EventTapLifecycleState: Equatable {
    case stopped
    case starting
    case running
    case stopping
}

/// Pure lifecycle state machine shared by TypingCounter's locked runtime
/// coordination and deterministic XCTest coverage. It owns no Event Tap or
/// RunLoop objects.
struct EventTapLifecycleModel: Equatable {
    private(set) var state: EventTapLifecycleState = .stopped
    private(set) var pendingStartAfterStop = false

    mutating func requestStart() -> Bool {
        switch state {
        case .stopped:
            state = .starting
            return true
        case .stopping:
            pendingStartAfterStop = true
            return false
        case .starting, .running:
            return false
        }
    }

    mutating func requestStop() -> Bool {
        switch state {
        case .starting, .running:
            state = .stopping
            return true
        case .stopped, .stopping:
            return false
        }
    }

    mutating func didCreateTap() -> Bool {
        guard state == .starting || state == .stopping else { return false }
        if state == .starting {
            state = .running
        }
        return state == .stopping
    }

    mutating func failStart() -> Bool {
        guard state == .starting || state == .stopping else { return false }
        state = .stopped
        pendingStartAfterStop = false
        return false
    }

    mutating func finishStop() -> Bool {
        guard state == .starting || state == .running || state == .stopping else { return false }
        state = .stopped
        let shouldRestart = pendingStartAfterStop
        pendingStartAfterStop = false
        return shouldRestart
    }
}
