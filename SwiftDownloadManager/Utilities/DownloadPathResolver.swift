import Foundation
import os

enum DownloadPathResolver {
    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "Paths")

    struct ResolvedTarget {
        let fileURL: URL
        /// Non-nil when access was granted via a security-scoped bookmark.
        /// The caller must call `stopAccessingSecurityScopedResource()` on it
        /// once the download stops writing.
        let scopedDirectoryURL: URL?
    }

    /// Resolves the unique target file URL for a fresh download.
    static func resolveTarget(for item: DownloadItem) -> ResolvedTarget? {
        if let bookmark = item.saveDirectoryBookmark,
           let scoped = BookmarkHelper.resolveBookmark(bookmark) {
            let directory = scoped.resolvingSymlinksInPath()
            guard ensureDirectoryExists(at: directory) else {
                scoped.stopAccessingSecurityScopedResource()
                return nil
            }
        return ResolvedTarget(
            fileURL: targetFileURL(in: directory, fileName: item.fileName, downloadID: item.id),
            scopedDirectoryURL: scoped
        )
        }

        let directory: URL
        if let savePath = item.saveDirectoryPath {
            directory = URL(fileURLWithPath: savePath, isDirectory: true).resolvingSymlinksInPath()
        } else {
            directory = preferredDefaultDirectory()
        }
        guard ensureDirectoryExists(at: directory) else { return nil }
        return ResolvedTarget(
            fileURL: targetFileURL(in: directory, fileName: item.fileName, downloadID: item.id),
            scopedDirectoryURL: nil
        )
    }

    static func preferredDefaultDirectory() -> URL {
        AppSettings.shared.resolvedDefaultSaveDirectory() ?? defaultDownloadsDirectory()
    }

    static func targetFileURL(in directory: URL, fileName: String, downloadID: UUID? = nil) -> URL {
        let policy: DestinationConflictPolicy
        if let downloadID {
            policy = DownloadManager.shared.effectiveConflictPolicy(for: downloadID)
        } else {
            policy = AppSettings.shared.conflictPolicy
        }
        return HTTPHeaderHelper.targetFileURL(
            in: directory,
            fileName: fileName,
            policy: policy
        )
    }

    static func defaultDownloadsDirectory() -> URL {
        let fileManager = FileManager.default
        let raw = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        let resolved = raw.resolvingSymlinksInPath()
        logger.info("Using Downloads folder: \(resolved.path, privacy: .public)")
        return resolved
    }

    private static func ensureDirectoryExists(at url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            logger.error("Cannot create directory \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
