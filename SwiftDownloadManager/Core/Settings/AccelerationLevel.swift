import Foundation

enum AccelerationLevel: String, CaseIterable, Codable, Sendable {
    case simple
    case balanced
    case fast
    case maximum

    var displayName: String {
        switch self {
        case .simple: return L10n.t(de: "Einfach", en: "Simple")
        case .balanced: return L10n.t(de: "Ausbalanciert", en: "Balanced")
        case .fast: return L10n.t(de: "Schnell", en: "Fast")
        case .maximum: return L10n.t(de: "Maximum", en: "Maximum")
        }
    }

    var description: String {
        switch self {
        case .simple: return L10n.t(de: "Eine Verbindung pro Download", en: "One connection per download")
        case .balanced: return L10n.t(de: "Automatisch angepasste Verbindungen", en: "Automatically adjusted connections")
        case .fast: return L10n.t(de: "Mehrere Verbindungen für größere Dateien", en: "Multiple connections for larger files")
        case .maximum: return L10n.t(de: "Bis zu 8 Verbindungen pro Download", en: "Up to 8 connections per download")
        }
    }

    var segmentCount: Int {
        switch self {
        case .simple: return 1
        case .balanced: return 4
        case .fast: return 6
        case .maximum: return 8
        }
    }
}
