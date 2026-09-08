import Foundation

struct DayTracePreferencesMigrationOutcome: Equatable {
    let migrated: Bool
    let copiedKeys: [String]
}

enum DayTracePreferencesMigration {
    static let markerKey = "daytrace.identityMigrationVersion"

    /// Only known DayTrace settings are eligible for identity migration.
    static let knownKeys = [
        AppLanguage.storageKey,
        "daytrace.menuBarDisplayMode",
        "daytrace.timeline.enabled",
        "daytrace.backgroundActivity.enabled",
        "daytrace.backups.enabled",
        "daytrace.backups.retention",
        "daytrace.backups.lastBackupAt",
        "daytrace.onboarding.completed",
        "daytrace.metadata.favoriteApps",
        "daytrace.metadata.favoriteWebsites",
        "daytrace.metadata.categories",
        "daytrace.metadata.customCategories",
        "daytrace.metadata.categoryRules",
        "daytrace.metadata.hiddenApps",
        "daytrace.metadata.hiddenWebsites"
    ]

    static let knownPrefixes = ["daytrace.backgroundActivity.detector."]

    @discardableResult
    static func migrateIfNeeded(
        targetBundleIdentifier: String = DayTraceIdentity.activeBundleIdentifier,
        targetDefaults: UserDefaults = .standard,
        legacyDomain: [String: Any]? = nil,
        legacyBundleIdentifier: String = DayTraceIdentity.developmentBundleIdentifier
    ) -> DayTracePreferencesMigrationOutcome {
        guard targetBundleIdentifier != legacyBundleIdentifier else {
            return DayTracePreferencesMigrationOutcome(migrated: false, copiedKeys: [])
        }

        let currentVersion = targetDefaults.integer(forKey: markerKey)
        guard currentVersion < DayTraceIdentity.identityMigrationVersion else {
            return DayTracePreferencesMigrationOutcome(migrated: false, copiedKeys: [])
        }

        let oldValues = legacyDomain ?? targetDefaults.persistentDomain(forName: legacyBundleIdentifier) ?? [:]
        let currentValues = targetDefaults.persistentDomain(forName: targetBundleIdentifier) ?? [:]
        let eligibleKeys = oldValues.keys.filter { key in
            knownKeys.contains(key) || knownPrefixes.contains(where: { key.hasPrefix($0) })
        }
        var copiedKeys: [String] = []
        for key in eligibleKeys.sorted() where currentValues[key] == nil {
            targetDefaults.set(oldValues[key], forKey: key)
            copiedKeys.append(key)
        }
        targetDefaults.set(DayTraceIdentity.identityMigrationVersion, forKey: markerKey)
        return DayTracePreferencesMigrationOutcome(migrated: true, copiedKeys: copiedKeys)
    }
}
