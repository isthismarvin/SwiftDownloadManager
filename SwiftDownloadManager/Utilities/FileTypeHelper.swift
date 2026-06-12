import Foundation
import AppKit
import UniformTypeIdentifiers

enum LibraryCategory: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case files
    case videos
    case images
    case archives

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .files: return L10n.t(de: "Dokumente", en: "Documents")
        case .videos: return L10n.t(de: "Videos", en: "Videos")
        case .images: return L10n.t(de: "Bilder", en: "Images")
        case .archives: return L10n.t(de: "Archive", en: "Archives")
        }
    }

    var icon: String {
        switch self {
        case .files: return "doc"
        case .videos: return "film"
        case .images: return "photo"
        case .archives: return "archivebox"
        }
    }
}

enum FileTypeHelper {
    private static let videoExtensions: Set<String> = ["mp4", "mov", "mkv", "avi", "webm", "m4v"]
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "bmp", "tiff"]
    private static let archiveExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz", "bz2", "iso", "dmg"]
    private static let fileExtensions: Set<String> = ["pdf", "doc", "docx", "txt", "rtf", "xls", "xlsx", "ppt", "pptx", "csv", "md"]

    static func category(for fileName: String) -> LibraryCategory? {
        let ext = fileExtension(from: fileName)
        guard !ext.isEmpty else { return nil }

        if videoExtensions.contains(ext) { return .videos }
        if imageExtensions.contains(ext) { return .images }
        if archiveExtensions.contains(ext) { return .archives }
        if fileExtensions.contains(ext) { return .files }
        return nil
    }

    static func matches(category: LibraryCategory, fileName: String) -> Bool {
        let ext = fileExtension(from: fileName)
        guard !ext.isEmpty else { return false }

        switch category {
        case .videos: return videoExtensions.contains(ext)
        case .images: return imageExtensions.contains(ext)
        case .archives: return archiveExtensions.contains(ext)
        case .files: return fileExtensions.contains(ext)
        }
    }

    static func icon(for fileName: String) -> String {
        let ext = fileExtension(from: fileName)

        switch ext {
        case "zip", "rar", "7z", "tar", "gz", "bz2":
            return "doc.zipper"
        case "iso", "dmg":
            return "opticaldisc"
        case "mp4", "mov", "mkv", "avi", "webm", "m4v":
            return "film"
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "bmp", "tiff":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "doc", "docx", "txt", "rtf", "md":
            return "doc.text"
        case "xls", "xlsx", "csv":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.stack"
        default:
            return "doc"
        }
    }

    /// Liefert das echte macOS-Systemicon für den Dateityp (wie im Finder).
    static func systemIcon(for fileName: String) -> NSImage {
        let ext = fileExtension(from: fileName)
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    private static func fileExtension(from fileName: String) -> String {
        URL(fileURLWithPath: fileName).pathExtension.lowercased()
    }
}
