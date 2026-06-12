import Foundation
import SwiftData
import Observation
import os

@Observable
final class PersistenceController {
    static let shared = PersistenceController()

    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "Persistence")

    let container: ModelContainer
    private(set) var isDegradedMode = false
    private(set) var lastError: String?

    init(inMemory: Bool = false) {
        let schema = Schema([
            DownloadItem.self,
            DownloadSegment.self,
            DownloadFolder.self,
            HistoryEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            Self.logger.error("ModelContainer creation failed (\(error.localizedDescription, privacy: .public)) — resetting store")
            let storeURL = modelConfiguration.url
            let fileManager = FileManager.default
            for suffix in ["", "-shm", "-wal"] {
                try? fileManager.removeItem(atPath: storeURL.path + suffix)
            }
            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch let resetError {
                let message = resetError.localizedDescription
                Self.logger.error("ModelContainer creation failed after store reset (\(message, privacy: .public)) — falling back to in-memory store")
                let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                if let memoryContainer = try? ModelContainer(for: schema, configurations: [fallbackConfiguration]) {
                    container = memoryContainer
                    isDegradedMode = true
                    lastError = message
                } else {
                    fatalError("SwiftData unavailable after store reset and in-memory fallback: \(message)")
                }
            }
        }
    }

    @MainActor
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext

        let downloading = DownloadItem(
            urlString: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso",
            fileName: "ubuntu-24.04-desktop-amd64.iso",
            status: .downloading,
            bytesReceived: 1_200_000_000,
            bytesTotal: 2_800_000_000,
            supportsResume: true,
            preferredSegmentsCount: 4
        )
        downloading.segments = [
            DownloadSegment(index: 0, startOffset: 0, endOffset: 699_999_999, bytesReceived: 300_000_000),
            DownloadSegment(index: 1, startOffset: 700_000_000, endOffset: 1_399_999_999, bytesReceived: 300_000_000),
            DownloadSegment(index: 2, startOffset: 1_400_000_000, endOffset: 2_099_999_999, bytesReceived: 300_000_000),
            DownloadSegment(index: 3, startOffset: 2_100_000_000, endOffset: 2_799_999_999, bytesReceived: 300_000_000)
        ]

        let items = [
            downloading,
            DownloadItem(
                urlString: "https://download.blender.org/demo/movies/Big_Buck_Bunny_4K.mp4",
                fileName: "Big Buck Bunny 4K.mp4",
                status: .downloading,
                bytesReceived: 652_100_000,
                bytesTotal: 1_400_000_000,
                supportsResume: true
            ),
            DownloadItem(
                urlString: "https://example.com/presentation.pdf",
                fileName: "presentation.pdf",
                status: .completed,
                bytesReceived: 24_300_000,
                bytesTotal: 24_300_000
            ),
            DownloadItem(
                urlString: "https://example.com/archive.zip",
                fileName: "archive.zip",
                status: .paused,
                bytesReceived: 0,
                bytesTotal: 1_100_000_000,
                supportsResume: true
            ),
            DownloadItem(
                urlString: "https://example.com/photo_2024_07_01.tar.gz",
                fileName: "photo_2024_07_01.tar.gz",
                status: .paused,
                bytesReceived: 0,
                bytesTotal: 512_700_000,
                supportsResume: true
            ),
            DownloadItem(
                urlString: "https://example.com/app.dmg",
                fileName: "app.dmg",
                status: .completed,
                bytesReceived: 2_000_000_000,
                bytesTotal: 2_000_000_000
            ),
            DownloadItem(
                urlString: "https://example.com/broken-file.iso",
                fileName: "broken-file.iso",
                status: .failed,
                bytesReceived: 0,
                bytesTotal: 1_200_000_000,
                errorMessage: "Connection lost"
            )
        ]

        for item in items {
            context.insert(item)
        }

        try? context.save()
        return controller
    }()
}
