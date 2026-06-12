import Foundation

enum DestinationConflictResolver {
    struct Preview {
        let directory: URL
        let resolvedFileName: String
        let willRename: Bool
    }

    static func preview(
        for item: DownloadItem,
        fileName: String,
        policy override: DestinationConflictPolicy? = nil
    ) -> Preview? {
        let directory: URL
        if let path = item.saveDirectoryPath {
            directory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            directory = DownloadPathResolver.preferredDefaultDirectory()
        }

        let sanitized = FileNameSanitizer.sanitize(fileName)
        let policy = override ?? DownloadManager.shared.effectiveConflictPolicy(for: item.id)
        let target = HTTPHeaderHelper.targetFileURL(in: directory, fileName: sanitized, policy: policy)
        let willRename = target.lastPathComponent != sanitized

        return Preview(
            directory: directory,
            resolvedFileName: target.lastPathComponent,
            willRename: willRename
        )
    }

    static func fileExists(for item: DownloadItem, fileName: String) -> Bool {
        let directory: URL
        if let path = item.saveDirectoryPath {
            directory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            directory = DownloadPathResolver.preferredDefaultDirectory()
        }
        let sanitized = FileNameSanitizer.sanitize(fileName)
        let candidate = directory.appendingPathComponent(sanitized)
        return FileManager.default.fileExists(atPath: candidate.path)
    }

    @MainActor
    static func message(for preview: Preview) -> String? {
        guard preview.willRename else { return nil }
        return L10n.t(
            de: "Wird gespeichert als „\(preview.resolvedFileName)“",
            en: "Will be saved as \"\(preview.resolvedFileName)\""
        )
    }
}
