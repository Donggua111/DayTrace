import Combine
import Foundation

@MainActor
final class BackgroundActivityCoordinator: ObservableObject {
    static let enabledKey = "daytrace.backgroundActivity.enabled"
    static let detectorEnabledPrefix = "daytrace.backgroundActivity.detector."

    let detectors: [BackgroundActivityDetector]
    private let usageStore: UsageStore
    private let foregroundTracker: ForegroundTracker
    private let defaults: UserDefaults
    private var refreshTimer: Timer?
    private var isStopping = false

    @Published private(set) var detectorSnapshots: [BackgroundDetectorSnapshot] = []
    @Published private(set) var backgroundActivityEnabled: Bool

    var enabledDetectorIdentifiers: Set<String> {
        Set(detectors.filter { isDetectorEnabled($0) }.map(\.identifier))
    }

    var onTransition: (() -> Void)?

    init(
        usageStore: UsageStore,
        foregroundTracker: ForegroundTracker,
        detectors: [BackgroundActivityDetector] = BackgroundActivityCatalog.makeDefaultDetectors(),
        defaults: UserDefaults = .standard
    ) {
        self.usageStore = usageStore
        self.foregroundTracker = foregroundTracker
        self.detectors = detectors
        self.defaults = defaults
        self.backgroundActivityEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    deinit { refreshTimer?.invalidate() }

    func start() {
        guard refreshTimer == nil else { return }
        isStopping = false
        refresh(at: Date())
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh(at: Date()) }
        }
        timer.tolerance = 0.25
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop(at date: Date = Date()) {
        isStopping = true
        refreshTimer?.invalidate()
        refreshTimer = nil
        usageStore.closeBackgroundActivityIntervals(at: date)
    }

    func refresh(at date: Date = Date()) {
        guard !isStopping else { return }
        let inspected = detectors.map { $0.inspect(at: date) }
        detectorSnapshots = inspected
        let transition = usageStore.updateBackgroundActivity(
            snapshots: inspected,
            foregroundApp: foregroundTracker.currentApp,
            trackingState: foregroundTracker.isTracking ? foregroundTracker.systemState : .paused,
            globallyEnabled: backgroundActivityEnabled,
            enabledDetectorIdentifiers: enabledDetectorIdentifiers,
            at: date
        )
        if transition { onTransition?() }
    }

    func setBackgroundActivityEnabled(_ enabled: Bool) {
        guard enabled != backgroundActivityEnabled else { return }
        backgroundActivityEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        refresh(at: Date())
    }

    func isDetectorEnabled(_ detector: BackgroundActivityDetector) -> Bool {
        isDetectorEnabled(identifier: detector.identifier)
    }

    func setDetectorEnabled(_ enabled: Bool, identifier: String) {
        guard enabled != isDetectorEnabled(identifier: identifier) else { return }
        defaults.set(enabled, forKey: Self.detectorEnabledPrefix + identifier)
        refresh(at: Date())
    }

    func isDetectorEnabled(identifier: String) -> Bool {
        defaults.object(forKey: Self.detectorEnabledPrefix + identifier) as? Bool ?? true
    }

    func activeActivities(at date: Date = Date()) -> [BackgroundActivityInterval] {
        usageStore.backgroundSummary(for: date, now: date).intervals.filter(\.isOpen)
    }

}
