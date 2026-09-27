import Foundation

/// Tiny HTTP/1.1 request parser, just enough for the Chrome extension endpoints.
enum HTTPRequestParser {
    /// Maximum request body size accepted by the local companion server.
    static let maxBodySize = 1_048_576

    struct ParsedRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data

        init(method: String, path: String, headers: [String: String] = [:], body: Data = Data()) {
            self.method = method
            self.path = path
            self.headers = headers
            self.body = body
        }
    }

    /// Returns nil while the request is still incomplete, or when the request is malformed.
    static func parse(data: Data) -> ParsedRequest? {
        guard let headEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }

        let headData = data.subdata(in: data.startIndex..<headEnd.lowerBound)
        guard let head = String(data: headData, encoding: .utf8) else { return nil }

        let lines = head.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else { return nil }

        let requestLineParts = requestLine.split(separator: " ")
        guard requestLineParts.count >= 2 else { return nil }

        var contentLength = 0
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            headers[key] = value
            if key == "content-length" {
                contentLength = Int(value) ?? 0
            }
        }

        guard contentLength >= 0, contentLength <= maxBodySize else { return nil }

        let bodyStart = headEnd.upperBound
        let availableBody = data.count - data.distance(from: data.startIndex, to: bodyStart)
        guard availableBody >= contentLength else { return nil }

        let method = String(requestLineParts[0]).uppercased()
        let path = String(requestLineParts[1])
        let body = data.subdata(in: bodyStart..<data.index(bodyStart, offsetBy: contentLength))
        return ParsedRequest(method: method, path: path, headers: headers, body: body)
    }
}
