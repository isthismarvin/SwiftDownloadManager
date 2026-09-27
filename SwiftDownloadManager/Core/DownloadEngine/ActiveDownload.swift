import Foundation

final class ActiveDownload: @unchecked Sendable {
    /// Lifecycle of a download. Transitions are one-way; `closed` is terminal
    /// (file handle released). Any state other than `running` means no more
    /// writes or events should be produced.
    enum Phase {
        case running
        case pausing
        case failed
        case finished
        case closed
    }

    let id: UUID
    let url: URL
    let requestHeaders: [String: String]
    let fileHandle: FileHandle
    let filePath: String
    var bytesTotal: Int64
    var segments: [Int: SegmentInfo]
    var tasks: [Int: URLSessionDataTask] = [:]
    var sentRangeHeader: [Int: Bool] = [:]
    var retryCounts: [Int: Int] = [:]
    var phase: Phase = .running
    var isSingleSegmentFallback = false
    /// Task-label index of the one task that survives a single-stream fallback.
    var fallbackReceivingIndex: Int?
    var sequentialWriteOffset: Int64 = 0
    let maxConcurrentConnections: Int
    /// Chunks accepted from URLSession but not yet written to disk.
    var pendingWrites: Int = 0
    /// Bytes accepted from URLSession but not yet written to disk.
    var bufferedBytes: Int = 0
    /// Task-label indexes currently suspended for backpressure.
    var suspendedTaskIndexes: Set<Int> = []
    /// Effective segment indexes whose task ended without error.
    var cleanlyFinishedSegments: Set<Int> = []
    /// Coalesces progress events to ~10 Hz per download.
    var lastProgressYieldAt = Date.distantPast
    let writeQueue: DispatchQueue
    let lock = NSLock()
    let localSpeedLimiter = SpeedLimiter()

    init(
        id: UUID,
        url: URL,
        requestHeaders: [String: String] = [:],
        fileHandle: FileHandle,
        filePath: String,
        bytesTotal: Int64,
        segments: [SegmentInfo],
        maxConcurrentConnections: Int = 4,
        speedLimit: Int64? = nil
    ) {
        self.id = id
        self.url = url
        self.requestHeaders = requestHeaders
        self.fileHandle = fileHandle
        self.filePath = filePath
        self.bytesTotal = bytesTotal
        self.segments = SegmentIndexMap.make(from: segments)
        self.maxConcurrentConnections = max(1, maxConcurrentConnections)
        self.writeQueue = DispatchQueue(label: "com.swiftdownloadmanager.write.\(id.uuidString)")
        self.sequentialWriteOffset = segments.map(\.bytesReceived).reduce(0, +)
        if let speedLimit = speedLimit, speedLimit > 0 {
            self.localSpeedLimiter.setLimit(speedLimit)
        }
    }

    // MARK: - Locked helpers (caller MUST hold `lock`)
    // NSLock is non-reentrant; these variants exist so methods that already
    // hold the lock never re-lock (which would deadlock permanently).

    func snapshotSegmentsLocked() -> [SegmentInfo] {
        segments.values.sorted { $0.index < $1.index }
    }

    func totalBytesReceivedLocked() -> Int64 {
        if isSingleSegmentFallback {
            return sequentialWriteOffset
        }
        return segments.values.map(\.bytesReceived).reduce(0, +)
    }

    func computedBytesTotalLocked() -> Int64 {
        if bytesTotal > 0 { return bytesTotal }
        let hasOpenEnded = segments.values.contains { $0.endOffset == -1 }
        if hasOpenEnded { return -1 }
        return segments.values.map { $0.endOffset - $0.startOffset + 1 }.reduce(0, +)
    }

    /// Returns the tasks to resume once the write buffer drained below the
    /// low watermark. Caller must hold `lock` and resume them after unlocking.
    func drainBackpressureLocked(lowWatermark: Int) -> [URLSessionDataTask] {
        guard !suspendedTaskIndexes.isEmpty,
              bufferedBytes <= lowWatermark,
              phase == .running else {
            return []
        }
        let tasksToResume = suspendedTaskIndexes.compactMap { tasks[$0] }
        suspendedTaskIndexes.removeAll()
        return tasksToResume
    }

    // MARK: - Locking wrappers

    func snapshotSegments() -> [SegmentInfo] {
        lock.lock()
        defer { lock.unlock() }
        return snapshotSegmentsLocked()
    }

    func totalBytesReceived() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return totalBytesReceivedLocked()
    }

    func computedBytesTotal() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return computedBytesTotalLocked()
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        guard phase != .closed else { return }
        phase = .closed
        try? fileHandle.synchronize()
        try? fileHandle.close()
    }

    /// Drains pending writes asynchronously, then closes the file handle.
    /// The caller must already have moved `phase` out of `.running`.
    func shutdown(cancelTasks: [URLSessionDataTask]) {
        for task in cancelTasks {
            task.cancel()
        }
        writeQueue.async { [self] in
            close()
        }
    }
}
