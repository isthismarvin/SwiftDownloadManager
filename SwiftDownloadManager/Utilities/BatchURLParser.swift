import Foundation

struct BatchURLItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    var isSelected: Bool = true

    var fileName: String {
        let name = url.lastPathComponent
        return name.isEmpty ? "download" : name
    }
}

enum BatchURLParser: Sendable {
    static let maxExpansionLimit = 500

    /// Parses text which may contain URL patterns (e.g. `[01-20]`, `[a-z]`) or multiple URLs.
    static func parse(text: String) -> [BatchURLItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Only single-line input can be a pattern template
        if !trimmed.contains("\n"), let patternItems = expandPatternIfPresent(trimmed), !patternItems.isEmpty {
            return patternItems
        }

        // Otherwise, extract all URLs from multi-line or whitespace-separated text
        return extractURLs(from: text)
    }

    /// Expands numeric `[01-20]` or character `[a-z]` patterns in a single URL template.
    static func expandPatternIfPresent(_ template: String) -> [BatchURLItem]? {
        let regexPattern = #"(?i)\[(\d+)-(\d+)\]|\[([a-zA-Z])-([a-zA-Z])\]"#
        guard let regex = try? NSRegularExpression(pattern: regexPattern) else { return nil }
        let nsRange = NSRange(template.startIndex..<template.endIndex, in: template)
        guard let match = regex.firstMatch(in: template, range: nsRange) else { return nil }

        // Check if numeric match
        if let range1 = Range(match.range(at: 1), in: template),
           let range2 = Range(match.range(at: 2), in: template) {
            let startStr = String(template[range1])
            let endStr = String(template[range2])
            guard let startNum = Int(startStr), let endNum = Int(endStr) else { return nil }

            let minNum = min(startNum, endNum)
            let maxNum = max(startNum, endNum)
            let count = maxNum - minNum + 1
            guard count > 0 && count <= maxExpansionLimit else { return nil }

            let padLength = max(startStr.count, endStr.count)
            let isPadded = startStr.hasPrefix("0") || endStr.hasPrefix("0")

            guard let matchRange = Range(match.range, in: template) else { return nil }

            var results: [BatchURLItem] = []
            let sequence = startNum <= endNum ? Array(stride(from: startNum, through: endNum, by: 1)) : Array(stride(from: startNum, through: endNum, by: -1))
            for num in sequence {
                let formattedNum: String
                if isPadded {
                    formattedNum = String(format: "%0*d", padLength, num)
                } else {
                    formattedNum = "\(num)"
                }
                var expanded = template
                expanded.replaceSubrange(matchRange, with: formattedNum)
                let cleaned = expanded.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: cleaned),
                   let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https") {
                    results.append(BatchURLItem(url: url))
                }
            }
            return results
        }

        // Check if character match
        if let range1 = Range(match.range(at: 3), in: template),
           let range2 = Range(match.range(at: 4), in: template),
           let char1 = template[range1].first,
           let char2 = template[range2].first,
           let ascii1 = char1.asciiValue,
           let ascii2 = char2.asciiValue {
            let start = Int(ascii1)
            let end = Int(ascii2)
            let count = abs(end - start) + 1
            guard count > 0 && count <= maxExpansionLimit else { return nil }

            guard let matchRange = Range(match.range, in: template) else { return nil }

            var results: [BatchURLItem] = []
            let sequence = start <= end ? Array(stride(from: start, through: end, by: 1)) : Array(stride(from: start, through: end, by: -1))
            for val in sequence {
                guard let unicode = UnicodeScalar(val) else { continue }
                let charStr = String(Character(unicode))
                var expanded = template
                expanded.replaceSubrange(matchRange, with: charStr)
                let cleaned = expanded.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: cleaned),
                   let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https") {
                    results.append(BatchURLItem(url: url))
                }
            }
            return results
        }

        return nil
    }

    /// Extracts all http/https URLs from arbitrary text.
    static func extractURLs(from text: String) -> [BatchURLItem] {
        let nsText = text as NSString
        let regexPattern = #"(?i)https?://[a-z0-9_.\-~:/?#@!$&'*+,;=%]+"#
        guard let regex = try? NSRegularExpression(pattern: regexPattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var seen = Set<String>()
        var results: [BatchURLItem] = []

        for match in matches {
            var candidate = nsText.substring(with: match.range)
            while let last = candidate.last, [".", ",", ";", ":"].contains(last) {
                candidate.removeLast()
            }
            if let url = URL(string: candidate), !seen.contains(url.absoluteString) {
                seen.insert(url.absoluteString)
                results.append(BatchURLItem(url: url))
            }
        }
        return results
    }
}
