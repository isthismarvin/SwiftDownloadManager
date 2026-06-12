import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case german = "de"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.t(de: "System", en: "System")
        case .german: return L10n.t(de: "Deutsch", en: "German")
        case .english: return L10n.t(de: "Englisch", en: "English")
        }
    }
}
