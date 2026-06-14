import Foundation

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general
    case downloads
    case network
    case integration
    case intelligence
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
        case .intelligence: return L10n.t(de: "Intelligenz", en: "Intelligence")
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
        case .intelligence: return "sparkles"
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
                de: "Sprache, Standardordner, Sortierung und Tabellen-Spalten.",
                en: "Language, default folder, sorting, and table columns."
            )
        case .downloads:
            return L10n.t(de: "Warteschlange, Verbindungen und Dateikonflikte.", en: "Queue, connections, and file conflicts.")
        case .network:
            return L10n.t(de: "Speed-Limit, WLAN und Netzwerk-Optionen.", en: "Speed limit, Wi-Fi, and network options.")
        case .integration:
            return L10n.t(
                de: "Chrome Extension, Domain-Regeln und gelernte Vorschläge.",
                en: "Chrome extension, domain rules, and learned suggestions."
            )
        case .intelligence:
            return L10n.t(
                de: "Lernen, Vorschläge, Hänger-Erkennung und smarte Filter.",
                en: "Learning, suggestions, stall detection, and smart filters."
            )
        case .notifications:
            return L10n.t(
                de: "Systemhinweise, Hänger, Warteschlange und Dock-Badge.",
                en: "System notifications, stalls, queue backlog, and Dock badge."
            )
        case .hotkeys:
            return L10n.t(
                de: "Menü-Tastenkürzel anpassen und Konflikte vermeiden.",
                en: "Customize menu keyboard shortcuts and avoid conflicts."
            )
        case .advanced: return L10n.t(de: "Verlauf, Diagnose und Zurücksetzen.", en: "History, diagnostics, and reset.")
        case .about: return L10n.t(de: "App-Version und Informationen.", en: "App version and information.")
        }
    }
}
