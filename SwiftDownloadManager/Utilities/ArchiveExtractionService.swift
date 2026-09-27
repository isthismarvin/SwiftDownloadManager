import Foundation
import AppKit

enum ArchiveExtractionService {
    private static let archiveExtensions: Set<String> = [
        "zip", "tar", "gz", "tgz", "bz2", "tbz", "xz", "7z", "rar"
    ]

    /// Checks whether the given file or URL has a supported archive extension.
    static func isArchive(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if archiveExtensions.contains(ext) { return true }
        if url.lastPathComponent.lowercased().hasSuffix(".tar.gz") { return true }
        return false
    }

    /// Extracts an archive to a destination folder, optionally moving the original archive to Trash.
    @discardableResult
    static func extractArchive(
        at sourceURL: URL,
        destination: URL? = nil,
        trashOriginal: Bool = false
    ) -> URL? {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }

        let targetDir: URL
        if let destination = destination {
            targetDir = destination
        } else {
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let parent = sourceURL.deletingLastPathComponent()
            targetDir = parent.appendingPathComponent(baseName, isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension.lowercased()
        let isTar = ext == "tar" || ext == "tgz" || ext == "gz" || sourceURL.lastPathComponent.hasSuffix(".tar.gz")

        var success = false

        if isTar {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            proc.arguments = ["-xf", sourceURL.path, "-C", targetDir.path]
            do {
                try proc.run()
                proc.waitUntilExit()
                success = proc.terminationStatus == 0
            } catch {
                success = false
            }
        } else {
            // For zip and other archives, ditto is the native macOS standard
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            proc.arguments = ["-x", "-k", sourceURL.path, targetDir.path]
            do {
                try proc.run()
                proc.waitUntilExit()
                success = proc.terminationStatus == 0
            } catch {
                success = false
            }
        }

        if !success {
            // Sandboxed fallback: Open with macOS Archive Utility
            NSWorkspace.shared.open(sourceURL)
            return targetDir
        }

        if trashOriginal {
            try? FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)
        }

        NSWorkspace.shared.activateFileViewerSelecting([targetDir])
        return targetDir
    }
}
