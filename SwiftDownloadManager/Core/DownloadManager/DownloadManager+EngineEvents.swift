import Foundation
import SwiftData
import os

extension DownloadManager {
    // MARK: - Engine Events

    func startListeningToEngineEvents() {
        guard !isListeningToEngine else { return }
        isListeningToEngine = true

        Task { @MainActor in
            for await event in engine.eventStream {
                handleEngineEvent(event)
            }
        }
    }

    func handleEngineEvent(_ event: DownloadEvent) {
        guard modelContext != nil else { return }
        guard !sessions.shouldIgnoreEvents(for: event.downloadID) else { return }

        switch event {
        case let .progress(id, bytesReceived, bytesTotal):
            handleProgressEvent(id: id, bytesReceived: bytesReceived, bytesTotal: bytesTotal)
        case let .segmentProgress(id, segmentIndex, bytesReceived):
            handleSegmentProgressEvent(id: id, segmentIndex: segmentIndex, bytesReceived: bytesReceived)
        case let .segmentsUpdated(id, segmentInfos):
            handleSegmentsUpdatedEvent(id: id, segmentInfos: segmentInfos)
        case let .paused(id, segments, bytesReceived, bytesTotal):
            handlePausedEvent(id: id, segments: segments, bytesReceived: bytesReceived, bytesTotal: bytesTotal)
        case let .completed(id, localURL):
            handleCompletedEvent(id: id, localURL: localURL)
        case let .failed(id, error, segments, bytesReceived):
            handleFailedEvent(id: id, error: error, segments: segments, bytesReceived: bytesReceived)
        case let .restartedAsSingleStream(id, bytesTotal):
            handleRestartedAsSingleStreamEvent(id: id, bytesTotal: bytesTotal)
        }

        refreshAggregateDisplaySpeed()
        scheduleSave()
    }

    private func handleProgressEvent(id: UUID, bytesReceived: Int64, bytesTotal: Int64) {
        noteProgress(for: id)
        guard let item = activeDownloadItems[id] ?? fetchItem(id: id) else { return }
        if activeDownloadItems[id] == nil {
            activeDownloadItems[id] = item
        }
        progressCache[id] = (bytesReceived, bytesTotal)
        if item.status != .downloading {
            item.status = .downloading
        }
        metricsTracker(for: id).update(
            bytesReceived: bytesReceived,
            bytesTotal: bytesTotal > 0 ? bytesTotal : item.bytesTotal,
            connections: activeConnectionCount(for: item)
        )
    }

    private func handleSegmentProgressEvent(id: UUID, segmentIndex: Int, bytesReceived: Int64) {
        noteProgress(for: id)
        segmentProgressCache[id, default: [:]][segmentIndex] = bytesReceived
    }

    private func handleSegmentsUpdatedEvent(id: UUID, segmentInfos: [SegmentInfo]) {
        guard let item = activeDownloadItems[id] ?? fetchItem(id: id) else { return }
        if activeDownloadItems[id] == nil {
            activeDownloadItems[id] = item
        }
        upsertSegments(into: item, from: segmentInfos)
        metricsTracker(for: id).update(
            bytesReceived: item.bytesReceived,
            bytesTotal: item.bytesTotal,
            connections: activeConnectionCount(for: item)
        )
    }

    private func handlePausedEvent(id: UUID, segments: [SegmentInfo], bytesReceived: Int64, bytesTotal: Int64) {
        sessions.endDownloading(id)
        releaseScopedDirectory(for: id)
        activeDownloadItems.removeValue(forKey: id)
        clearProgressCache(for: id)
        if let item = fetchItem(id: id) {
            item.status = .paused
            item.bytesReceived = bytesReceived
            if bytesTotal > 0 {
                item.bytesTotal = bytesTotal
            }
            upsertSegments(into: item, from: segments)
        }
        saveNow()
        processQueue()
    }

    private func handleCompletedEvent(id: UUID, localURL: URL) {
        sessions.endDownloading(id)
        releaseScopedDirectory(for: id)
        activeDownloadItems.removeValue(forKey: id)
        let cachedProgress = progressCache[id]
        clearProgressCache(for: id)
        if let item = fetchItem(id: id) {
            item.status = .completed
            item.completedAt = Date()
            finalizeCompletedByteCounts(for: item, localURL: localURL, cachedProgress: cachedProgress)
            finalizeCompletedSegments(for: item)
            attachFileLocation(to: item, fileURL: localURL)
            recordIntelligenceAfterCompletion(item)
            recordHistory(for: item, outcome: .completed)

            let targetID = id
            let targetFileURL = localURL
            Task.detached(priority: .utility) {
                if let sha = try? await FileChecksumService.computeSHA256(for: targetFileURL) {
                    await MainActor.run {
                        if let completedItem = DownloadManager.shared.fetchItem(id: targetID) {
                            completedItem.sha256Checksum = sha
                            DownloadManager.shared.saveNow()
                        }
                    }
                }
            }
            metricsTracker(for: id).update(
                bytesReceived: item.bytesReceived,
                bytesTotal: item.bytesTotal,
                connections: 0
            )
            NotificationService.postDownloadCompleted(fileName: item.fileName)
            enqueueCompletionDialog(id: id)
            logger.info("Completed download \(item.fileName, privacy: .public)")
            persistSpeedHistory(for: item, tracker: metricsTracker(for: id))
        }
        metricsTrackers.removeValue(forKey: id)
        saveNow()
        processQueue()
        checkQueueCompletionAction()
    }

    private func handleFailedEvent(id: UUID, error: Error, segments: [SegmentInfo], bytesReceived: Int64) {
        sessions.endDownloading(id)
        releaseScopedDirectory(for: id)
        activeDownloadItems.removeValue(forKey: id)
        if let item = fetchItem(id: id) {
            item.status = .failed
            let nsError = error as NSError
            if nsError.code == 401 {
                item.errorMessage = L10n.t(
                    de: "HTTP 401: Authentifizierung erforderlich (Site Login hinterlegen)",
                    en: "HTTP 401: Authentication required (Add Site Login in Settings)"
                )
            } else {
                item.errorMessage = error.localizedDescription
            }
            if bytesReceived > 0 {
                item.bytesReceived = bytesReceived
            }
            upsertSegments(into: item, from: segments)
            clearProgressCache(for: id)
            persistSpeedHistory(for: item, tracker: metricsTracker(for: id))
            metricsTracker(for: id).reset()
            NotificationService.postDownloadFailed(fileName: item.fileName, message: error.localizedDescription)
            logger.error(
                "Download failed \(item.fileName, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        } else {
            clearProgressCache(for: id)
        }
        metricsTrackers.removeValue(forKey: id)
        saveNow()
        processQueue()
    }

    private func handleRestartedAsSingleStreamEvent(id: UUID, bytesTotal: Int64) {
        clearProgressCache(for: id)
        if let item = fetchItem(id: id) {
            item.supportsResume = false
            item.bytesReceived = 0
            if bytesTotal > 0 {
                item.bytesTotal = bytesTotal
            }
            let oldSegments = item.segments
            item.segments = []
            for segment in oldSegments {
                modelContext?.delete(segment)
            }
            let end = bytesTotal > 0 ? bytesTotal - 1 : Int64(-1)
            item.segments = [DownloadSegment(index: 0, startOffset: 0, endOffset: end)]
            persistSpeedHistory(for: item, tracker: metricsTracker(for: id))
            metricsTracker(for: id).reset()
            logger.info("Server ignored range request — restarted \(item.fileName, privacy: .public) as single stream")
        }
        saveNow()
    }

    private func upsertSegments(into item: DownloadItem, from segmentInfos: [SegmentInfo]) {
        var existingByIndex: [Int: DownloadSegment] = [:]
        for seg in item.segments {
            existingByIndex[seg.index] = seg
        }
        for info in segmentInfos {
            if let existing = existingByIndex[info.index] {
                existing.startOffset = info.startOffset
                existing.endOffset = info.endOffset
                existing.bytesReceived = info.bytesReceived
                existing.isCompleted = info.isCompleted
            } else {
                let newSegment = DownloadSegment(
                    index: info.index,
                    startOffset: info.startOffset,
                    endOffset: info.endOffset,
                    bytesReceived: info.bytesReceived,
                    isCompleted: info.isCompleted
                )
                newSegment.downloadItem = item
                item.segments.append(newSegment)
            }
        }
    }

    func activeConnectionCount(for item: DownloadItem) -> Int {
        guard item.status == .downloading else { return 0 }
        if item.segments.isEmpty {
            return item.preferredSegmentsCount
        }
        let active = item.segments.filter { !$0.isCompleted }.count
        return max(active, 1)
    }

    func checkQueueCompletionAction() {
        guard AppSettings.shared.onQueueCompleteAction != .doNothing else { return }
        guard sessions.activeCount == 0 else { return }
        guard let modelContext else { return }
        var descriptor = FetchDescriptor<DownloadItem>()
        descriptor.predicate = #Predicate<DownloadItem> { $0.statusRaw == "queued" || $0.statusRaw == "downloading" }
        descriptor.fetchLimit = 1
        let remaining = (try? modelContext.fetch(descriptor)) ?? []
        if remaining.isEmpty {
            SystemPowerHelper.executeOnQueueCompleteAction()
        }
    }
}
