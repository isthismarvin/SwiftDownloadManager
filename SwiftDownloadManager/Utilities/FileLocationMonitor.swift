import CoreServices
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class FileLocationMonitor {
    static let shared = FileLocationMonitor()

    private(set) var revision: UInt64 = 0
    private var missingIDs: Set<UUID> = []
    private var resolvedURLs: [UUID: URL] = [:]
    private var eventStream: FSEventStreamRef?
    private var onFilesystemChange: (() -> Void)?

    private init() {}

    func isMissing(id: UUID) -> Bool {
        missingIDs.contains(id)
    }

    func resolvedURL(for item: DownloadItem) -> URL? {
        if let cached = resolvedURLs[item.id] {
            return cached
        }
        guard let path = item.localFilePath, !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func isAvailable(id: UUID, item: DownloadItem) -> Bool {
        !isMissing(id: id) && resolvedURL(for: item) != nil
    }

    func start(onChange: @escaping () -> Void) {
        onFilesystemChange = onChange
    }

    func apply(state: CompletedFileState, for id: UUID) {
        switch state {
        case .available(let url):
            missingIDs.remove(id)
            resolvedURLs[id] = url
        case .missing:
            missingIDs.insert(id)
            resolvedURLs.removeValue(forKey: id)
        case .unknown:
            missingIDs.remove(id)
            resolvedURLs.removeValue(forKey: id)
        }
        revision &+= 1
    }

    func rebuildWatchList(for items: [DownloadItem]) {
        let directories = Set(
            items.compactMap { item -> String? in
                guard item.status == .completed,
                      let path = item.localFilePath,
                      !path.isEmpty else { return nil }
                return URL(fileURLWithPath: path).deletingLastPathComponent().path
            }
        )
        restartEventStream(paths: Array(directories))
    }

    private func restartEventStream(paths: [String]) {
        stopEventStream()
        guard !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            Self.eventCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.35,
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    private func stopEventStream() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    private func handleFilesystemEvent() {
        onFilesystemChange?()
    }

    private static let eventCallback: FSEventStreamCallback = { _, clientInfo, _, _, _, _ in
        guard let clientInfo else { return }
        let monitor = Unmanaged<FileLocationMonitor>.fromOpaque(clientInfo).takeUnretainedValue()
        Task { @MainActor in
            monitor.handleFilesystemEvent()
        }
    }
}
