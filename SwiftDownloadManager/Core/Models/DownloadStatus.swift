import Foundation

enum DownloadStatus: String, Codable, Sendable {
    /// URL received from an external source; metadata probe may still be running.
    case received
    /// Awaiting user confirmation before entering the download queue.
    case pendingConfirmation
    case queued
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

enum HistoryOutcome: String, Codable, Sendable {
    case completed
    case deleted
    case cancelled
}
