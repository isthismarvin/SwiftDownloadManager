import Foundation

// Minimal stand-ins so unit tests compile without the full app graph.
// The real types live in SwiftDownloadManager/; these are test-only.

enum AppConstants {
    static let urlScheme = "swiftdownloadmanager"
}

enum DestinationConflictPolicy: String, Codable, Sendable {
    case rename
    case overwrite
    case ask
}

enum DownloadSource {
    case paste
}

final class AppSettings {
    static let shared = AppSettings()
    var conflictPolicy: DestinationConflictPolicy = .rename
    var clipboardMonitoringEnabled: Bool = true

    private init() {}
}

enum DownloadPathResolver {
    static func preferredDefaultDirectory() -> URL {
        defaultDownloadsDirectory()
    }

    static func defaultDownloadsDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }
}

enum L10n {
    static func t(de: String, en: String) -> String { en }
}

final class DownloadManager {
    static let shared = DownloadManager()
    var modelContext: Any? = "context"

    private init() {}

    func effectiveConflictPolicy(for downloadID: UUID) -> DestinationConflictPolicy {
        AppSettings.shared.conflictPolicy
    }

    func receiveDownload(url: URL, source: DownloadSource = .paste) -> Any? {
        nil
    }
}

final class DownloadItem {
    let id = UUID()
    var saveDirectoryPath: String?

    init(saveDirectoryPath: String? = nil) {
        self.saveDirectoryPath = saveDirectoryPath
    }
}

enum DownloadSortOrder: String, CaseIterable, Identifiable, Codable {
    case dateAdded, name, size, speed, progress, eta, status
    var id: String { rawValue }
    var prefersAscending: Bool { self == .name }
}

struct ColumnWidths {
    var date: CGFloat = 108
    var progress: CGFloat = 160
    var speed: CGFloat = 90
    var status: CGFloat = 36
    var size: CGFloat = 80
    var eta: CGFloat = 75

    static let `default` = ColumnWidths()
    static let minWidth: CGFloat = 36
}

struct DownloadConfirmationOptions: Sendable {
    var fileName: String
    var urlString: String
    var preferredSegmentsCount: Int = 4
    var saveDirectory: URL?
    var startImmediately: Bool = true
    var priority: DownloadPriority = .normal
    var speedLimitBytesPerSecond: Int64?
    var scheduledStartAt: Date?
}

