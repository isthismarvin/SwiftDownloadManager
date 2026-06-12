import Foundation

/// Resolves the Chrome companion extension folder for dev and release layouts.
enum ChromeExtensionLocator {
    private static let folderName = "ChromeExtension"

    /// Returns the extension directory if it exists on disk.
    static func directoryURL() -> URL? {
        candidateURLs().first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []

        if let bundled = Bundle.main.url(forResource: folderName, withExtension: nil) {
            urls.append(bundled)
        }

        if let resources = Bundle.main.resourceURL?.appendingPathComponent(folderName, isDirectory: true) {
            urls.append(resources)
        }

        // Sibling of the .app bundle (typical distribution layout).
        urls.append(
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent(folderName, isDirectory: true)
        )

        // Xcode build products: repo root next to the project.
        urls.append(
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(folderName, isDirectory: true)
        )

        // Source tree during development (Settings panel lives under Views/Settings/Panels).
        urls.append(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(folderName, isDirectory: true)
        )

        return urls
    }
}
