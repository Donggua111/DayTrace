import Combine
import Foundation

struct CategoryRule: Codable, Equatable, Identifiable {
    enum TargetKind: String, Codable { case app, website }
    let id: UUID
    let targetKind: TargetKind
    let target: String
    let category: String
}

/// User-facing metadata is deliberately separate from aggregate usage records.
/// It can change without changing identity or historical measurements.
@MainActor
final class MetadataStore: ObservableObject {
    private static let favoriteAppsKey = "daytrace.metadata.favoriteApps"
    private static let favoriteWebsitesKey = "daytrace.metadata.favoriteWebsites"
    private static let categoriesKey = "daytrace.metadata.categories"
    private static let customCategoriesKey = "daytrace.metadata.customCategories"
    private static let rulesKey = "daytrace.metadata.categoryRules"
    private static let hiddenAppsKey = "daytrace.metadata.hiddenApps"
    private static let hiddenWebsitesKey = "daytrace.metadata.hiddenWebsites"

    @Published private(set) var favoriteAppBundleIDs: Set<String>
    @Published private(set) var favoriteWebsites: Set<String>
    @Published private(set) var categoriesByApp: [String: String]
    @Published private(set) var customCategories: [String]
    @Published private(set) var categoryRules: [CategoryRule]
    @Published private(set) var hiddenAppBundleIDs: Set<String>
    @Published private(set) var hiddenWebsites: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favoriteAppBundleIDs = Set(defaults.stringArray(forKey: Self.favoriteAppsKey) ?? [])
        favoriteWebsites = Set(defaults.stringArray(forKey: Self.favoriteWebsitesKey) ?? [])
        categoriesByApp = defaults.dictionary(forKey: Self.categoriesKey) as? [String: String] ?? [:]
        customCategories = defaults.stringArray(forKey: Self.customCategoriesKey) ?? []
        if let data = defaults.data(forKey: Self.rulesKey), let rules = try? JSONDecoder().decode([CategoryRule].self, from: data) {
            categoryRules = rules
        } else {
            categoryRules = []
        }
        hiddenAppBundleIDs = Set(defaults.stringArray(forKey: Self.hiddenAppsKey) ?? [])
        hiddenWebsites = Set(defaults.stringArray(forKey: Self.hiddenWebsitesKey) ?? [])
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

    /// Manual assignment wins over an exact-match rule, then Uncategorized.
    func resolvedCategory(for app: AppIdentity) -> String? {
        category(for: app) ?? categoryRules.first(where: { $0.targetKind == .app && $0.target == app.bundleIdentifier })?.category
    }

    func resolvedCategory(for website: String) -> String? {
        categoryRules.first(where: { $0.targetKind == .website && $0.target == website })?.category
    }

    func addRule(targetKind: CategoryRule.TargetKind, target: String, category: String) {
        let normalizedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTarget.isEmpty, !normalizedCategory.isEmpty else { return }
        categoryRules.removeAll { $0.targetKind == targetKind && $0.target == normalizedTarget }
        categoryRules.append(CategoryRule(id: UUID(), targetKind: targetKind, target: normalizedTarget, category: normalizedCategory))
        save()
    }

    func deleteRule(_ rule: CategoryRule) {
        categoryRules.removeAll { $0.id == rule.id }
        save()
    }

    func isIdentityHidden(app: AppIdentity) -> Bool { hiddenAppBundleIDs.contains(app.bundleIdentifier) }
    func isIdentityHidden(website: String) -> Bool { hiddenWebsites.contains(website) }

    func toggleIdentityHidden(app: AppIdentity) {
        if !hiddenAppBundleIDs.insert(app.bundleIdentifier).inserted { hiddenAppBundleIDs.remove(app.bundleIdentifier) }
        save()
    }

    func toggleIdentityHidden(website: String) {
        if !hiddenWebsites.insert(website).inserted { hiddenWebsites.remove(website) }
        save()
    }

    func presentationName(for app: AppIdentity) -> String { isIdentityHidden(app: app) ? String(localized: "metadata.privateApp") : app.displayName }
    func presentationName(for website: String) -> String { isIdentityHidden(website: website) ? String(localized: "metadata.privateWebsite") : website }

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
        categoryRules = categoryRules.map { rule in
            rule.category == oldName
                ? CategoryRule(id: rule.id, targetKind: rule.targetKind, target: rule.target, category: trimmed)
                : rule
        }
        save()
    }

    func deleteCategory(_ name: String) {
        customCategories.removeAll { $0 == name }
        categoriesByApp = categoriesByApp.filter { $0.value != name }
        categoryRules.removeAll { $0.category == name }
        save()
    }

    private func save() {
        defaults.set(Array(favoriteAppBundleIDs).sorted(), forKey: Self.favoriteAppsKey)
        defaults.set(Array(favoriteWebsites).sorted(), forKey: Self.favoriteWebsitesKey)
        defaults.set(categoriesByApp, forKey: Self.categoriesKey)
        defaults.set(customCategories, forKey: Self.customCategoriesKey)
        defaults.set(try? JSONEncoder().encode(categoryRules), forKey: Self.rulesKey)
        defaults.set(Array(hiddenAppBundleIDs).sorted(), forKey: Self.hiddenAppsKey)
        defaults.set(Array(hiddenWebsites).sorted(), forKey: Self.hiddenWebsitesKey)
        objectWillChange.send()
    }
}
