import AppKit
import Foundation
import SwiftData
import os

extension DownloadManager {
    func startDownload(id: UUID) {
        resumeDownload(id: id)
    }

    func resumeDownload(id: UUID) {
        guard let item = fetchItem(id: id) else {
            logger.warning("resumeDownload: item not found \(id.uuidString, privacy: .public)")
            return
        }
        guard item.status == .paused || item.status == .failed || item.status == .cancelled || item.status == .queued else { return }

        sessions.unmarkCancelled(id)
        item.status = .queued
        item.errorMessage = nil
        item.holdInQueue = false
        item.scheduledStartAt = nil
        item.startWhenOnWiFi = false
        saveNow()
        logger.info("Resumed download \(item.fileName, privacy: .public)")
        processQueue()
    }

    func pauseDownload(id: UUID) {
        guard let item = fetchItem(id: id) else { return }

        switch item.status {
        case .downloading:
            engine.pauseDownload(id: id)
        case .queued:
            cancelPrepareDownload(for: id)
            sessions.endDownloading(id)
            item.status = .paused
            saveNow()
        default:
            break
        }
        processQueue()
    }

    func cancelDownload(id: UUID) {
        guard let item = fetchItem(id: id) else { return }

        sessions.markCancelled(id)
        cancelMetadataProbe(for: id)
        cancelPrepareDownload(for: id)
        engine.cancelDownload(id: id)

        // The engine only removes files of active downloads — clean up
        // paused/failed partials here as well.
        removePartialFile(of: item)
        releaseScopedDirectory(for: id)

        recordHistory(for: item, outcome: .cancelled)
        item.status = .cancelled
        item.errorMessage = nil
        item.bytesReceived = 0
        item.localFilePath = nil
        item.localFileBookmark = nil
        for segment in item.segments {
            segment.bytesReceived = 0
            segment.isCompleted = false
        }
        metricsTrackers[id]?.reset()
        saveNow()
        logger.info("Cancelled download \(item.fileName, privacy: .public)")
        processQueue()
    }

    func deleteDownload(item: DownloadItem) {
        deleteDownload(id: item.id)
    }

    func deleteDownload(id: UUID) {
        guard let modelContext = modelContext else { return }
        guard let item = fetchItem(id: id) else { return }

        sessions.markDeleted(id)
        cancelMetadataProbe(for: id)
        cancelPrepareDownload(for: id)

        if item.status == .completed {
            recordHistory(for: item, outcome: .deleted)
        } else if item.status != .cancelled {
            recordHistory(for: item, outcome: .cancelled)
        }

        engine.cancelDownload(id: id, removeFile: true)
        removePartialFile(of: item)
        releaseScopedDirectory(for: id)
        metricsTrackers.removeValue(forKey: id)
        conflictPolicyOverrides.removeValue(forKey: id)

        modelContext.delete(item)
        saveNow()
        logger.info("Deleted download \(item.fileName, privacy: .public)")
        processQueue()
    }

    func pauseAll() {
        guard let modelContext = modelContext else { return }
        let descriptor = FetchDescriptor<DownloadItem>()
        guard let allItems = try? modelContext.fetch(descriptor) else { return }

        for item in allItems where item.status == .downloading || item.status == .queued {
            if item.status == .downloading {
                engine.pauseDownload(id: item.id)
            } else {
                cancelPrepareDownload(for: item.id)
                sessions.endDownloading(item.id)
                item.status = .paused
            }
        }
        saveNow()
        processQueue()
    }

    func resumeAll() {
        guard let modelContext = modelContext else { return }
        let descriptor = FetchDescriptor<DownloadItem>()
        guard let allItems = try? modelContext.fetch(descriptor) else { return }

        for item in allItems where item.status == .paused || item.status == .failed {
            sessions.unmarkCancelled(item.id)
            item.status = .queued
            item.errorMessage = nil
        }
        saveNow()
        processQueue()
    }

    func clearCompleted() {
        guard let modelContext = modelContext else { return }
        let descriptor = FetchDescriptor<DownloadItem>()
        guard let allItems = try? modelContext.fetch(descriptor) else { return }

        for item in allItems where item.status == .completed {
            recordHistory(for: item, outcome: .deleted)
            metricsTrackers.removeValue(forKey: item.id)
            modelContext.delete(item)
        }
        saveNow()
    }

    func moveDownload(_ item: DownloadItem, to folder: DownloadFolder?) {
        item.folder = folder
        saveNow()
    }

    // MARK: - Download Lifecycle

    func beginDownload(id: UUID) {
        guard !sessions.isActive(id) else { return }
        guard !sessions.shouldIgnoreEvents(for: id) else { return }
        guard let item = fetchItem(id: id), item.status == .queued else { return }

        guard let url = URL(string: item.urlString) else {
            item.status = .failed
            item.errorMessage = L10n.t(de: "Ungültige URL", en: "Invalid URL")
            saveNow()
            processQueue()
            return
        }

        lastProgressAt[id] = Date()
        sessions.beginPreparing(id)
        enqueuePrepareDownload(id: id, url: url)
    }

    func prepareAndStartDownload(id: UUID, url: URL, generation: UInt64) async {
        defer {
            clearPrepareDownloadTaskIfCurrent(id: id, generation: generation)
        }

        guard !Task.isCancelled, !sessions.shouldIgnoreEvents(for: id) else {
            sessions.endPreparing(id)
            processQueue()
            return
        }

        guard let item = fetchItem(id: id), item.status == .queued else {
            sessions.endPreparing(id)
            processQueue()
            return
        }

        if item.segments.isEmpty || item.bytesTotal <= 0 {
            switch await DownloadProbeService.probe(url: url, headers: item.requestHeaders) {
            case .networkError(let error):
                sessions.endPreparing(id)
                guard !Task.isCancelled, !sessions.shouldIgnoreEvents(for: id),
                      let currentItem = fetchItem(id: id),
                      currentItem.status == .queued else {
                    processQueue()
                    return
                }
                currentItem.status = .failed
                currentItem.errorMessage = friendlyNetworkMessage(for: error)
                saveNow()
                logger.error("Probe aborted download: \(currentItem.errorMessage ?? "", privacy: .public)")
                processQueue()
                return

            case .success(let probeResult):
                guard !Task.isCancelled, !sessions.shouldIgnoreEvents(for: id),
                      let currentItem = fetchItem(id: id),
                      currentItem.status == .queued else {
                    sessions.endPreparing(id)
                    processQueue()
                    return
                }
                applyProbeResult(probeResult, to: currentItem, url: url)
                scheduleSave()

            case .inconclusive:
                guard !Task.isCancelled, !sessions.shouldIgnoreEvents(for: id),
                      let currentItem = fetchItem(id: id),
                      currentItem.status == .queued else {
                    sessions.endPreparing(id)
                    processQueue()
                    return
                }
                if currentItem.segments.isEmpty {
                    currentItem.segments = [DownloadSegment(index: 0, startOffset: 0, endOffset: -1)]
                }
                scheduleSave()
            }
        }

        guard !Task.isCancelled, !sessions.shouldIgnoreEvents(for: id),
              let currentItem = fetchItem(id: id),
              currentItem.status == .queued else {
            sessions.endPreparing(id)
            processQueue()
            return
        }

        // Resume must continue writing into the existing partial file. Resolving
        // a fresh target URL would rename it via uniqueFileURL and leave holes.
        releaseScopedDirectory(for: id)
        let targetURL: URL
        if let existingPath = currentItem.localFilePath,
           currentItem.bytesReceived > 0,
           FileManager.default.fileExists(atPath: existingPath) {
            // Re-establish sandbox access to the user-selected folder.
            if let bookmark = currentItem.saveDirectoryBookmark,
               let scoped = BookmarkHelper.resolveBookmark(bookmark) {
                scopedDirectories[id] = scoped
            }
            targetURL = URL(fileURLWithPath: existingPath)
        } else {
            if currentItem.bytesReceived > 0 {
                // The partial file vanished — start over from scratch.
                currentItem.bytesReceived = 0
                for segment in currentItem.segments {
                    segment.bytesReceived = 0
                    segment.isCompleted = false
                }
            }
            guard let resolved = DownloadPathResolver.resolveTarget(for: currentItem) else {
                sessions.endPreparing(id)
                currentItem.status = .failed
                currentItem.errorMessage = L10n.t(
                    de: "Auf den Download-Ordner kann nicht zugegriffen werden. Überprüfe die Dateiberechtigungen in den Systemeinstellungen.",
                    en: "Cannot access download folder. Check file permissions in System Settings."
                )
                saveNow()
                logger.error("Failed to resolve target URL for \(currentItem.fileName, privacy: .public)")
                processQueue()
                return
            }
            if let scoped = resolved.scopedDirectoryURL {
                scopedDirectories[id] = scoped
            }
            targetURL = resolved.fileURL
        }

        guard !Task.isCancelled, !sessions.shouldIgnoreEvents(for: id),
              let currentItem = fetchItem(id: id),
              currentItem.status == .queued else {
            sessions.endPreparing(id)
            processQueue()
            return
        }

        currentItem.localFilePath = targetURL.path
        currentItem.fileName = targetURL.lastPathComponent
        currentItem.status = .downloading
        sessions.beginDownloading(id)
        metricsTrackers[id]?.reset()
        saveNow()

        logger.info("Starting engine for \(currentItem.fileName, privacy: .public) → \(targetURL.path, privacy: .public)")

        let engineSegments = deduplicatedEngineSegments(from: currentItem.segments)

        engine.startSegmentedDownload(
            id: currentItem.id,
            url: url,
            filePath: targetURL.path,
            bytesTotal: currentItem.bytesTotal,
            segments: engineSegments,
            requestHeaders: currentItem.requestHeaders
        )
    }

    func isDeferredStart(_ item: DownloadItem) -> Bool {
        if let scheduled = item.scheduledStartAt, scheduled > Date() {
            return true
        }
        if item.startWhenOnWiFi && !NetworkReachability.shared.prefersWiFiAvailable {
            return true
        }
        return false
    }

    func startScheduler() {
        schedulerTask?.cancel()
        schedulerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                self?.processQueue()
            }
        }
    }

    func performPostDownloadAction(for item: DownloadItem, at localURL: URL) {
        switch item.postDownloadAction {
        case .none:
            break
        case .revealInFinder:
            NSWorkspace.shared.activateFileViewerSelecting([localURL])
        case .openFile:
            NSWorkspace.shared.open(localURL)
        case .extractArchive:
            NSWorkspace.shared.open(localURL)
        }
    }

    func applyProbeResult(_ result: HTTPHeaderHelper.HEADResult, to item: DownloadItem, url: URL) {
        item.supportsResume = result.supportsResume
        if result.contentLength > 0 {
            item.bytesTotal = result.contentLength
        }

        if let suggestedName = result.suggestedFileName,
           item.fileName == FileNameSanitizer.sanitize(url.lastPathComponent) || item.fileName == "download" {
            // Server-provided names are untrusted — never let them traverse paths.
            item.fileName = FileNameSanitizer.sanitize(suggestedName)
        }

        guard item.segments.isEmpty else { return }

        item.preferredSegmentsCount = DownloadIntelligence.recommendedSegmentCount(
            bytesTotal: item.bytesTotal,
            defaultCount: item.preferredSegmentsCount
        )

        let segmentCount = item.preferredSegmentsCount
        item.segments = SegmentPlanner.plan(
            bytesTotal: item.bytesTotal,
            preferredCount: segmentCount,
            supportsResume: result.supportsResume
        ).map { planned in
            DownloadSegment(index: planned.index, startOffset: planned.startOffset, endOffset: planned.endOffset)
        }
    }

    private func deduplicatedEngineSegments(from segments: [DownloadSegment]) -> [SegmentInfo] {
        let mapped = segments.map { segment in
            SegmentInfo(
                index: segment.index,
                startOffset: segment.startOffset,
                endOffset: segment.endOffset,
                bytesReceived: segment.bytesReceived,
                isCompleted: segment.isCompleted
            )
        }
        return SegmentIndexMap.make(from: mapped).values.sorted { $0.index < $1.index }
    }
}
