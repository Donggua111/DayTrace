import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans
    case english

    static let storageKey = "daytrace.language"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return Locale.current
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    var localizationKey: String {
        switch self {
        case .system: return "language.system"
        case .zhHans: return "language.zhHans"
        case .english: return "language.english"
        }
    }
}
