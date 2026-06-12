import Foundation

enum URLSchemeParser {
    /// Extracts an HTTP(S) download URL from a custom-scheme deep link.
    ///
    /// Supported forms:
    /// - `swiftdownloadmanager://add?url=https%3A%2F%2Fexample.com%2Ffile.zip`
    /// - `swiftdownloadmanager://https/example.com/file.zip`
    /// - `swiftdownloadmanager:///https://example.com/file.zip`
    static func downloadURL(from incoming: URL) -> URL? {
        guard incoming.scheme?.lowercased() == AppConstants.urlScheme else { return nil }

        if let components = URLComponents(url: incoming, resolvingAgainstBaseURL: false),
           let raw = components.queryItems?.first(where: { $0.name == "url" })?.value {
            let decoded = raw.removingPercentEncoding ?? raw
            if let url = URL(string: decoded), isHTTP(url) {
                return url
            }
        }

        if let host = incoming.host?.lowercased(),
           host == "http" || host == "https" {
            let path = incoming.path.removingPercentEncoding ?? incoming.path
            let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
            guard !trimmed.isEmpty else { return nil }
            if let url = URL(string: "\(host)://\(trimmed)"), isHTTP(url) {
                return url
            }
        }

        let path = incoming.path.removingPercentEncoding ?? incoming.path
        if path.hasPrefix("/http://") || path.hasPrefix("/https://") {
            let trimmed = String(path.dropFirst())
            if let url = URL(string: trimmed), isHTTP(url) {
                return url
            }
        }

        return nil
    }

    private static func isHTTP(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
