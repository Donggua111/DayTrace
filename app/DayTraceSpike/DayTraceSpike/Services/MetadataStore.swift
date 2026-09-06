import Combine
import Foundation

/// User-facing metadata is deliberately separate from aggregate usage records.
/// It can change without changing identity or historical measurements.
@MainActor
final class MetadataStore: ObservableObject {
    private static let favoriteAppsKey = "daytrace.metadata.favoriteApps"
    private static let favoriteWebsitesKey = "daytrace.metadata.favoriteWebsites"
    private static let categoriesKey = "daytrace.metadata.categories"
    private static let customCategoriesKey = "daytrace.metadata.customCategories"

    @Published private(set) var favoriteAppBundleIDs: Set<String>
    @Published private(set) var favoriteWebsites: Set<String>
    @Published private(set) var categoriesByApp: [String: String]
    @Published private(set) var customCategories: [String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favoriteAppBundleIDs = Set(defaults.stringArray(forKey: Self.favoriteAppsKey) ?? [])
        favoriteWebsites = Set(defaults.stringArray(forKey: Self.favoriteWebsitesKey) ?? [])
        categoriesByApp = defaults.dictionary(forKey: Self.categoriesKey) as? [String: String] ?? [:]
        customCategories = defaults.stringArray(forKey: Self.customCategoriesKey) ?? []
    }

    func isFavorite(app: AppIdentity) -> Bool { favoriteAppBundleIDs.contains(app.bundleIdentifier) }
    func isFavorite(website: String) -> Bool { favoriteWebsites.contains(website) }

    func toggleFavorite(app: AppIdentity) {
        if !favoriteAppBundleIDs.insert(app.bundleIdentifier).inserted {
            favoriteAppBundleIDs.remove(app.bundleIdentifier)
        }
        save()
    }

    func toggleFavorite(website: String) {
        if !favoriteWebsites.insert(website).inserted { favoriteWebsites.remove(website) }
        save()
    }

    func category(for app: AppIdentity) -> String? { categoriesByApp[app.bundleIdentifier] }

    func setCategory(_ category: String?, for app: AppIdentity) {
        if let category, !category.isEmpty { categoriesByApp[app.bundleIdentifier] = category }
        else { categoriesByApp.removeValue(forKey: app.bundleIdentifier) }
        save()
    }

    func addCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !customCategories.contains(trimmed) else { return }
        customCategories.append(trimmed)
        customCategories.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        save()
    }

    func renameCategory(from oldName: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, oldName != trimmed, !customCategories.contains(trimmed) else { return }
        customCategories = customCategories.map { $0 == oldName ? trimmed : $0 }
        for (appID, category) in categoriesByApp where category == oldName { categoriesByApp[appID] = trimmed }
        save()
    }

    func deleteCategory(_ name: String) {
        customCategories.removeAll { $0 == name }
        categoriesByApp = categoriesByApp.filter { $0.value != name }
        save()
    }

    private func save() {
        defaults.set(Array(favoriteAppBundleIDs).sorted(), forKey: Self.favoriteAppsKey)
        defaults.set(Array(favoriteWebsites).sorted(), forKey: Self.favoriteWebsitesKey)
        defaults.set(categoriesByApp, forKey: Self.categoriesKey)
        defaults.set(customCategories, forKey: Self.customCategoriesKey)
        objectWillChange.send()
    }
}
