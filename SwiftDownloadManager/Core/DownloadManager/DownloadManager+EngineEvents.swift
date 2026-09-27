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

        let eventID: UUID = switch event {
        case .progress(let id, _, _): id
        case .segmentProgress(let id, _, _): id
        case .segmentsUpdated(let id, _): id
        case .paused(let id, _, _, _): id
        case .completed(let id, _): id
        case .failed(let id, _, _, _): id
        case .restartedAsSingleStream(let id, _): id
        }

        guard !sessions.shouldIgnoreEvents(for: eventID) else { return }

        switch event {
        case .progress(let id, let bytesReceived, let bytesTotal):
            noteProgress(for: id)
            let item = activeDownloadItems[id] ?? fetchItem(id: id)
            if let item {
                if activeDownloadItems[id] == nil {
                    activeDownloadItems[id] = item
                }
                // Live values go to the in-memory tracker; SwiftData is only
                // touched at flush cadence to avoid store churn per chunk.
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

        case .segmentProgress(let id, let segmentIndex, let bytesReceived):
            noteProgress(for: id)
            segmentProgressCache[id, default: [:]][segmentIndex] = bytesReceived

        case .segmentsUpdated(let id, let segmentInfos):
            let item = activeDownloadItems[id] ?? fetchItem(id: id)
            if let item {
                if activeDownloadItems[id] == nil {
                    activeDownloadItems[id] = item
                }
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
                metricsTracker(for: id).update(
                    bytesReceived: item.bytesReceived,
                    bytesTotal: item.bytesTotal,
                    connections: activeConnectionCount(for: item)
                )
            }

        case .paused(let id, let segments, let bytesReceived, let bytesTotal):
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
                var existingByIndex: [Int: DownloadSegment] = [:]
                for seg in item.segments {
                    existingByIndex[seg.index] = seg
                }
                for segmentInfo in segments {
                    if let segment = existingByIndex[segmentInfo.index] {
                        segment.startOffset = segmentInfo.startOffset
                        segment.endOffset = segmentInfo.endOffset
                        segment.bytesReceived = segmentInfo.bytesReceived
                        segment.isCompleted = segmentInfo.isCompleted
                    } else {
                        let newSegment = DownloadSegment(
                            index: segmentInfo.index,
                            startOffset: segmentInfo.startOffset,
                            endOffset: segmentInfo.endOffset,
                            bytesReceived: segmentInfo.bytesReceived,
                            isCompleted: segmentInfo.isCompleted
                        )
                        newSegment.downloadItem = item
                        item.segments.append(newSegment)
                    }
                }
            }
            saveNow()
            processQueue()

        case .completed(let id, let localURL):
            sessions.endDownloading(id)
            releaseScopedDirectory(for: id)
            activeDownloadItems.removeValue(forKey: id)
            let cachedProgress = progressCache[id]
            clearProgressCache(for: id)
            if let item = fetchItem(id: id) {
                item.status = .completed
                item.completedAt = Date()
                finalizeCompletedByteCounts(
                    for: item,
                    localURL: localURL,
                    cachedProgress: cachedProgress
                )
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
            // Bound the tracker dictionary; persisted history stays on the item.
            metricsTrackers.removeValue(forKey: id)
            saveNow()
            processQueue()
            checkQueueCompletionAction()

        case .failed(let id, let error, let segments, let bytesReceived):
            sessions.endDownloading(id)
            releaseScopedDirectory(for: id)
            activeDownloadItems.removeValue(forKey: id)
            if let item = fetchItem(id: id) {
                item.status = .failed
                item.errorMessage = error.localizedDescription
                if bytesReceived > 0 {
                    item.bytesReceived = bytesReceived
                }
                var existingByIndex: [Int: DownloadSegment] = [:]
                for seg in item.segments {
                    existingByIndex[seg.index] = seg
                }
                for segmentInfo in segments {
                    if let segment = existingByIndex[segmentInfo.index] {
                        segment.startOffset = segmentInfo.startOffset
                        segment.endOffset = segmentInfo.endOffset
                        segment.bytesReceived = segmentInfo.bytesReceived
                        segment.isCompleted = segmentInfo.isCompleted
                    } else {
                        let newSegment = DownloadSegment(
                            index: segmentInfo.index,
                            startOffset: segmentInfo.startOffset,
                            endOffset: segmentInfo.endOffset,
                            bytesReceived: segmentInfo.bytesReceived,
                            isCompleted: segmentInfo.isCompleted
                        )
                        newSegment.downloadItem = item
                        item.segments.append(newSegment)
                    }
                }
                clearProgressCache(for: id)
                persistSpeedHistory(for: item, tracker: metricsTracker(for: id))
                metricsTracker(for: id).reset()
                NotificationService.postDownloadFailed(fileName: item.fileName, message: error.localizedDescription)
                logger.error("Download failed \(item.fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                clearProgressCache(for: id)
            }
            metricsTrackers.removeValue(forKey: id)
            saveNow()
            processQueue()

        case .restartedAsSingleStream(let id, let bytesTotal):
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

        refreshAggregateDisplaySpeed()
        scheduleSave()
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
