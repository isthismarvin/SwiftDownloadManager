import Foundation
import SwiftData

extension DownloadManager {
    // MARK: - Folders

    func createFolder(name: String) -> DownloadFolder? {
        guard let modelContext = modelContext else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let folder = DownloadFolder(name: trimmed)
        modelContext.insert(folder)
        saveNow()
        return folder
    }

    func renameFolder(_ folder: DownloadFolder, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folder.name = trimmed
        saveNow()
    }

    func deleteFolder(_ folder: DownloadFolder) {
        guard let modelContext = modelContext else { return }
        for item in folder.downloads {
            item.folder = nil
        }
        modelContext.delete(folder)
        saveNow()
    }

    func fetchFolders() -> [DownloadFolder] {
        guard let modelContext = modelContext else { return [] }
        let descriptor = FetchDescriptor<DownloadFolder>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - History

    func fetchHistory() -> [HistoryEntry] {
        guard let modelContext = modelContext else { return [] }
        let descriptor = FetchDescriptor<HistoryEntry>(
            sortBy: [SortDescriptor(\.finishedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func clearHistory() {
        guard let modelContext = modelContext else { return }
        let descriptor = FetchDescriptor<HistoryEntry>()
        guard let entries = try? modelContext.fetch(descriptor) else { return }
        for entry in entries {
            modelContext.delete(entry)
        }
        saveNow()
    }

    func reDownload(from entry: HistoryEntry) {
        guard let url = URL(string: entry.urlString) else { return }
        addDownload(url: url, fileNameOverride: entry.fileName)
    }

    // MARK: - Queue

    func processQueue() {
        guard modelContext != nil else { return }

        let activeCount = sessions.activeCount
        NotificationService.updateDockBadge(activeCount: activeCount)
        applyFairBandwidthSharing()
        guard activeCount < AppSettings.shared.maxConcurrentDownloads else { return }

        let descriptor = FetchDescriptor<DownloadItem>()
        guard let allItems = try? modelContext?.fetch(descriptor) else { return }

        let queuedItems = allItems
            .filter {
                $0.status == .queued
                    && !$0.holdInQueue
                    && !isDeferredStart($0)
                    && !sessions.shouldIgnoreEvents(for: $0.id)
                    && !sessions.isActive($0.id)
            }
            .sorted { $0.createdAt < $1.createdAt }

        let slots = AppSettings.shared.maxConcurrentDownloads - activeCount
        for item in queuedItems.prefix(slots) {
            beginDownload(id: item.id)
        }
    }

    func sortedDownloads(_ downloads: [DownloadItem]) -> [DownloadItem] {
        let order = AppSettings.shared.sortOrder
        let ascending = AppSettings.shared.sortAscending
        return downloads.sorted { lhs, rhs in
            let goesBefore = compareDownloads(lhs, rhs, by: order)
            return ascending ? goesBefore : !goesBefore
        }
    }

    private func compareDownloads(_ lhs: DownloadItem, _ rhs: DownloadItem, by order: DownloadSortOrder) -> Bool {
        switch order {
        case .dateAdded:
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
        case .name:
            let nameOrder = lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return lhs.createdAt < rhs.createdAt
        case .progress:
            let left = progressSortValue(for: lhs)
            let right = progressSortValue(for: rhs)
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        case .speed:
            let left = speedSortValue(for: lhs)
            let right = speedSortValue(for: rhs)
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        case .status:
            let left = statusSortRank(lhs.status)
            let right = statusSortRank(rhs.status)
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        case .size:
            let left = max(lhs.bytesTotal, lhs.bytesReceived)
            let right = max(rhs.bytesTotal, rhs.bytesReceived)
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        case .eta:
            let left = etaSortValue(for: lhs)
            let right = etaSortValue(for: rhs)
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private func progressSortValue(for item: DownloadItem) -> Double {
        let total = item.bytesTotal
        guard total > 0 else { return 0 }
        let received = liveBytesReceived(for: item)
        return Double(received) / Double(total)
    }

    private func speedSortValue(for item: DownloadItem) -> Double {
        guard item.status == .downloading else { return -1 }
        return metricsTracker(for: item.id).currentSpeed
    }

    private func etaSortValue(for item: DownloadItem) -> TimeInterval {
        guard item.status == .downloading, item.bytesTotal > 0 else { return .infinity }
        let remaining = item.bytesTotal - liveBytesReceived(for: item)
        return metricsTracker(for: item.id).eta(remainingBytes: remaining) ?? .infinity
    }

    private func liveBytesReceived(for item: DownloadItem) -> Int64 {
        if item.status == .downloading {
            let live = metricsTracker(for: item.id).liveBytesReceived
            if live > 0 { return live }
        }
        return item.bytesReceived
    }

    private func statusSortRank(_ status: DownloadStatus) -> Int {
        switch status {
        case .downloading: return 0
        case .queued, .received, .pendingConfirmation: return 1
        case .paused: return 2
        case .completed: return 3
        case .failed: return 4
        case .cancelled: return 5
        }
    }
}
