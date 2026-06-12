import Foundation
import SwiftData

extension DownloadManager {
    func attachFileLocation(to item: DownloadItem, fileURL: URL) {
        let url = fileURL.standardizedFileURL
        item.localFilePath = url.path
        item.localFileBookmark = BookmarkHelper.createFileBookmark(for: url)
        FileLocationMonitor.shared.apply(state: .available(url), for: item.id)
    }

    @discardableResult
    func reconcileFileLocation(for id: UUID) -> Bool {
        guard let item = fetchItem(id: id), item.status == .completed else { return false }

        let beforePath = item.localFilePath
        let beforeMissing = FileLocationMonitor.shared.isMissing(id: id)
        let state = CompletedFileLocator.resolve(into: item)
        FileLocationMonitor.shared.apply(state: state, for: id)

        let afterMissing = FileLocationMonitor.shared.isMissing(id: id)
        return beforePath != item.localFilePath || beforeMissing != afterMissing
    }

    func reconcileAllCompletedFileLocations() {
        guard let modelContext else { return }

        let descriptor = FetchDescriptor<DownloadItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }

        let completed = items.filter { $0.status == .completed }
        var changed = false
        for item in completed {
            if reconcileFileLocation(for: item.id) {
                changed = true
            }
        }
        FileLocationMonitor.shared.rebuildWatchList(for: completed)
        if changed {
            saveNow()
        }
    }

    func noteFileExternallyRelocated(id: UUID) {
        Task { @MainActor [weak self] in
            // Finder finishes move/copy slightly after the drag session ends.
            try? await Task.sleep(for: .milliseconds(500))
            guard let self else { return }
            if self.reconcileFileLocation(for: id) {
                self.saveNow()
            }
        }
    }
}
