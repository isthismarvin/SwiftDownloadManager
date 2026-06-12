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

final class AppSettings {
    static let shared = AppSettings()
    var conflictPolicy: DestinationConflictPolicy = .rename

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

    private init() {}

    func effectiveConflictPolicy(for downloadID: UUID) -> DestinationConflictPolicy {
        AppSettings.shared.conflictPolicy
    }
}

final class DownloadItem {
    let id = UUID()
    var saveDirectoryPath: String?

    init(saveDirectoryPath: String? = nil) {
        self.saveDirectoryPath = saveDirectoryPath
    }
}
