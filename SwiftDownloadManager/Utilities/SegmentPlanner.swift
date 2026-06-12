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
}
