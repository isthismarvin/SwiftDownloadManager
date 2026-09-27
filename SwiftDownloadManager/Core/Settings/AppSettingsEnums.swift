import Foundation

enum DestinationConflictPolicy: String, CaseIterable, Identifiable, Codable, Sendable {
    case rename
    case overwrite
    case ask

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rename: return L10n.t(de: "Umbenennen", en: "Rename")
        case .overwrite: return L10n.t(de: "Überschreiben", en: "Overwrite")
        case .ask: return L10n.t(de: "Jedes Mal fragen", en: "Ask every time")
        }
    }
}

enum OnQueueCompleteAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case doNothing
    case sleepMac
    case quitApp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .doNothing: return L10n.t(de: "Nichts tun", en: "Do nothing")
        case .sleepMac: return L10n.t(de: "Mac in Ruhezustand versetzen", en: "Put Mac to sleep")
        case .quitApp: return L10n.t(de: "App beenden", en: "Quit application")
        }
    }
}

enum DockBadgeDisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case activeCount
    case totalSpeed
    case overallProgress
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .activeCount: return L10n.t(de: "Anzahl aktiver Downloads", en: "Active download count")
        case .totalSpeed: return L10n.t(de: "Gesamtgeschwindigkeit", en: "Total download speed")
        case .overallProgress: return L10n.t(de: "Gesamtfortschritt (%)", en: "Overall progress (%)")
        case .none: return L10n.t(de: "Kein Badge", en: "None")
        }
    }
}

enum WindowCloseBehavior: String, CaseIterable, Identifiable, Codable, Sendable {
    case hideToMenuBar
    case minimize
    case quitIfIdle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hideToMenuBar: return L10n.t(de: "In Menüleiste ausblenden (Hintergrund)", en: "Hide to menu bar (Keep in background)")
        case .minimize: return L10n.t(de: "Im Dock minimieren", en: "Minimize to Dock")
        case .quitIfIdle: return L10n.t(de: "Beenden wenn keine aktiven Downloads", en: "Quit if no active downloads")
        }
    }
}
