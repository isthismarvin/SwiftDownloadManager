import Foundation
import SwiftData
import os

extension DownloadManager {
    func friendlyNetworkMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return L10n.t(
                    de: "Server nicht gefunden. Überprüfe die URL — der Host ist möglicherweise offline oder falsch geschrieben.",
                    en: "Server not found. Check the URL — the host may be offline or misspelled."
                )
            case NSURLErrorNotConnectedToInternet:
                return L10n.t(de: "Keine Internetverbindung.", en: "No internet connection.")
            case NSURLErrorTimedOut:
                return L10n.t(de: "Verbindung abgelaufen.", en: "Connection timed out.")
            case NSURLErrorCannotConnectToHost:
                return L10n.t(de: "Verbindung zum Server nicht möglich.", en: "Cannot connect to server.")
            default:
                break
            }
        }
        return error.localizedDescription
    }

    func releaseScopedDirectory(for id: UUID) {
        if let url = scopedDirectories.removeValue(forKey: id) {
            url.stopAccessingSecurityScopedResource()
        }
    }

    /// Removes the partially downloaded file of a non-completed item. The engine
    /// only cleans up files of *active* downloads; paused/failed partials would
    /// otherwise be orphaned on disk.
    func removePartialFile(of item: DownloadItem) {
        guard item.status != .completed, let path = item.localFilePath else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    func fetchItem(id: UUID) -> DownloadItem? {
        guard let modelContext = modelContext else { return nil }
        // Copy into a local constant first — #Predicate cannot reference the
        // parameter directly without miscompiling. This replaces the previous
        // full-table scan per event.
        let targetID = id
        var descriptor = FetchDescriptor<DownloadItem>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        return ((try? modelContext.fetch(descriptor)) ?? []).first
    }

    func fetchAllItemsForUI() -> [DownloadItem] {
        guard let modelContext = modelContext else { return [] }
        let descriptor = FetchDescriptor<DownloadItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func recordHistory(for item: DownloadItem, outcome: HistoryOutcome) {
        guard let modelContext = modelContext else { return }
        let entry = HistoryEntry(
            fileName: item.fileName,
            urlString: item.urlString,
            bytesTotal: item.bytesTotal,
            finishedAt: Date(),
            outcome: outcome
        )
        modelContext.insert(entry)
        pruneHistory(olderThanDays: AppSettings.shared.historyRetentionDays)
    }

    // MARK: - Throttled Save

    func scheduleSave() {
        pendingSave = true
        // Do not cancel-and-recreate the task per event: a steady event stream
        // would push the save out indefinitely and lose all progress on a crash.
        // One task per window guarantees a flush at least every 2 seconds.
        guard saveDebounceTask == nil else { return }
        saveDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            self.saveDebounceTask = nil
            self.flushSaveIfNeeded()
        }
    }

    func flushSaveIfNeeded() {
        guard pendingSave else { return }
        pendingSave = false
        applyProgressCaches()
        do {
            try modelContext?.save()
        } catch {
            logger.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveNow() {
        pendingSave = false
        saveDebounceTask?.cancel()
        saveDebounceTask = nil
        applyProgressCaches()
        do {
            try modelContext?.save()
        } catch {
            logger.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func persistSpeedHistory(for item: DownloadItem, tracker: DownloadMetricsTracker) {
        let samples = tracker.exportSamples()
        item.speedHistoryJSON = SpeedHistoryStore.encode(samples)
    }

    func clearProgressCache(for id: UUID) {
        progressCache.removeValue(forKey: id)
        segmentProgressCache.removeValue(forKey: id)
    }

    /// Ensures completed downloads show the real file size even when live
    /// progress lived only in `progressCache` or the server sent no Content-Length.
    func finalizeCompletedByteCounts(
        for item: DownloadItem,
        localURL: URL,
        cachedProgress: (received: Int64, total: Int64)?
    ) {
        if let cachedProgress {
            if cachedProgress.received > 0 {
                item.bytesReceived = cachedProgress.received
            }
            if cachedProgress.total > 0 {
                item.bytesTotal = cachedProgress.total
            }
        }

        let fileSize = fileByteCount(at: localURL)
        if fileSize > 0 {
            item.bytesReceived = fileSize
            if item.bytesTotal <= 0 {
                item.bytesTotal = fileSize
            }
        } else if item.bytesTotal > 0, item.bytesReceived <= 0 {
            item.bytesReceived = item.bytesTotal
        } else if item.bytesTotal > 0, item.bytesReceived < item.bytesTotal {
            item.bytesReceived = item.bytesTotal
        }
    }

    /// Ensures every segment reflects a full download after successful completion.
    func finalizeCompletedSegments(for item: DownloadItem) {
        for segment in item.segments {
            segment.isCompleted = true
            let capacity = segment.byteCapacity(bytesTotal: item.bytesTotal)
            if capacity > 0 {
                segment.bytesReceived = capacity
            }
        }
    }

    func fileByteCount(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.int64Value
    }

    /// Writes the in-memory progress into the SwiftData models. Called right
    /// before every save so the store lags live values by at most one flush.
    func applyProgressCaches() {
        guard !progressCache.isEmpty || !segmentProgressCache.isEmpty else { return }

        let ids = Set(progressCache.keys).union(segmentProgressCache.keys)
        for id in ids {
            guard let item = fetchItem(id: id) else { continue }
            if let progress = progressCache[id] {
                item.bytesReceived = progress.received
                if progress.total > 0 {
                    item.bytesTotal = progress.total
                }
            }
            if let segmentBytes = segmentProgressCache[id] {
                for segment in item.segments {
                    guard let bytes = segmentBytes[segment.index] else { continue }
                    segment.bytesReceived = bytes
                    if segment.endOffset != -1,
                       bytes >= (segment.endOffset - segment.startOffset + 1) {
                        segment.isCompleted = true
                    }
                }
            }
        }
        progressCache.removeAll()
        segmentProgressCache.removeAll()
    }
}
