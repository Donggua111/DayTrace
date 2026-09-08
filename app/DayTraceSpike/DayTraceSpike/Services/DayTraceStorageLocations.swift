import Foundation

/// Stable, user-owned locations. These paths deliberately do not include the
/// app Bundle ID so an eventual identity cutover cannot hide activity history.
enum DayTraceStorageLocations {
    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    static var rootDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("DayTrace", isDirectory: true)
    }

    static var storeURL: URL {
        rootDirectory.appendingPathComponent("DayTrace.sqlite")
    }

    static var backupDirectory: URL {
        rootDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    static var runtimeDirectory: URL {
        rootDirectory.appendingPathComponent("Runtime", isDirectory: true)
    }

    static var socketURL: URL {
        rootDirectory.appendingPathComponent("Spike/daytrace.sock")
    }

    /// Kept compatible with the already-installed development manifest.
    static var nativeHostDevelopmentURL: URL {
        rootDirectory.appendingPathComponent("Spike/Development/DayTraceNativeHost")
    }
}
