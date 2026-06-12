import AppKit

enum FinderHelper {
    @MainActor
    static func openDefaultSaveDirectory() {
        let settings = AppSettings.shared
        if let bookmark = settings.defaultSaveDirectoryBookmark,
           let url = BookmarkHelper.resolveBookmark(bookmark) {
            defer { BookmarkHelper.stopAccessing(url) }
            NSWorkspace.shared.open(url.resolvingSymlinksInPath())
        } else {
            NSWorkspace.shared.open(DownloadPathResolver.defaultDownloadsDirectory())
        }
    }
}
