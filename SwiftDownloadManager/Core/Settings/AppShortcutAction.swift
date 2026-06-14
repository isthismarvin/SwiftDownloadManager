import AppKit
import Foundation

enum AppShortcutCategory: String, CaseIterable, Identifiable {
    case file
    case edit
    case download
    case view
    case sidebar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .file: return L10n.t(de: "Ablage", en: "File")
        case .edit: return L10n.t(de: "Bearbeiten", en: "Edit")
        case .download: return L10n.t(de: "Download", en: "Download")
        case .view: return L10n.t(de: "Ansicht", en: "View")
        case .sidebar: return L10n.t(de: "Sidebar", en: "Sidebar")
        }
    }

    var actions: [AppShortcutAction] {
        AppShortcutAction.allCases.filter { $0.category == self }
    }
}

enum AppShortcutAction: String, CaseIterable, Identifiable, Codable {
    case addDownload
    case addFromClipboard
    case openFile
    case revealInFinder
    case copyURL
    case openDownloadsFolder
    case newFolder
    case selectAll
    case deselectAll
    case delete
    case clearCompleted
    case search
    case resume
    case pause
    case cancel
    case resumeAll
    case pauseAll
    case history
    case inspector
    case settings
    case filterAllDownloads
    case filterQueue
    case filterDownloading
    case filterPaused
    case filterCompleted
    case filterFailed
    case filterScheduled

    var id: String { rawValue }

    var category: AppShortcutCategory {
        switch self {
        case .addDownload, .addFromClipboard, .openFile, .revealInFinder, .copyURL,
             .openDownloadsFolder, .newFolder:
            return .file
        case .selectAll, .deselectAll, .delete, .clearCompleted:
            return .edit
        case .search, .resume, .pause, .cancel, .resumeAll, .pauseAll:
            return .download
        case .history, .inspector, .settings:
            return .view
        case .filterAllDownloads, .filterQueue, .filterDownloading, .filterPaused,
             .filterCompleted, .filterFailed, .filterScheduled:
            return .sidebar
        }
    }

    var title: String {
        switch self {
        case .addDownload: return L10n.t(de: "Download hinzufügen", en: "Add Download")
        case .addFromClipboard: return L10n.t(de: "Download aus Zwischenablage", en: "Add Download from Clipboard")
        case .openFile: return L10n.t(de: "Datei öffnen", en: "Open File")
        case .revealInFinder: return L10n.t(de: "Im Finder anzeigen", en: "Reveal in Finder")
        case .copyURL: return L10n.t(de: "URL kopieren", en: "Copy URL")
        case .openDownloadsFolder: return L10n.t(de: "Downloads-Ordner öffnen", en: "Open Downloads Folder")
        case .newFolder: return L10n.t(de: "Neuer Ordner", en: "New Folder")
        case .selectAll: return L10n.t(de: "Alles auswählen", en: "Select All")
        case .deselectAll: return L10n.t(de: "Auswahl aufheben", en: "Deselect All")
        case .delete: return L10n.t(de: "Löschen", en: "Delete")
        case .clearCompleted: return L10n.t(de: "Abgeschlossene löschen", en: "Clear Completed")
        case .search: return L10n.t(de: "Downloads suchen", en: "Search Downloads")
        case .resume: return L10n.t(de: "Fortsetzen", en: "Resume")
        case .pause: return L10n.t(de: "Pausieren", en: "Pause")
        case .cancel: return L10n.t(de: "Abbrechen", en: "Cancel")
        case .resumeAll: return L10n.t(de: "Alle fortsetzen", en: "Resume All")
        case .pauseAll: return L10n.t(de: "Alle pausieren", en: "Pause All")
        case .history: return L10n.t(de: "Verlauf", en: "History")
        case .inspector: return L10n.t(de: "Inspector ein-/ausblenden", en: "Toggle Inspector")
        case .settings: return L10n.t(de: "Einstellungen", en: "Settings")
        case .filterAllDownloads: return L10n.t(de: "Alle Downloads", en: "All Downloads")
        case .filterQueue: return L10n.t(de: "Warteschlange", en: "Queue")
        case .filterDownloading: return L10n.t(de: "Laufend", en: "Downloading")
        case .filterPaused: return L10n.t(de: "Pausiert", en: "Paused")
        case .filterCompleted: return L10n.t(de: "Abgeschlossen", en: "Completed")
        case .filterFailed: return L10n.t(de: "Fehlgeschlagen", en: "Failed")
        case .filterScheduled: return L10n.t(de: "Geplant", en: "Scheduled")
        }
    }

    var defaultShortcut: StoredShortcut {
        switch self {
        case .addDownload: return .cmd("n")
        case .addFromClipboard: return .cmdShift("v")
        case .openFile: return .cmd("o")
        case .revealInFinder: return .cmdShift("r")
        case .copyURL: return .cmdShift("c")
        case .openDownloadsFolder: return .cmdShift("d")
        case .newFolder: return .cmdShift("n")
        case .selectAll: return .cmd("a")
        case .deselectAll: return .escapeOnly()
        case .delete: return StoredShortcut(key: "delete", modifiers: NSEvent.ModifierFlags.command.rawValue)
        case .clearCompleted: return .cmdShift("k")
        case .search: return .cmd("f")
        case .resume: return .cmd("r")
        case .pause: return .cmdOption("p")
        case .cancel: return StoredShortcut(key: ".", modifiers: NSEvent.ModifierFlags.command.rawValue)
        case .resumeAll: return .cmdOption("r")
        case .pauseAll: return .cmdShift("p")
        case .history: return .cmd("y")
        case .inspector: return .cmd("i")
        case .settings: return StoredShortcut(key: ",", modifiers: NSEvent.ModifierFlags.command.rawValue)
        case .filterAllDownloads: return .cmd("1")
        case .filterQueue: return .cmd("2")
        case .filterDownloading: return .cmd("3")
        case .filterPaused: return .cmd("4")
        case .filterCompleted: return .cmd("5")
        case .filterFailed: return .cmd("6")
        case .filterScheduled: return .cmd("7")
        }
    }
}
