import Foundation

enum BandwidthSharingMode: String, CaseIterable, Codable, Sendable {
    case auto
    case fair
    case performance

    var displayName: String {
        switch self {
        case .auto: return L10n.t(de: "Automatisch", en: "Auto")
        case .fair: return L10n.t(de: "Fair", en: "Fair")
        case .performance: return L10n.t(de: "Performance", en: "Performance")
        }
    }

    var description: String {
        switch self {
        case .auto: return L10n.t(de: "Intelligent zwischen fair und Performance wählen", en: "Intelligently choose between fair and performance")
        case .fair: return L10n.t(de: "Gleichmäßige Verteilung auf alle aktiven Downloads", en: "Evenly distribute across all active downloads")
        case .performance: return L10n.t(de: "Erste Downloads bevorzugen für maximale Geschwindigkeit", en: "Prioritize early downloads for maximum speed")
        }
    }
}
