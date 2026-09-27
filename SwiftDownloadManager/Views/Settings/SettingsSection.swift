import Foundation

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case downloads
    case network
    case integration
    case automation
    case notifications
    case hotkeys
    case advanced
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L10n.t(de: "Allgemein", en: "General")
        case .downloads: return L10n.t(de: "Downloads", en: "Downloads")
        case .network: return L10n.t(de: "Netzwerk", en: "Network")
        case .integration: return L10n.t(de: "Integration", en: "Integration")
        case .automation: return L10n.t(de: "Automatisierung", en: "Automation")
        case .notifications: return L10n.t(de: "Benachrichtigungen", en: "Notifications")
        case .hotkeys: return L10n.t(de: "Tastenkürzel", en: "Hotkeys")
        case .advanced: return L10n.t(de: "Erweitert", en: "Advanced")
        case .about: return L10n.t(de: "Über", en: "About")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .downloads: return "arrow.down.circle"
        case .network: return "network"
        case .integration: return "puzzlepiece.extension"
        case .automation: return "wand.and.stars"
        case .notifications: return "bell"
        case .hotkeys: return "keyboard"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }

    var help: String {
        switch self {
        case .general:
            return L10n.t(
                de: "Sprache, Standardordner, Start- und Dialogverhalten.",
                en: "Language, default folder, startup and dialog behavior."
            )
        case .downloads:
            return L10n.t(
                de: "Warteschlange, Beschleunigung und Dateikonflikte.",
                en: "Queue, acceleration, and file conflicts."
            )
        case .network:
            return L10n.t(
                de: "Geschwindigkeits-Limit, WLAN und Bandbreitenverteilung.",
                en: "Speed limit, Wi-Fi, and bandwidth sharing."
            )
        case .integration:
            return L10n.t(
                de: "Browser-Integration, Domain-Regeln und Zwischenablage.",
                en: "Browser integration, domain rules, and clipboard."
            )
        case .automation:
            return L10n.t(
                de: "Automatische Vorschläge ohne globalen Master-Schalter.",
                en: "Automatic suggestions without a global master switch."
            )
        case .notifications:
            return L10n.t(
                de: "Systemhinweise, Warteschlange und Dock-Badge.",
                en: "System notifications, queue, and Dock badge."
            )
        case .hotkeys:
            return L10n.t(
                de: "Menü-Tastenkürzel anpassen und Konflikte vermeiden.",
                en: "Customize menu keyboard shortcuts and avoid conflicts."
            )
        case .advanced:
            return L10n.t(
                de: "Verlauf, Diagnose, Zurücksetzen und Motor-Tuning.",
                en: "History, diagnostics, reset, and engine tuning."
            )
        case .about:
            return L10n.t(de: "App-Version und Informationen.", en: "App version and information.")
        }
    }
}
