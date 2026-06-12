import Foundation

enum RecentDestinationsStore {
    private static let key = "recentDownloadDestinations"
    private static let maxCount = 5

    static func record(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var paths = all().filter { $0 != trimmed }
        paths.insert(trimmed, at: 0)
        UserDefaults.standard.set(Array(paths.prefix(maxCount)), forKey: key)
    }

    static func all() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func quickPickURLs() -> [URL] {
        let defaults = DownloadPathResolver.defaultDownloadsDirectory().path
        var paths = [defaults]
        for path in all() where path != defaults {
            paths.append(path)
        }
        return paths.prefix(maxCount + 1).map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
}
