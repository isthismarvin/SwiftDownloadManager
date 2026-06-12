import Foundation

enum HTTPHeaderHelper {
    struct HEADResult {
        var supportsResume: Bool
        var contentLength: Int64
        var suggestedFileName: String?
    }

    static func parseHEADResponse(_ response: HTTPURLResponse) -> HEADResult {
        var supportsResume = false
        if let acceptRanges = response.value(forHTTPHeaderField: "Accept-Ranges"),
           acceptRanges.lowercased() == "bytes" {
            supportsResume = true
        }

        var contentLength: Int64 = -1
        if let contentLengthStr = response.value(forHTTPHeaderField: "Content-Length"),
           let length = Int64(contentLengthStr) {
            contentLength = length
        }

        let suggestedFileName = parseContentDisposition(
            response.value(forHTTPHeaderField: "Content-Disposition")
        )

        return HEADResult(
            supportsResume: supportsResume,
            contentLength: contentLength,
            suggestedFileName: suggestedFileName
        )
    }

    static func parseContentDisposition(_ header: String?) -> String? {
        guard let header else { return nil }

        // attachment; filename="example.zip" or filename*=UTF-8''example.zip
        if let range = header.range(of: "filename*=UTF-8''", options: .caseInsensitive) {
            var value = String(header[range.upperBound...])
            // Cut off any trailing parameters ("; size=…").
            if let semicolon = value.firstIndex(of: ";") {
                value = String(value[..<semicolon])
            }
            return value.removingPercentEncoding?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let range = header.range(of: "filename=", options: .caseInsensitive) {
            var value = String(header[range.upperBound...])
            if value.hasPrefix("\"") {
                value.removeFirst()
                if let endQuote = value.firstIndex(of: "\"") {
                    value = String(value[..<endQuote])
                }
            } else if let semicolon = value.firstIndex(of: ";") {
                value = String(value[..<semicolon])
            }
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    static func uniqueFileURL(in directory: URL, fileName: String) -> URL {
        targetFileURL(in: directory, fileName: fileName, policy: .rename)
    }

    static func targetFileURL(
        in directory: URL,
        fileName: String,
        policy: DestinationConflictPolicy
    ) -> URL {
        let fileManager = FileManager.default
        let candidate = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        switch policy {
        case .overwrite:
            return candidate
        case .rename, .ask:
            let ext = candidate.pathExtension
            let baseName = candidate.deletingPathExtension().lastPathComponent
            var counter = 1
            var resolved = candidate
            while fileManager.fileExists(atPath: resolved.path) {
                let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
                resolved = directory.appendingPathComponent(newName)
                counter += 1
            }
            return resolved
        }
    }
}
