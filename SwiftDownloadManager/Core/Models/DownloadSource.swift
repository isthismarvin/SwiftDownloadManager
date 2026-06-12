import Foundation

enum DownloadSource: String, Codable, Sendable {
    case chromeExtension
    case dragDrop
    case paste
    case manual
    case external

    var displayName: String {
        switch self {
        case .chromeExtension: return L10n.t(de: "Chrome Extension", en: "Chrome Extension")
        case .dragDrop: return L10n.t(de: "Drag & Drop", en: "Drag & Drop")
        case .paste: return L10n.t(de: "Zwischenablage", en: "Clipboard")
        case .manual: return L10n.t(de: "Manuell", en: "Manual")
        case .external: return L10n.t(de: "Extern", en: "External")
        }
    }

    var icon: String {
        switch self {
        case .chromeExtension: return "globe"
        case .dragDrop: return "arrow.down.doc"
        case .paste: return "doc.on.clipboard"
        case .manual: return "plus.circle"
        case .external: return "link"
        }
    }
}

enum PostDownloadAction: String, Codable, CaseIterable, Sendable {
    case none
    case revealInFinder
    case openFile
    case extractArchive

    var displayName: String {
        switch self {
        case .none: return L10n.t(de: "Keine", en: "None")
        case .revealInFinder: return L10n.t(de: "Im Finder anzeigen", en: "Show in Finder")
        case .openFile: return L10n.t(de: "Datei öffnen", en: "Open file")
        case .extractArchive: return L10n.t(de: "Archiv entpacken", en: "Extract archive")
        }
    }
}

struct DownloadConfirmationOptions: Sendable {
    var fileName: String
    var urlString: String
    var preferredSegmentsCount: Int = 4
    var libraryCategory: LibraryCategory?
    var folder: DownloadFolder?
    var saveDirectory: URL?
    var domainPolicy: DomainPolicy?
    var startImmediately: Bool = true
    var postDownloadAction: PostDownloadAction = .none
    var scheduledStartAt: Date?
    var startWhenOnWiFi: Bool = false
    var useBrowserHeaders: Bool = true
    var conflictPolicyOverride: DestinationConflictPolicy?
}
