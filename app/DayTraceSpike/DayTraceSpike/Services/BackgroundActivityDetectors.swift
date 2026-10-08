import AppKit
import CoreAudio
import CoreGraphics
import Foundation

protocol BackgroundProcessLookup {
    func processIDs(for bundleIdentifier: String) -> [pid_t]
}

final class WorkspaceBackgroundProcessLookup: BackgroundProcessLookup {
    private let processIDQuery: (String) -> [pid_t]

    init(processIDQuery: @escaping (String) -> [pid_t] = { bundleIdentifier in
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { !$0.isTerminated }
            .map(\.processIdentifier)
    }) {
        self.processIDQuery = processIDQuery
    }

    func processIDs(for bundleIdentifier: String) -> [pid_t] {
        processIDQuery(bundleIdentifier)
    }
}

protocol ProcessAudioStateProvider {
    func outputIsRunning(for processID: pid_t) -> Bool?
}

/// Public CoreAudio process property only. No audio samples or content are read.
final class CoreAudioProcessStateProvider: ProcessAudioStateProvider {
    func outputIsRunning(for processID: pid_t) -> Bool? {
        var processObjectID = AudioObjectID(kAudioObjectUnknown)
        var translateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var processID = processID
        var objectSize = UInt32(MemoryLayout<AudioObjectID>.size)
        let translateStatus = withUnsafePointer(to: &processID) { qualifier in
            withUnsafeMutablePointer(to: &processObjectID) { output in
                AudioObjectGetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &translateAddress,
                    UInt32(MemoryLayout<pid_t>.size),
                    qualifier,
                    &objectSize,
                    output
                )
            }
        }
        guard translateStatus == noErr, processObjectID != kAudioObjectUnknown else { return nil }

        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var runningSize = UInt32(MemoryLayout<UInt32>.size)
        let runningStatus = withUnsafeMutablePointer(to: &isRunning) { output in
            AudioObjectGetPropertyData(
                processObjectID,
                &runningAddress,
                0,
                nil,
                &runningSize,
                output
            )
        }
        guard runningStatus == noErr else { return nil }
        return isRunning != 0
    }
}

final class ProcessAudioActivityDetector: BackgroundActivityDetector {
    let identifier: String
    let app: AppIdentity
    let activityKind: BackgroundActivityKind = .audioPlayback

    private let processLookup: BackgroundProcessLookup
    private let audioStateProvider: ProcessAudioStateProvider

    init(
        identifier: String,
        app: AppIdentity,
        processLookup: BackgroundProcessLookup = WorkspaceBackgroundProcessLookup(),
        audioStateProvider: ProcessAudioStateProvider = CoreAudioProcessStateProvider()
    ) {
        self.identifier = identifier
        self.app = app
        self.processLookup = processLookup
        self.audioStateProvider = audioStateProvider
    }

    func inspect(at date: Date) -> BackgroundDetectorSnapshot {
        let processIDs = processLookup.processIDs(for: app.bundleIdentifier)
        guard let processID = processIDs.first else {
            return BackgroundDetectorSnapshot(identifier: identifier, app: app, activityKind: activityKind, state: .inactive(processRunning: false), observedAt: date)
        }
        guard let outputIsRunning = audioStateProvider.outputIsRunning(for: processID) else {
            return BackgroundDetectorSnapshot(identifier: identifier, app: app, activityKind: activityKind, state: .unavailable(reason: "CoreAudio process output state unavailable"), observedAt: date)
        }
        return BackgroundDetectorSnapshot(
            identifier: identifier,
            app: app,
            activityKind: activityKind,
            state: outputIsRunning ? .active(processRunning: true) : .inactive(processRunning: true),
            observedAt: date
        )
    }
}

struct VisibleSurfaceWindowMetadata: Equatable {
    let ownerPID: pid_t
    let layer: Int
    let width: Double
    let height: Double
    let alpha: Double
    let isOnscreen: Bool
}

protocol VisibleSurfaceProvider {
    func hasRelevantSurface(for processID: pid_t) -> Bool
}

/// Uses only public WindowServer metadata. It deliberately ignores titles,
/// content, pixels, and coordinates. NookX's active surface is above normal
/// windows (non-zero layer); settings/helper windows are normal layer 0.
final class CGWindowVisibleSurfaceProvider: VisibleSurfaceProvider {
    func hasRelevantSurface(for processID: pid_t) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return windows.contains { window in
            guard let ownerPID = (window[kCGWindowOwnerPID as String] as? NSNumber)?.intValue,
                  ownerPID == Int(processID),
                  let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  layer > 0,
                  let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue,
                  alpha > 0,
                  let isOnscreen = (window[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue,
                  isOnscreen,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue else {
                return false
            }
            return width > 0 && height > 0
        }
    }
}

final class VisibleSurfaceActivityDetector: BackgroundActivityDetector {
    let identifier: String
    let app: AppIdentity
    let activityKind: BackgroundActivityKind = .visibleSurface

    private let processLookup: BackgroundProcessLookup
    private let surfaceProvider: VisibleSurfaceProvider

    init(
        identifier: String,
        app: AppIdentity,
        processLookup: BackgroundProcessLookup = WorkspaceBackgroundProcessLookup(),
        surfaceProvider: VisibleSurfaceProvider = CGWindowVisibleSurfaceProvider()
    ) {
        self.identifier = identifier
        self.app = app
        self.processLookup = processLookup
        self.surfaceProvider = surfaceProvider
    }

    func inspect(at date: Date) -> BackgroundDetectorSnapshot {
        let processIDs = processLookup.processIDs(for: app.bundleIdentifier)
        guard let processID = processIDs.first else {
            return BackgroundDetectorSnapshot(identifier: identifier, app: app, activityKind: activityKind, state: .inactive(processRunning: false), observedAt: date)
        }
        let active = surfaceProvider.hasRelevantSurface(for: processID)
        return BackgroundDetectorSnapshot(
            identifier: identifier,
            app: app,
            activityKind: activityKind,
            state: active ? .active(processRunning: true) : .inactive(processRunning: true),
            observedAt: date
        )
    }
}

enum BackgroundActivityCatalog {
    static let nookX = AppIdentity(bundleIdentifier: "com.monsterwl.NookX", displayName: "NookX")
    static let netEase = AppIdentity(bundleIdentifier: "com.netease.163music", displayName: "网易云音乐")

    static func makeDefaultDetectors(
        processLookup: BackgroundProcessLookup = WorkspaceBackgroundProcessLookup(),
        audioStateProvider: ProcessAudioStateProvider = CoreAudioProcessStateProvider(),
        surfaceProvider: VisibleSurfaceProvider = CGWindowVisibleSurfaceProvider()
    ) -> [BackgroundActivityDetector] {
        [
            VisibleSurfaceActivityDetector(identifier: "nookx.visibleSurface", app: nookX, processLookup: processLookup, surfaceProvider: surfaceProvider),
            ProcessAudioActivityDetector(identifier: "netease.audioPlayback", app: netEase, processLookup: processLookup, audioStateProvider: audioStateProvider)
        ]
    }
}
