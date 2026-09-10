import CoreData
import Foundation

enum BackgroundActivityKind: String, CaseIterable, Codable, Identifiable {
    case audioPlayback
    case visibleSurface

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .audioPlayback: return "background.activity.audioPlayback"
        case .visibleSurface: return "background.activity.visibleSurface"
        }
    }

    /// Audio can remain observable while the interactive session is locked;
    /// a visible surface cannot be meaningfully visible in that state.
    var continuesWhileSessionLocked: Bool {
        self == .audioPlayback
    }

    /// Background activity has a kind-specific lifecycle policy. Manual pause
    /// and system sleep remain global stop conditions for every kind.
    func isEligible(for trackingState: TrackingSystemState) -> Bool {
        switch trackingState {
        case .awake:
            return true
        case .locked:
            return continuesWhileSessionLocked
        case .sleeping, .paused, .unavailable:
            return false
        }
    }
}

enum BackgroundDetectorState: Equatable {
    case unavailable(reason: String)
    case inactive(processRunning: Bool)
    case active(processRunning: Bool)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    var processRunning: Bool {
        switch self {
        case .unavailable: return false
        case let .inactive(processRunning), let .active(processRunning): return processRunning
        }
    }
}

struct BackgroundDetectorSnapshot: Identifiable, Equatable {
    let identifier: String
    let app: AppIdentity
    let activityKind: BackgroundActivityKind
    let state: BackgroundDetectorState
    let observedAt: Date

    var id: String { identifier }
    var isActive: Bool { state.isActive }
}

protocol BackgroundActivityDetector: AnyObject {
    var identifier: String { get }
    var app: AppIdentity { get }
    var activityKind: BackgroundActivityKind { get }
    func inspect(at date: Date) -> BackgroundDetectorSnapshot
}

struct BackgroundActivityInterval: Identifiable, Equatable {
    let id: String
    let dateKey: String
    let start: Date
    let end: Date
    let duration: TimeInterval
    let app: AppIdentity
    let activityKind: BackgroundActivityKind
    let detectorIdentifier: String
    let isOpen: Bool
}

struct BackgroundActivitySummary: Equatable {
    let intervals: [BackgroundActivityInterval]
    let durationsByApp: [AppIdentity: TimeInterval]
    let durationsByKind: [BackgroundActivityKind: TimeInterval]

    static let empty = BackgroundActivitySummary(intervals: [], durationsByApp: [:], durationsByKind: [:])
}

struct BackgroundDataStatistics: Equatable {
    let intervalCount: Int
    let startDate: Date?
}

@objc(BackgroundActivityIntervalRecord)
final class BackgroundActivityIntervalRecord: NSManagedObject {}

extension BackgroundActivityIntervalRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<BackgroundActivityIntervalRecord> {
        NSFetchRequest<BackgroundActivityIntervalRecord>(entityName: "BackgroundActivityIntervalRecord")
    }

    @NSManaged var idString: String
    @NSManaged var dateKey: String
    @NSManaged var startAt: Date
    @NSManaged var endAt: Date
    @NSManaged var durationSeconds: Double
    @NSManaged var isOpen: Bool
    @NSManaged var bundleIdentifier: String
    @NSManaged var displayName: String
    @NSManaged var activityKindRawValue: String
    @NSManaged var detectorIdentifier: String
}
