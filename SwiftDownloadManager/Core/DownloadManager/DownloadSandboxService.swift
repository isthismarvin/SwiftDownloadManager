import Foundation
import os

/// Manages the lifecycle of security-scoped resource access for active downloads.
@MainActor
final class DownloadSandboxService {
    static let shared = DownloadSandboxService()

    private let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "DownloadSandboxService")
    private var scopedDirectories: [UUID: URL] = [:]

    private init() {}

    /// Retains a security-scoped directory access for an active download task.
    /// Replaces any existing scope for the same download ID.
    func retainScopedDirectory(_ url: URL, for id: UUID) {
        releaseScopedDirectory(for: id)
        scopedDirectories[id] = url
        logger.debug("Retained security-scoped directory for \(id.uuidString, privacy: .public): \(url.path, privacy: .public)")
    }

    /// Releases security-scoped access for a specific download when it pauses, completes, cancels, or fails.
    func releaseScopedDirectory(for id: UUID) {
        if let url = scopedDirectories.removeValue(forKey: id) {
            url.stopAccessingSecurityScopedResource()
            logger.debug("Released security-scoped directory for \(id.uuidString, privacy: .public)")
        }
    }

    /// Releases all retained security-scoped directories on application shutdown.
    func releaseAll() {
        for (id, url) in scopedDirectories {
            url.stopAccessingSecurityScopedResource()
            logger.debug("Released security-scoped directory during shutdown for \(id.uuidString, privacy: .public)")
        }
        scopedDirectories.removeAll()
    }
}
