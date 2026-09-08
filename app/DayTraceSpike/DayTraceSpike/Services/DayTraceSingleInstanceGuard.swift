import Darwin
import Foundation

/// A kernel-held advisory lock prevents two DayTrace processes from tracking
/// and checkpointing the same store or owning the same Unix socket.
final class DayTraceSingleInstanceGuard {
    private let runtimeDirectory: URL
    private var fileDescriptor: Int32 = -1

    init(runtimeDirectory: URL = DayTraceStorageLocations.runtimeDirectory) {
        self.runtimeDirectory = runtimeDirectory
    }

    func acquire() -> Bool {
        guard fileDescriptor < 0 else { return true }
        do {
            try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: runtimeDirectory.path)
        } catch {
            return false
        }

        let descriptor = open(runtimeDirectory.appendingPathComponent("daytrace.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { return false }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return false
        }
        fileDescriptor = descriptor
        return true
    }

    deinit {
        if fileDescriptor >= 0 {
            _ = flock(fileDescriptor, LOCK_UN)
            close(fileDescriptor)
        }
    }
}
