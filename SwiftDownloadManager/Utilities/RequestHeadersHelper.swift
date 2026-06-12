import Foundation

enum RequestHeadersHelper {
    static func decode(_ json: String?) -> [String: String] {
        guard let json,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func encode(_ headers: [String: String]) -> String? {
        guard !headers.isEmpty,
              let data = try? JSONEncoder().encode(headers) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func applying(_ headers: [String: String], to request: inout URLRequest) {
        for (key, value) in headers where !key.isEmpty && !value.isEmpty {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}
