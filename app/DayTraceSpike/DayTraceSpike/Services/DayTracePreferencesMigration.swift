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
        legacyBundleIdentifier: String = DayTraceIdentity.legacyBundleIdentifier
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
            targetDefaults.set(
                migratedValue(
                    oldValues[key],
                    forKey: key,
                    legacyBundleIdentifier: legacyBundleIdentifier,
                    targetBundleIdentifier: targetBundleIdentifier
                ),
                forKey: key
            )
            copiedKeys.append(key)
        }
        targetDefaults.set(DayTraceIdentity.identityMigrationVersion, forKey: markerKey)
        return DayTracePreferencesMigrationOutcome(migrated: true, copiedKeys: copiedKeys)
    }

    private static func migratedValue(
        _ value: Any?,
        forKey key: String,
        legacyBundleIdentifier: String,
        targetBundleIdentifier: String
    ) -> Any? {
        guard let value, legacyBundleIdentifier != targetBundleIdentifier else { return value }

        switch key {
        case "daytrace.metadata.favoriteApps", "daytrace.metadata.hiddenApps":
            guard let identifiers = value as? [String] else { return value }
            return Array(Set(identifiers.map { $0 == legacyBundleIdentifier ? targetBundleIdentifier : $0 })).sorted()
        case "daytrace.metadata.categories":
            guard var categories = value as? [String: String] else { return value }
            if let legacyCategory = categories.removeValue(forKey: legacyBundleIdentifier),
               categories[targetBundleIdentifier] == nil {
                categories[targetBundleIdentifier] = legacyCategory
            }
            return categories
        case "daytrace.metadata.categoryRules":
            guard let data = value as? Data,
                  let rules = try? JSONDecoder().decode([CategoryRule].self, from: data) else {
                return value
            }
            let migratedRules = rules.map { rule in
                guard rule.targetKind == .app, rule.target == legacyBundleIdentifier else { return rule }
                return CategoryRule(
                    id: rule.id,
                    targetKind: rule.targetKind,
                    target: targetBundleIdentifier,
                    category: rule.category
                )
            }
            return try? JSONEncoder().encode(migratedRules)
        default:
            return value
        }
    }
}
