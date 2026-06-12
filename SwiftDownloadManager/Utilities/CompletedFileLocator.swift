import Foundation

enum CompletedFileState: Equatable {
    case available(URL)
    case missing(storedPath: String?)
    case unknown
}

enum CompletedFileLocator {
    /// Resolves the on-disk location, updating `localFilePath` and the bookmark when needed.
    @discardableResult
    static func resolve(into item: DownloadItem) -> CompletedFileState {
        if let bookmark = item.localFileBookmark,
           let resolved = BookmarkHelper.resolveFileBookmark(bookmark) {
            defer { BookmarkHelper.stopAccessing(resolved.url) }
            let url = resolved.url.standardizedFileURL

            if FileManager.default.fileExists(atPath: url.path) {
                if item.localFilePath != url.path {
                    item.localFilePath = url.path
                }
                if resolved.isStale, let refreshed = BookmarkHelper.createFileBookmark(for: url) {
                    item.localFileBookmark = refreshed
                }
                return .available(url)
            }
            return .missing(storedPath: item.localFilePath)
        }

        if let path = item.localFilePath, !path.isEmpty {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            if FileManager.default.fileExists(atPath: url.path) {
                if item.localFileBookmark == nil {
                    item.localFileBookmark = BookmarkHelper.createFileBookmark(for: url)
                }
                return .available(url)
            }
            return .missing(storedPath: path)
        }

        return .unknown
    }
}
