import Foundation

enum FileNameSanitizer {
    /// Characters that are invalid in macOS file names (path separators and reserved symbols).
    private static let forbiddenCharacters = CharacterSet(charactersIn: ":/\\")

    /// Reduces an untrusted file name (server header, URL path, user input) to
    /// a safe single path component. Prevents path traversal via names like
    /// "../../.zshrc" or absolute paths injected through Content-Disposition.
    static func sanitize(_ raw: String) -> String {
        var name = raw
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse any path structure to its last component. Deliberately not
        // URL(fileURLWithPath:) — that resolves "" and ".." against the
        // current directory instead of treating them literally.
        name = name.split(separator: "/").last.map(String.init) ?? ""

        name = String(name.unicodeScalars.map { forbiddenCharacters.contains($0) ? "-" : Character($0) })

        // Collapse consecutive replacement dashes for readability.
        while name.contains("--") {
            name = name.replacingOccurrences(of: "--", with: "-")
        }

        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        if name.isEmpty || name == "." || name == ".." {
            return "download"
        }
        return name
    }
}
