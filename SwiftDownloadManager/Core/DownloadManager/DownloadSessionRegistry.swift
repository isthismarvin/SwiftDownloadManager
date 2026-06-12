import Foundation
import Observation

/// Tracks in-memory lifecycle for active downloads (separate from persisted SwiftData status).
@MainActor
@Observable
final class DownloadSessionRegistry {
    enum Phase: Equatable {
        case preparing
        case downloading
    }

    private(set) var preparingIDs: Set<UUID> = []
    private(set) var downloadingIDs: Set<UUID> = []
    private(set) var cancelledIDs: Set<UUID> = []
    private(set) var deletedIDs: Set<UUID> = []

    var activeCount: Int {
        preparingIDs.count + downloadingIDs.count
    }

    func isActive(_ id: UUID) -> Bool {
        preparingIDs.contains(id) || downloadingIDs.contains(id)
    }

    func shouldIgnoreEvents(for id: UUID) -> Bool {
        cancelledIDs.contains(id) || deletedIDs.contains(id)
    }

    func beginPreparing(_ id: UUID) {
        preparingIDs.insert(id)
    }

    func endPreparing(_ id: UUID) {
        preparingIDs.remove(id)
    }

    func beginDownloading(_ id: UUID) {
        preparingIDs.remove(id)
        downloadingIDs.insert(id)
    }

    func endDownloading(_ id: UUID) {
        preparingIDs.remove(id)
        downloadingIDs.remove(id)
    }

    func markCancelled(_ id: UUID) {
        cancelledIDs.insert(id)
        endDownloading(id)
    }

    func markDeleted(_ id: UUID) {
        deletedIDs.insert(id)
        // The deleted marker covers event suppression; drop the cancelled
        // marker so the set does not grow for the app's lifetime.
        cancelledIDs.remove(id)
        endDownloading(id)
    }

    func unmarkCancelled(_ id: UUID) {
        cancelledIDs.remove(id)
    }

    func resetAll() {
        preparingIDs.removeAll()
        downloadingIDs.removeAll()
    }
}
