import Foundation

enum AuthType: String, Codable, CaseIterable, Sendable {
    case basic
    case bearer

    var displayName: String {
        switch self {
        case .basic: return L10n.t(de: "HTTP Basic (Benutzer / Passwort)", en: "HTTP Basic (User / Password)")
        case .bearer: return L10n.t(de: "Bearer Token", en: "Bearer Token")
        }
    }
}

struct SiteCredential: Codable, Identifiable, Equatable, Sendable {
    var id: String { host }
    var host: String
    var username: String
    var secret: String // password or token
    var authType: AuthType

    var authorizationHeaderValue: String {
        switch authType {
        case .basic:
            let raw = "\(username):\(secret)"
            let base64 = Data(raw.utf8).base64EncodedString()
            return "Basic \(base64)"
        case .bearer:
            return "Bearer \(secret.isEmpty ? username : secret)"
        }
    }
}

/// Thread-safe store for site logins and authentication credentials.
enum SiteCredentialStore {
    private static let storageKey = "siteCredentials"
    private static let lock = NSLock()

    static func credential(for url: URL) -> SiteCredential? {
        guard let host = url.host else { return nil }
        return credential(forHost: host)
    }

    static func credential(forHost host: String) -> SiteCredential? {
        let normalized = normalize(host)
        guard !normalized.isEmpty else { return nil }

        lock.lock()
        defer { lock.unlock() }

        let list = loadLocked()
        return list.first { matches(pattern: $0.host, host: normalized) }
    }

    static func save(_ credential: SiteCredential) {
        let normalized = normalize(credential.host)
        guard !normalized.isEmpty else { return }

        var item = credential
        item.host = normalized

        lock.lock()
        defer { lock.unlock() }

        var list = loadLocked().filter { normalize($0.host) != normalized }
        list.append(item)
        saveLocked(list)
    }

    static func remove(host: String) {
        let normalized = normalize(host)
        guard !normalized.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        let list = loadLocked().filter { normalize($0.host) != normalized }
        saveLocked(list)
    }

    static func allCredentials() -> [SiteCredential] {
        lock.lock()
        defer { lock.unlock() }
        return loadLocked()
    }

    // MARK: - Private Helpers

    private static func normalize(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func matches(pattern: String, host: String) -> Bool {
        let pat = normalize(pattern)
        let h = normalize(host)
        if pat == h { return true }
        if pat.hasPrefix("*.") {
            let suffix = String(pat.dropFirst(2))
            return h.hasSuffix(suffix) || h == suffix
        }
        return false
    }

    private static func loadLocked() -> [SiteCredential] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let list = try? JSONDecoder().decode([SiteCredential].self, from: data) else {
            return []
        }
        return list
    }

    private static func saveLocked(_ list: [SiteCredential]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
