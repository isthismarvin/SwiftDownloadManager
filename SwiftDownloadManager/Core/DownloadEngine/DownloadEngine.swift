import Foundation
import Darwin
import os

struct SegmentInfo: Sendable {
    let index: Int
    let startOffset: Int64
    var endOffset: Int64
    var bytesReceived: Int64
    var isCompleted: Bool
}

enum SegmentIndexMap {
    /// Builds an index lookup, keeping the last segment when duplicate indices appear.
    static func make(from segments: [SegmentInfo]) -> [Int: SegmentInfo] {
        var dict: [Int: SegmentInfo] = [:]
        dict.reserveCapacity(segments.count)
        for segment in segments {
            dict[segment.index] = segment
        }
        return dict
    }
}

enum DownloadEvent: Sendable {
    case progress(id: UUID, bytesReceived: Int64, bytesTotal: Int64)
    case segmentProgress(id: UUID, segmentIndex: Int, bytesReceived: Int64)
    case segmentsUpdated(id: UUID, segments: [SegmentInfo])
    case paused(id: UUID, segments: [SegmentInfo], bytesReceived: Int64, bytesTotal: Int64)
    case completed(id: UUID, localURL: URL)
    case failed(id: UUID, error: Error, segments: [SegmentInfo], bytesReceived: Int64)
    /// The server ignored a Range request and is sending the full file from
    /// byte 0. All previous progress was discarded; the item does not support
    /// resuming.
    case restartedAsSingleStream(id: UUID, bytesTotal: Int64)

    var downloadID: UUID {
        switch self {
        case let .progress(id, _, _),
             let .segmentProgress(id, _, _),
             let .segmentsUpdated(id, _),
             let .paused(id, _, _, _),
             let .completed(id, _),
             let .failed(id, _, _, _),
             let .restartedAsSingleStream(id, _):
            return id
        }
    }
}

final class DownloadEngine: NSObject, @unchecked Sendable {
    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "Engine")

    private var maxSegmentRetries = 3
    /// Backpressure: suspend a download's tasks once this many bytes are
    /// buffered in memory awaiting disk writes …
    private static let backpressureHighWatermark = 4 * 1024 * 1024
    /// … and resume them once the buffer drained below this.
    private static let backpressureLowWatermark = 1 * 1024 * 1024

    private let speedLimiter = SpeedLimiter()

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.waitsForConnectivity = true
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 4
        delegateQueue.name = "com.swiftdownloadmanager.urlsession"
        return URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    }()

    private var activeDownloads: [UUID: ActiveDownload] = [:]
    private let lock = NSLock()
    private var continuation: AsyncStream<DownloadEvent>.Continuation?

    lazy var eventStream: AsyncStream<DownloadEvent> = {
        AsyncStream { [weak self] continuation in
            self?.lock.lock()
            self?.continuation = continuation
            self?.lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuation = nil
                self?.lock.unlock()
            }
        }
    }()

    override init() {
        super.init()
    }

    func setSpeedLimit(_ bytesPerSecond: Int64, for id: UUID? = nil) {
        if let id = id {
            lock.lock()
            let active = activeDownloads[id]
            lock.unlock()
            active?.localSpeedLimiter.setLimit(bytesPerSecond)
        } else {
            speedLimiter.setLimit(bytesPerSecond)
        }
    }

    func setMaxSegmentRetries(_ count: Int) {
        maxSegmentRetries = max(1, count)
    }

    func startSegmentedDownload(
        id: UUID,
        url: URL,
        filePath: String,
        bytesTotal: Int64,
        segments: [SegmentInfo],
        requestHeaders: [String: String] = [:],
        maxConcurrentConnections: Int = 4,
        speedLimit: Int64? = nil
    ) {
        lock.lock()
        if activeDownloads[id] != nil {
            lock.unlock()
            cancelDownload(id: id, removeFile: false)
            lock.lock()
        }

        let folder = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            lock.unlock()
            continuation?.yield(.failed(
                id: id,
                error: NSError(
                    domain: "DownloadEngine",
                    code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Cannot create download folder: \(folder.path)",
                        NSUnderlyingErrorKey: error
                    ]
                ),
                segments: segments,
                bytesReceived: 0
            ))
            return
        }

        let fileManager = FileManager.default
        let fileURL = URL(fileURLWithPath: filePath)
        let isResuming = segments.contains { $0.bytesReceived > 0 }
        let fileExists = fileManager.fileExists(atPath: filePath)

        if !isResuming || !fileExists {
            if fileExists {
                try? fileManager.removeItem(atPath: filePath)
            }
            guard fileManager.createFile(atPath: filePath, contents: nil, attributes: nil) else {
                lock.unlock()
                continuation?.yield(.failed(
                    id: id,
                    error: NSError(
                        domain: "DownloadEngine",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot create file at \(filePath). Check app sandbox file permissions."]
                    ),
                    segments: segments,
                    bytesReceived: 0
                ))
                return
            }
            if bytesTotal > 0 {
                do {
                    let preallocHandle = try FileHandle(forWritingTo: fileURL)
                    try preallocHandle.truncate(atOffset: UInt64(bytesTotal))
                    try preallocHandle.close()
                } catch {
                    Self.logger.error("Pre-allocation failed for \(filePath, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        } else if bytesTotal > 0 {
            // When resuming, ensure file is at least bytesTotal length if known, without removing existing data
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
               let fileSize = attributes[.size] as? Int64,
               fileSize < bytesTotal {
                do {
                    let preallocHandle = try FileHandle(forWritingTo: fileURL)
                    try preallocHandle.truncate(atOffset: UInt64(bytesTotal))
                    try preallocHandle.close()
                } catch {
                    Self.logger.error("Resume expansion failed for \(filePath, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forWritingTo: fileURL)
        } catch {
            lock.unlock()
            continuation?.yield(.failed(
                id: id,
                error: NSError(
                    domain: "DownloadEngine",
                    code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to open file for writing at \(filePath)",
                        NSUnderlyingErrorKey: error
                    ]
                ),
                segments: segments,
                bytesReceived: isResuming ? segments.map(\.bytesReceived).reduce(0, +) : 0
            ))
            return
        }

        let active = ActiveDownload(
            id: id,
            url: url,
            requestHeaders: requestHeaders,
            fileHandle: fileHandle,
            filePath: filePath,
            bytesTotal: bytesTotal,
            segments: segments,
            maxConcurrentConnections: maxConcurrentConnections,
            speedLimit: speedLimit
        )
        activeDownloads[id] = active
        lock.unlock()

        for segment in segments where !segment.isCompleted {
            startSegmentTask(active: active, segmentIndex: segment.index)
        }
    }

    func pauseDownload(id: UUID) {
        lock.lock()
        let active = activeDownloads.removeValue(forKey: id)
        let cont = continuation
        lock.unlock()

        guard let active = active else { return }

        active.lock.lock()
        guard active.phase == .running else {
            active.lock.unlock()
            return
        }
        active.phase = .pausing
        let tasks = Array(active.tasks.values)
        active.tasks.removeAll()
        let segments = active.snapshotSegmentsLocked()
        let bytesReceived = active.totalBytesReceivedLocked()
        let bytesTotal = active.computedBytesTotalLocked()
        active.lock.unlock()

        active.shutdown(cancelTasks: tasks)
        cont?.yield(.paused(id: id, segments: segments, bytesReceived: bytesReceived, bytesTotal: bytesTotal))
    }

    func cancelDownload(id: UUID, removeFile: Bool = true) {
        lock.lock()
        let active = activeDownloads.removeValue(forKey: id)
        lock.unlock()

        guard let active = active else { return }

        active.lock.lock()
        guard active.phase == .running else {
            active.lock.unlock()
            return
        }
        active.phase = .finished
        let tasks = Array(active.tasks.values)
        active.tasks.removeAll()
        let filePath = active.filePath
        active.lock.unlock()

        active.shutdown(cancelTasks: tasks)

        if removeFile {
            // Remove the file only after pending writes drained and the handle closed.
            active.writeQueue.async {
                try? FileManager.default.removeItem(atPath: filePath)
            }
        }
    }

    // MARK: - Private

    @discardableResult
    private func tryDynamicReSegmentation(
        active: ActiveDownload,
        continuation: AsyncStream<DownloadEvent>.Continuation?
    ) -> Bool {
        active.lock.lock()
        guard active.phase == .running,
              !active.isSingleSegmentFallback,
              active.bytesTotal > 0 else {
            active.lock.unlock()
            return false
        }

        let activeTaskIndices = Set(active.tasks.keys)
        let currentTaskCount = active.tasks.count
        let segmentsList = active.snapshotSegmentsLocked()

        guard let plan = SegmentPlanner.planDynamicSplit(
            segments: segmentsList,
            activeTaskIndices: activeTaskIndices,
            maxConcurrentTasks: active.maxConcurrentConnections,
            currentActiveTaskCount: currentTaskCount
        ) else {
            active.lock.unlock()
            return false
        }

        guard var parent = active.segments[plan.parentIndex] else {
            active.lock.unlock()
            return false
        }

        parent.endOffset = plan.parentNewEndOffset
        active.segments[plan.parentIndex] = parent

        let child = SegmentInfo(
            index: plan.childIndex,
            startOffset: plan.childStartOffset,
            endOffset: plan.childEndOffset,
            bytesReceived: 0,
            isCompleted: false
        )
        active.segments[plan.childIndex] = child

        let allSegments = active.snapshotSegmentsLocked()
        active.lock.unlock()

        Self.logger.info(
            """
            Dynamic re-segmentation: split segment \(plan.parentIndex) at \(plan.childStartOffset), \
            created child segment \(plan.childIndex) [\(plan.childStartOffset)-\(plan.childEndOffset)]
            """
        )

        continuation?.yield(.segmentsUpdated(id: active.id, segments: allSegments))

        startSegmentTask(active: active, segmentIndex: plan.childIndex)

        return true
    }

    private func writeData(
        _ data: Data,
        to active: ActiveDownload,
        segmentIndex: Int,
        continuation: AsyncStream<DownloadEvent>.Continuation?
    ) {
        active.lock.lock()
        active.pendingWrites -= 1
        active.bufferedBytes -= data.count
        let tasksToResume = active.drainBackpressureLocked(lowWatermark: Self.backpressureLowWatermark)
        defer {
            for task in tasksToResume {
                task.resume()
            }
        }

        guard active.phase == .running else {
            active.lock.unlock()
            return
        }

        let effectiveIndex: Int
        if active.isSingleSegmentFallback {
            guard segmentIndex == active.fallbackReceivingIndex else {
                // Stale chunk from a task that was cancelled by the fallback.
                active.lock.unlock()
                maybeFinish(active: active)
                return
            }
            effectiveIndex = 0
        } else {
            effectiveIndex = segmentIndex
        }

        guard var segment = active.segments[effectiveIndex] else {
            active.lock.unlock()
            maybeFinish(active: active)
            return
        }

        do {
            let writeOffset: Int64
            let dataToWrite: Data
            if active.isSingleSegmentFallback {
                writeOffset = active.sequentialWriteOffset
                dataToWrite = data
            } else {
                writeOffset = segment.startOffset + segment.bytesReceived
                if segment.endOffset != -1 {
                    let maxAcceptable = max(0, segment.endOffset - writeOffset + 1)
                    if Int64(data.count) > maxAcceptable {
                        dataToWrite = data.prefix(Int(maxAcceptable))
                    } else {
                        dataToWrite = data
                    }
                } else {
                    dataToWrite = data
                }
            }

            if !dataToWrite.isEmpty {
                let fd = active.fileHandle.fileDescriptor
                let count = dataToWrite.count
                let offset = off_t(writeOffset)
                try dataToWrite.withUnsafeBytes { rawBuffer in
                    guard let base = rawBuffer.baseAddress else { return }
                    var totalWritten = 0
                    while totalWritten < count {
                        let written = pwrite(
                            fd,
                            base.advanced(by: totalWritten),
                            count - totalWritten,
                            offset + off_t(totalWritten)
                        )
                        if written < 0 {
                            let err = errno
                            if err == EINTR {
                                continue
                            }
                            throw NSError(
                                domain: NSPOSIXErrorDomain,
                                code: Int(err),
                                userInfo: [NSLocalizedDescriptionKey: "pwrite failed with errno \(err)"]
                            )
                        }
                        if written == 0 {
                            throw NSError(
                                domain: NSPOSIXErrorDomain,
                                code: Int(ENOSPC),
                                userInfo: [NSLocalizedDescriptionKey: "pwrite returned 0 bytes written"]
                            )
                        }
                        totalWritten += written
                    }
                }
            }

            let writtenCount = Int64(dataToWrite.count)
            if active.isSingleSegmentFallback {
                active.sequentialWriteOffset += writtenCount
                segment.bytesReceived += writtenCount
                if segment.endOffset != -1,
                   segment.bytesReceived >= (segment.endOffset - segment.startOffset + 1) {
                    segment.isCompleted = true
                }
            } else {
                segment.bytesReceived += writtenCount
                if segment.endOffset != -1,
                   segment.bytesReceived >= (segment.endOffset - segment.startOffset + 1) {
                    segment.isCompleted = true
                }
            }

            var taskToCancel: URLSessionDataTask?
            if segment.isCompleted && !active.isSingleSegmentFallback {
                taskToCancel = active.tasks.removeValue(forKey: effectiveIndex)
                active.cleanlyFinishedSegments.insert(effectiveIndex)
            }

            active.segments[effectiveIndex] = segment

            let bytesReceived = active.totalBytesReceivedLocked()
            let bytesTotal = active.computedBytesTotalLocked()
            let shouldCheckCompletion = segment.isCompleted
                || (active.tasks.isEmpty && active.pendingWrites == 0)

            // Coalesce progress events to ~10 Hz per download; chunk-level
            // events would otherwise flood the MainActor consumer.
            let now = Date()
            let shouldYieldProgress = segment.isCompleted
                || now.timeIntervalSince(active.lastProgressYieldAt) >= 0.1
            if shouldYieldProgress {
                active.lastProgressYieldAt = now
            }
            let isCompleted = segment.isCompleted
            active.lock.unlock()

            taskToCancel?.cancel()

            if shouldYieldProgress {
                continuation?.yield(.segmentProgress(id: active.id, segmentIndex: effectiveIndex, bytesReceived: segment.bytesReceived))
                continuation?.yield(.progress(id: active.id, bytesReceived: bytesReceived, bytesTotal: bytesTotal))
            }

            if isCompleted {
                while self.tryDynamicReSegmentation(active: active, continuation: continuation) {}
            }

            if shouldCheckCompletion {
                maybeFinish(active: active)
            }
        } catch {
            active.lock.unlock()
            // failDownload re-checks the phase atomically, so a pause/cancel that
            // raced with this failed write is handled correctly.
            failDownload(active: active, error: error)
        }
    }

    /// Decides — after writes drained and tasks ended — whether the download is
    /// complete, needs a segment retried (server closed early), or failed.
    private func maybeFinish(active: ActiveDownload) {
        enum FinishAction {
            case none
            case complete(filePath: String)
            case retrySegments([Int])
            case fail(Error)
        }

        let action: FinishAction
        active.lock.lock()
        decision: do {
            guard active.phase == .running,
                  active.tasks.isEmpty,
                  active.pendingWrites == 0 else {
                action = .none
                break decision
            }

            var incompleteCleanSegments: [SegmentInfo] = []
            for segment in active.segments.values where !segment.isCompleted {
                guard active.cleanlyFinishedSegments.contains(segment.index) else {
                    // A task error retry is still scheduled for this segment.
                    action = .none
                    break decision
                }
                if segment.endOffset != -1 {
                    // Closed range whose task ended cleanly but bytes are missing.
                    incompleteCleanSegments.append(segment)
                }
                // Open-ended segments finish when their task ends cleanly.
            }

            if incompleteCleanSegments.isEmpty {
                for segment in active.segments.values where !segment.isCompleted {
                    var completed = segment
                    completed.isCompleted = true
                    active.segments[segment.index] = completed
                }
                active.phase = .finished
                action = .complete(filePath: active.filePath)
                break decision
            }

            var labelsToRetry: [Int] = []
            for segment in incompleteCleanSegments {
                let label = active.isSingleSegmentFallback
                    ? (active.fallbackReceivingIndex ?? 0)
                    : segment.index
                let retryCount = active.retryCounts[label, default: 0]
                guard retryCount < maxSegmentRetries else {
                    action = .fail(NSError(
                        domain: "DownloadEngine",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "Server closed the connection before the file was complete."]
                    ))
                    break decision
                }
                active.retryCounts[label] = retryCount + 1
                active.cleanlyFinishedSegments.remove(segment.index)
                labelsToRetry.append(label)
            }
            action = .retrySegments(labelsToRetry)
        }
        active.lock.unlock()

        switch action {
        case .none:
            break

        case .complete(let filePath):
            lock.lock()
            activeDownloads.removeValue(forKey: active.id)
            let cont = continuation
            lock.unlock()

            active.shutdown(cancelTasks: [])
            cont?.yield(.completed(id: active.id, localURL: URL(fileURLWithPath: filePath)))

        case .retrySegments(let labels):
            for label in labels {
                startSegmentTask(active: active, segmentIndex: label)
            }

        case .fail(let error):
            failDownload(active: active, error: error)
        }
    }

    /// Resets all progress and continues with the one task that received an
    /// HTTP 200 full-body response. Returns `bytesTotal` on success, nil if the
    /// receiving task is no longer current (e.g. a second racing 200 response).
    private func restartAsSingleStream(active: ActiveDownload, receivingSegmentIndex: Int) -> Int64? {
        active.lock.lock()
        defer { active.lock.unlock() }

        guard active.phase == .running,
              active.tasks[receivingSegmentIndex] != nil else {
            return nil
        }

        active.isSingleSegmentFallback = true
        active.fallbackReceivingIndex = receivingSegmentIndex

        let tasksToCancel = active.tasks.filter { $0.key != receivingSegmentIndex }
        for (index, task) in tasksToCancel {
            active.tasks.removeValue(forKey: index)
            task.cancel()
        }

        active.segments = [
            0: SegmentInfo(
                index: 0,
                startOffset: 0,
                endOffset: active.bytesTotal > 0 ? active.bytesTotal - 1 : -1,
                bytesReceived: 0,
                isCompleted: false
            )
        ]
        active.sequentialWriteOffset = 0
        active.cleanlyFinishedSegments.removeAll()
        active.sentRangeHeader[receivingSegmentIndex] = false

        // Cleanly truncate the file back to offset 0 on the writeQueue so stale blocks from
        // preallocation or previous segments do not corrupt the single stream.
        active.writeQueue.async {
            try? active.fileHandle.seek(toOffset: 0)
            try? active.fileHandle.truncate(atOffset: 0)
        }

        return active.bytesTotal
    }

    private func startSegmentTask(active: ActiveDownload, segmentIndex: Int) {
        active.lock.lock()
        let lookupIndex = active.isSingleSegmentFallback ? 0 : segmentIndex
        guard let segment = active.segments[lookupIndex], !segment.isCompleted else {
            active.lock.unlock()
            return
        }

        let url = active.url
        let bytesTotal = active.bytesTotal
        let start = segment.startOffset + segment.bytesReceived
        var sentRange = false
        active.lock.unlock()

        var request = URLRequest(url: url)
        active.lock.lock()
        let headers = active.requestHeaders
        active.lock.unlock()
        RequestHeadersHelper.applying(headers, to: &request)
        if request.value(forHTTPHeaderField: "Authorization") == nil,
           let cred = SiteCredentialStore.credential(for: url) {
            request.setValue(cred.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        }
        if bytesTotal > 0 && segment.endOffset != -1 {
            request.addValue("bytes=\(start)-\(segment.endOffset)", forHTTPHeaderField: "Range")
            sentRange = true
        } else if start > 0 {
            request.addValue("bytes=\(start)-", forHTTPHeaderField: "Range")
            sentRange = true
        }

        let task = session.dataTask(with: request)
        task.taskDescription = "\(active.id.uuidString)|\(segmentIndex)"

        active.lock.lock()
        active.tasks[segmentIndex] = task
        active.sentRangeHeader[segmentIndex] = sentRange
        active.lock.unlock()

        task.resume()
    }

    private func retrySegment(active: ActiveDownload, segmentIndex: Int) {
        lock.lock()
        let stillActive = activeDownloads[active.id] != nil
        lock.unlock()
        guard stillActive else { return }

        active.lock.lock()
        let isRunning = active.phase == .running
        active.lock.unlock()
        guard isRunning else { return }

        startSegmentTask(active: active, segmentIndex: segmentIndex)
    }

    private func failDownload(active: ActiveDownload, error: Error) {
        active.lock.lock()
        guard active.phase == .running else {
            active.lock.unlock()
            return
        }
        active.phase = .failed
        let tasks = Array(active.tasks.values)
        active.tasks.removeAll()
        let segments = active.snapshotSegmentsLocked()
        let bytesReceived = active.totalBytesReceivedLocked()
        active.lock.unlock()

        lock.lock()
        activeDownloads.removeValue(forKey: active.id)
        let cont = continuation
        lock.unlock()

        active.shutdown(cancelTasks: tasks)
        cont?.yield(.failed(id: active.id, error: error, segments: segments, bytesReceived: bytesReceived))
    }
}

// MARK: - URLSessionDataDelegate

extension DownloadEngine: URLSessionDataDelegate {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let taskDescription = dataTask.taskDescription else {
            completionHandler(.cancel)
            return
        }

        let components = taskDescription.split(separator: "|")
        guard components.count == 2,
              let id = UUID(uuidString: String(components[0])),
              let segmentIndex = Int(components[1]) else {
            completionHandler(.cancel)
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.allow)
            return
        }

        let statusCode = httpResponse.statusCode

        lock.lock()
        let active = activeDownloads[id]
        let cont = continuation
        lock.unlock()

        guard let active = active else {
            completionHandler(.cancel)
            return
        }

        if statusCode >= 400 {
            completionHandler(.cancel)
            failDownload(
                active: active,
                error: NSError(
                    domain: "DownloadEngine",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode): \(HTTPURLResponse.localizedString(forStatusCode: statusCode))"]
                )
            )
            return
        }

        active.lock.lock()
        let sentRange = active.sentRangeHeader[segmentIndex] == true
        active.lock.unlock()

        if sentRange && statusCode == 200 {
            // The server ignored the Range header and sends the full file from
            // byte 0. Discard all progress and write this one stream from scratch.
            if let bytesTotal = restartAsSingleStream(active: active, receivingSegmentIndex: segmentIndex) {
                completionHandler(.allow)
                cont?.yield(.restartedAsSingleStream(id: id, bytesTotal: bytesTotal))
            } else {
                completionHandler(.cancel)
            }
            return
        }

        if sentRange && statusCode != 206 {
            completionHandler(.cancel)
            failDownload(
                active: active,
                error: NSError(
                    domain: "DownloadEngine",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Unexpected HTTP \(statusCode) for range request"]
                )
            )
            return
        }

        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        guard let taskDescription = dataTask.taskDescription else { return }
        let components = taskDescription.split(separator: "|")
        guard components.count == 2,
              let id = UUID(uuidString: String(components[0])),
              let segmentIndex = Int(components[1]) else { return }

        lock.lock()
        let active = activeDownloads[id]
        let cont = continuation
        lock.unlock()

        guard let active = active else { return }

        active.lock.lock()
        guard active.phase == .running else {
            active.lock.unlock()
            return
        }
        active.pendingWrites += 1
        active.bufferedBytes += data.count

        // Backpressure: suspend network data tasks when too much data is buffered in
        // memory waiting for (possibly speed-limited) disk writes.
        var tasksToSuspend: [URLSessionDataTask] = []
        if active.bufferedBytes >= Self.backpressureHighWatermark {
            for (index, task) in active.tasks where !active.suspendedTaskIndexes.contains(index) {
                active.suspendedTaskIndexes.insert(index)
                tasksToSuspend.append(task)
            }
        }
        active.lock.unlock()

        for task in tasksToSuspend {
            task.suspend()
        }

        let globalDelay = speedLimiter.delayBeforeWrite(bytesCount: data.count)
        let localDelay = active.localSpeedLimiter.delayBeforeWrite(bytesCount: data.count)
        let delay = max(globalDelay, localDelay)

        // Captures self strongly so the pendingWrites counter is always balanced.
        active.writeQueue.asyncAfter(deadline: .now() + delay) {
            self.writeData(data, to: active, segmentIndex: segmentIndex, continuation: cont)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let taskDescription = task.taskDescription else { return }
        let components = taskDescription.split(separator: "|")
        guard components.count == 2,
              let id = UUID(uuidString: String(components[0])),
              let segmentIndex = Int(components[1]) else { return }

        lock.lock()
        let active = activeDownloads[id]
        lock.unlock()

        guard let active = active else { return }

        active.lock.lock()
        active.tasks.removeValue(forKey: segmentIndex)

        guard active.phase == .running else {
            active.lock.unlock()
            return
        }

        if let error = error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                active.lock.unlock()
                let cont = continuation
                while tryDynamicReSegmentation(active: active, continuation: cont) {}
                maybeFinish(active: active)
                return
            }

            let retryCount = active.retryCounts[segmentIndex, default: 0]
            if retryCount < maxSegmentRetries {
                active.retryCounts[segmentIndex] = retryCount + 1
                active.lock.unlock()
                let backoff = pow(2.0, Double(retryCount))
                DispatchQueue.global().asyncAfter(deadline: .now() + backoff) { [weak self] in
                    self?.retrySegment(active: active, segmentIndex: segmentIndex)
                }
                return
            }

            active.lock.unlock()
            failDownload(active: active, error: error)
            return
        }

        if active.isSingleSegmentFallback && segmentIndex != active.fallbackReceivingIndex {
            // Late clean completion of a task that was superseded by the fallback.
            active.lock.unlock()
            return
        }

        let effectiveIndex = active.isSingleSegmentFallback ? 0 : segmentIndex
        active.cleanlyFinishedSegments.insert(effectiveIndex)
        active.lock.unlock()

        let cont = continuation
        while tryDynamicReSegmentation(active: active, continuation: cont) {}
        maybeFinish(active: active)
    }
}
