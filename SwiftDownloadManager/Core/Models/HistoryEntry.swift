import Foundation
import SwiftData

@Model
final class HistoryEntry {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var urlString: String
    var bytesTotal: Int64
    var finishedAt: Date
    var outcomeRaw: String

    var outcome: HistoryOutcome {
        get { HistoryOutcome(rawValue: outcomeRaw) ?? .completed }
        set { outcomeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        fileName: String,
        urlString: String,
        bytesTotal: Int64,
        finishedAt: Date = Date(),
        outcome: HistoryOutcome
    ) {
        self.id = id
        self.fileName = fileName
        self.urlString = urlString
        self.bytesTotal = bytesTotal
        self.finishedAt = finishedAt
        self.outcomeRaw = outcome.rawValue
    }
}
