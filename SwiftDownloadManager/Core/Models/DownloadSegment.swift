import Foundation
import SwiftData

@Model
final class DownloadSegment {
    @Attribute(.unique) var id: UUID
    var index: Int
    var startOffset: Int64
    var endOffset: Int64
    var bytesReceived: Int64
    var isCompleted: Bool
    
    var downloadItem: DownloadItem?
    
    init(
        id: UUID = UUID(),
        index: Int,
        startOffset: Int64,
        endOffset: Int64,
        bytesReceived: Int64 = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.index = index
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.bytesReceived = bytesReceived
        self.isCompleted = isCompleted
    }

    /// Expected byte count for this segment's HTTP range.
    func byteCapacity(bytesTotal: Int64) -> Int64 {
        if endOffset >= 0 {
            return endOffset - startOffset + 1
        }
        guard bytesTotal > startOffset else { return max(bytesReceived, 0) }
        return bytesTotal - startOffset
    }

    /// Progress for UI display. Completed segments and finished downloads show 100%.
    func displayProgress(bytesTotal: Int64, downloadCompleted: Bool) -> Double {
        if downloadCompleted || isCompleted {
            return 1.0
        }
        let size = byteCapacity(bytesTotal: bytesTotal)
        guard size > 0 else { return 0 }
        return min(Double(bytesReceived) / Double(size), 1.0)
    }

    /// Bytes received for UI display, normalized when the segment or download is done.
    func displayBytesReceived(bytesTotal: Int64, downloadCompleted: Bool) -> Int64 {
        if downloadCompleted || isCompleted {
            return byteCapacity(bytesTotal: bytesTotal)
        }
        return bytesReceived
    }
}
