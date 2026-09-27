import Foundation

/// Pure segment-splitting logic, extracted from DownloadManager for testability.
enum SegmentPlanner {
    /// Segments below this size are not worth a separate connection.
    static let minSegmentSize: Int64 = 1_048_576

    struct PlannedSegment: Equatable {
        let index: Int
        let startOffset: Int64
        /// -1 = open-ended (unknown size or no range support).
        let endOffset: Int64
    }

    static func plan(bytesTotal: Int64, preferredCount: Int, supportsResume: Bool) -> [PlannedSegment] {
        guard supportsResume, bytesTotal > 0 else {
            return [PlannedSegment(index: 0, startOffset: 0, endOffset: -1)]
        }

        // Cap the count so each segment is at least `minSegmentSize` — splitting
        // tiny files produces zero-length segments with bogus offsets.
        let maxSegmentsBySize = max(1, Int(bytesTotal / minSegmentSize))
        let count = max(1, min(preferredCount, maxSegmentsBySize))

        guard count > 1 else {
            // Closed range so the engine can validate that all bytes arrived.
            return [PlannedSegment(index: 0, startOffset: 0, endOffset: bytesTotal - 1)]
        }

        let segmentSize = bytesTotal / Int64(count)
        return (0..<count).map { i in
            let start = Int64(i) * segmentSize
            let end = (i == count - 1) ? (bytesTotal - 1) : (start + segmentSize - 1)
            return PlannedSegment(index: i, startOffset: start, endOffset: end)
        }
    }

    struct SplitPlan: Equatable {
        let parentIndex: Int
        let parentNewEndOffset: Int64
        let childIndex: Int
        let childStartOffset: Int64
        let childEndOffset: Int64
    }

    /// Determines if an active segment should be dynamically split in half to feed an idle connection (IDM dynamic segmentation).
    /// Returns the split plan if an eligible segment with sufficient un-downloaded bytes is found.
    static func planDynamicSplit(
        segments: [SegmentInfo],
        activeTaskIndices: Set<Int>,
        maxConcurrentTasks: Int,
        currentActiveTaskCount: Int,
        minSpanToSplit: Int64 = 4 * 1024 * 1024,
        minChildSize: Int64 = 2 * 1024 * 1024
    ) -> SplitPlan? {
        guard currentActiveTaskCount < maxConcurrentTasks else { return nil }

        // Find eligible segments: must have an active task, not be completed, and have a finite endOffset
        var bestCandidate: SegmentInfo?
        var maxRemaining: Int64 = 0

        for segment in segments {
            guard activeTaskIndices.contains(segment.index),
                  !segment.isCompleted,
                  segment.endOffset != -1 else { continue }

            let currentWriteOffset = segment.startOffset + segment.bytesReceived
            let remaining = segment.endOffset - currentWriteOffset + 1
            if remaining > maxRemaining {
                maxRemaining = remaining
                bestCandidate = segment
            }
        }

        guard let target = bestCandidate,
              maxRemaining >= minSpanToSplit else {
            return nil
        }

        let currentWriteOffset = target.startOffset + target.bytesReceived
        let half = maxRemaining / 2
        guard half >= minChildSize else { return nil }

        let splitPoint = currentWriteOffset + half
        let parentNewEnd = splitPoint - 1
        let childEnd = target.endOffset

        let nextIndex = (segments.map(\.index).max() ?? 0) + 1

        return SplitPlan(
            parentIndex: target.index,
            parentNewEndOffset: parentNewEnd,
            childIndex: nextIndex,
            childStartOffset: splitPoint,
            childEndOffset: childEnd
        )
    }
}
