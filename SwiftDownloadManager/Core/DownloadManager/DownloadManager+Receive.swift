import Foundation
import SwiftData
import os

extension DownloadManager {
    // MARK: - Public Download API

    /// User already confirmed via the Add Download sheet — enqueue immediately.
    func applySegmentRetries(_ count: Int) {
        engine.setMaxSegmentRetries(count)
    }

    func pruneHistory(olderThanDays days: Int) {
        guard days > 0, let modelContext = modelContext else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<HistoryEntry>()
        guard let entries = try? modelContext.fetch(descriptor) else { return }
        let stale = entries.filter { $0.finishedAt < cutoff }
        guard !stale.isEmpty else { return }
        for entry in stale {
            modelContext.delete(entry)
        }
        saveNow()
        logger.info("Pruned \(stale.count) history entries older than \(days) days")
    }

    func addDownload(
        url: URL,
        preferredSegmentsCount: Int? = nil,
        saveDirectory: URL? = nil,
        fileNameOverride: String? = nil,
        category: LibraryCategory? = nil,
        folder: DownloadFolder? = nil
    ) {
        let segments = preferredSegmentsCount ?? AppSettings.shared.defaultSegmentsCount
        guard let item = insertDownloadItem(
            url: url,
            preferredSegmentsCount: segments,
            saveDirectory: saveDirectory,
            fileNameOverride: fileNameOverride,
            category: category,
            folder: folder,
            initialStatus: .queued
        ) else { return }

        logger.info("Queued download \(item.fileName, privacy: .public) for \(url.absoluteString, privacy: .public)")
        processQueue()
    }

    /// External sources (extension, drag & drop, paste) — confirmation required
    /// unless the host matches an auto-start domain rule.
    @discardableResult
    func receiveDownload(
        url: URL,
        fileNameOverride: String? = nil,
        preferredSegmentsCount: Int? = nil,
        source: DownloadSource = .chromeExtension,
        requestHeaders: [String: String] = [:],
        referrer: String? = nil
    ) -> ReceiveDownloadOutcome? {
        let segments = preferredSegmentsCount ?? AppSettings.shared.defaultSegmentsCount
        switch DomainRuleStore.policy(for: url.absoluteString) {
        case .blocked:
            logger.info("Blocked download from \(url.absoluteString, privacy: .public)")
            return .blocked
        case .autoStart:
            guard let item = insertDownloadItem(
                url: url,
                preferredSegmentsCount: segments,
                fileNameOverride: fileNameOverride,
                initialStatus: .queued,
                source: source,
                requestHeadersJSON: RequestHeadersHelper.encode(requestHeaders),
                referrerURLString: referrer
            ) else { return nil }
            applyIncomingDefaults(to: item)
            item.holdInQueue = false
            logger.info("Auto-started download for \(url.host ?? "", privacy: .public)")
            processQueue()
            return .queued(item.id)
        case .default, .alwaysAsk:
            break
        }

        guard let item = insertDownloadItem(
            url: url,
            preferredSegmentsCount: segments,
            fileNameOverride: fileNameOverride,
            initialStatus: .received,
            source: source,
            requestHeadersJSON: RequestHeadersHelper.encode(requestHeaders),
            referrerURLString: referrer
        ) else { return nil }

        applyIncomingDefaults(to: item)
        saveNow()

        logger.info("Received download \(item.fileName, privacy: .public) — awaiting confirmation")
        startMetadataProbe(for: item.id)

        if let duplicate = findActiveDuplicate(urlString: url.absoluteString, excluding: item.id) {
            return .duplicateAwaitingConfirmation(newID: item.id, existingID: duplicate.id)
        }
        return .awaitingConfirmation(item.id)
    }

    func fetchItemForUI(id: UUID) -> DownloadItem? {
        fetchItem(id: id)
    }

    func enqueueCompletionDialog(id: UUID) {
        if !AppSettings.shared.showCompletionDialog {
            if let item = fetchItem(id: id), let path = item.localFilePath {
                performPostDownloadAction(for: item, at: URL(fileURLWithPath: path))
            }
            return
        }
        guard !completionDialogQueue.contains(id) else { return }
        completionDialogQueue.append(id)
    }

    func dismissCompletionDialog(id: UUID) {
        completionDialogQueue.removeAll { $0 == id }
    }

    /// Moves a completed file into `directory` and updates the download record.
    func moveCompletedFile(itemID: UUID, to directory: URL) -> String? {
        guard let item = fetchItem(id: itemID),
              item.status == .completed,
              let path = item.localFilePath else { return nil }

        let source = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }

        let hasAccess = directory.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                directory.stopAccessingSecurityScopedResource()
            }
        }

        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else {
            return nil
        }

        let destination = DownloadPathResolver.targetFileURL(in: directory, fileName: source.lastPathComponent)

        do {
            if source != destination {
                try FileManager.default.moveItem(at: source, to: destination)
            }
            item.localFilePath = destination.path
            item.fileName = destination.lastPathComponent
            item.saveDirectoryPath = directory.path
            item.saveDirectoryBookmark = BookmarkHelper.createBookmark(for: directory)
            item.localFileBookmark = BookmarkHelper.createFileBookmark(for: destination)
            FileLocationMonitor.shared.apply(state: .available(destination), for: item.id)
            RecentDestinationsStore.record(directory.path)
            saveNow()
            return destination.path
        } catch {
            logger.error("Move failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func confirmDownload(id: UUID, options: DownloadConfirmationOptions, processQueueAfter: Bool = true) {
        guard let item = fetchItem(id: id) else { return }
        guard item.status == .received || item.status == .pendingConfirmation else { return }

        cancelMetadataProbe(for: id)

        if let host = DomainRuleStore.host(from: item.urlString),
           let policy = options.domainPolicy,
           policy != .default {
            DomainRuleStore.setPolicy(policy, forHost: host)
        }

        item.urlString = options.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        item.fileName = FileNameSanitizer.sanitize(options.fileName)
        item.preferredSegmentsCount = options.preferredSegmentsCount
        item.libraryCategory = options.libraryCategory
        item.folder = options.folder
        item.postDownloadAction = options.postDownloadAction
        item.scheduledStartAt = options.scheduledStartAt
        item.startWhenOnWiFi = options.startWhenOnWiFi
        item.holdInQueue = !options.startImmediately
        item.probeErrorMessage = nil

        if let override = options.conflictPolicyOverride {
            conflictPolicyOverrides[id] = override
        } else if AppSettings.shared.conflictPolicy != .ask {
            conflictPolicyOverrides.removeValue(forKey: id)
        }

        if options.useBrowserHeaders {
            // Keep headers already stored on the item.
        } else {
            item.requestHeadersJSON = nil
        }

        if let saveDirectory = options.saveDirectory {
            updatePendingDestination(id: id, saveDirectory: saveDirectory)
            RecentDestinationsStore.record(saveDirectory.path)
        } else if let path = item.saveDirectoryPath {
            RecentDestinationsStore.record(path)
        }

        item.status = .queued
        saveNow()
        logger.info("Confirmed download \(item.fileName, privacy: .public)")

        if processQueueAfter && options.startImmediately && !isDeferredStart(item) {
            processQueue()
        }
    }

    func confirmDownload(id: UUID, autoStartDomain: Bool = false) {
        guard let item = fetchItem(id: id) else { return }
        var options = DownloadConfirmationOptions(
            fileName: item.fileName,
            urlString: item.urlString,
            preferredSegmentsCount: item.preferredSegmentsCount,
            libraryCategory: item.libraryCategory,
            folder: item.folder,
            startImmediately: true
        )
        if autoStartDomain {
            options.domainPolicy = .autoStart
        }
        confirmDownload(id: id, options: options)
    }

    func reprobePendingDownload(id: UUID, urlString: String) async {
        guard let item = fetchItem(id: id) else { return }
        guard item.status == .received || item.status == .pendingConfirmation else { return }

        item.urlString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        item.probeErrorMessage = nil
        item.bytesTotal = -1
        item.supportsResume = false
        if item.status == .pendingConfirmation {
            item.status = .received
        }
        saveNow()
        await enqueueMetadataProbe(for: id).value
    }

    func releaseHeldDownload(id: UUID) {
        guard let item = fetchItem(id: id), item.status == .queued else { return }
        item.holdInQueue = false
        item.scheduledStartAt = nil
        item.startWhenOnWiFi = false
        saveNow()
        processQueue()
    }

    func confirmDownloads(ids: [UUID], startImmediately: Bool = true) {
        for id in ids {
            guard let item = fetchItem(id: id) else { continue }
            let options = DownloadConfirmationOptions(
                fileName: item.fileName,
                urlString: item.urlString,
                preferredSegmentsCount: item.preferredSegmentsCount,
                libraryCategory: item.libraryCategory,
                folder: item.folder,
                startImmediately: startImmediately
            )
            confirmDownload(id: id, options: options, processQueueAfter: false)
        }
        if startImmediately {
            processQueue()
        }
    }

    func rejectDownloads(ids: [UUID]) {
        for id in ids {
            rejectDownload(id: id)
        }
    }

    func rejectDownload(id: UUID) {
        guard let item = fetchItem(id: id) else { return }
        guard item.status == .received || item.status == .pendingConfirmation else { return }

        cancelMetadataProbe(for: id)
        modelContext?.delete(item)
        saveNow()
        logger.info("Rejected download \(item.fileName, privacy: .public)")
    }

    func updatePendingDestination(id: UUID, saveDirectory: URL?) {
        guard let item = fetchItem(id: id) else { return }
        guard item.status == .received || item.status == .pendingConfirmation else { return }

        if let saveDirectory {
            let hasAccess = saveDirectory.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    saveDirectory.stopAccessingSecurityScopedResource()
                }
            }
            item.saveDirectoryBookmark = BookmarkHelper.createBookmark(for: saveDirectory)
            item.saveDirectoryPath = saveDirectory.path
        } else {
            item.saveDirectoryBookmark = nil
            item.saveDirectoryPath = nil
        }
        saveNow()
    }

    func findActiveDuplicate(urlString: String, excluding excludedID: UUID? = nil) -> DownloadItem? {
        guard let modelContext = modelContext else { return nil }
        let descriptor = FetchDescriptor<DownloadItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return nil }

        let activeStatuses: Set<DownloadStatus> = [
            .received, .pendingConfirmation, .queued, .downloading, .paused
        ]

        return items.first { item in
            if let excludedID, item.id == excludedID { return false }
            return item.urlString == urlString && activeStatuses.contains(item.status)
        }
    }

    func insertDownloadItem(
        url: URL,
        preferredSegmentsCount: Int = 4,
        saveDirectory: URL? = nil,
        fileNameOverride: String? = nil,
        category: LibraryCategory? = nil,
        folder: DownloadFolder? = nil,
        initialStatus: DownloadStatus,
        source: DownloadSource? = nil,
        requestHeadersJSON: String? = nil,
        referrerURLString: String? = nil
    ) -> DownloadItem? {
        guard let modelContext = modelContext else {
            logger.error("insertDownloadItem called before setup")
            return nil
        }

        var bookmark: Data?
        var resolvedSaveDirectory = saveDirectory
        if resolvedSaveDirectory == nil,
           AppSettings.shared.smartFeaturesEnabled,
           AppSettings.shared.rememberFolderPerHost,
           let host = DomainRuleStore.host(from: url.absoluteString),
           let learned = DownloadLearningStore.suggestedSaveDirectory(for: host) {
            resolvedSaveDirectory = learned
        }
        if resolvedSaveDirectory == nil {
            resolvedSaveDirectory = AppSettings.shared.resolvedDefaultSaveDirectory()
        }

        if let resolvedSaveDirectory {
            let hasAccess = resolvedSaveDirectory.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    resolvedSaveDirectory.stopAccessingSecurityScopedResource()
                }
            }
            bookmark = BookmarkHelper.createBookmark(for: resolvedSaveDirectory)
        }

        let fileName: String
        if let override = fileNameOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
            fileName = FileNameSanitizer.sanitize(override)
        } else {
            fileName = FileNameSanitizer.sanitize(url.lastPathComponent)
        }

        let resolvedCategory = category ?? FileTypeHelper.category(for: fileName)

        let newItem = DownloadItem(
            urlString: url.absoluteString,
            fileName: fileName,
            status: initialStatus,
            bytesTotal: -1,
            supportsResume: false,
            preferredSegmentsCount: preferredSegmentsCount,
            saveDirectoryPath: resolvedSaveDirectory?.path,
            saveDirectoryBookmark: bookmark,
            libraryCategory: resolvedCategory,
            folder: folder,
            source: source,
            requestHeadersJSON: requestHeadersJSON,
            referrerURLString: referrerURLString
        )

        modelContext.insert(newItem)
        saveNow()
        return newItem
    }

    func startMetadataProbe(for id: UUID) {
        _ = enqueueMetadataProbe(for: id)
    }

    func probeMetadata(for id: UUID, generation: UInt64) async {
        defer {
            clearMetadataProbeTaskIfCurrent(id: id, generation: generation)
        }

        guard !Task.isCancelled else { return }
        guard let item = fetchItem(id: id), isProbeableStatus(item.status) else { return }
        guard let url = URL(string: item.urlString) else {
            guard !Task.isCancelled,
                  let item = fetchItem(id: id),
                  isProbeableStatus(item.status) else { return }
            item.status = .pendingConfirmation
            saveNow()
            return
        }

        let headers = item.requestHeaders
        let probeOutcome = await DownloadProbeService.probe(url: url, headers: headers)

        guard !Task.isCancelled,
              let item = fetchItem(id: id),
              isProbeableStatus(item.status) else { return }

        switch probeOutcome {
        case .success(let result):
            item.probeErrorMessage = nil
            applyProbeMetadata(result, to: item, url: url)
        case .inconclusive:
            item.probeErrorMessage = nil
        case .networkError(let error):
            item.probeErrorMessage = friendlyNetworkMessage(for: error)
        }

        guard !Task.isCancelled,
              let currentItem = fetchItem(id: id),
              currentItem.status == .received else { return }

        finishAwaitingConfirmation(for: id)
    }

    func applyIncomingDefaults(to item: DownloadItem) {
        item.startWhenOnWiFi = AppSettings.shared.defaultStartWhenOnWiFi
        if item.postDownloadAction == .none {
            if AppSettings.shared.smartFeaturesEnabled,
               AppSettings.shared.smartPostDownloadActions,
               let learned = DownloadLearningStore.recommendedPostDownloadAction(for: item.fileName) {
                item.postDownloadAction = learned
            } else {
                item.postDownloadAction = AppSettings.shared.defaultPostDownloadAction
            }
        }
        if AppSettings.shared.holdNewDownloadsInQueue {
            item.holdInQueue = true
        }
    }

    func finishAwaitingConfirmation(for id: UUID) {
        guard let item = fetchItem(id: id) else { return }

        if AppSettings.shared.shouldShowConfirmation(for: item.urlString) {
            item.status = .pendingConfirmation
            saveNow()
            return
        }

        confirmDownload(
            id: id,
            options: AppSettings.shared.defaultConfirmationOptions(for: item),
            processQueueAfter: true
        )
    }

    func applyProbeMetadata(_ result: HTTPHeaderHelper.HEADResult, to item: DownloadItem, url: URL) {
        item.supportsResume = result.supportsResume
        if result.contentLength > 0 {
            item.bytesTotal = result.contentLength
        }

        if let suggestedName = result.suggestedFileName,
           item.fileName == FileNameSanitizer.sanitize(url.lastPathComponent) || item.fileName == "download" {
            item.fileName = FileNameSanitizer.sanitize(suggestedName)
        }

        if item.libraryCategory == nil {
            item.libraryCategory = FileTypeHelper.category(for: item.fileName)
        }
    }
}
