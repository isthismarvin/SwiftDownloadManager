import Foundation

enum DomainPolicy: String, Codable, CaseIterable, Sendable {
    case `default`
    case autoStart
    case alwaysAsk
    case blocked

    var displayName: String {
        switch self {
        case .default: return L10n.t(de: "Standard (Dialog)", en: "Default (Dialog)")
        case .autoStart: return L10n.t(de: "Automatisch starten", en: "Auto-start")
        case .alwaysAsk: return L10n.t(de: "Immer nachfragen", en: "Always ask")
        case .blocked: return L10n.t(de: "Blockieren", en: "Block")
        }
    }
}

struct DomainRule: Codable, Equatable, Sendable {
    var pattern: String
    var policy: DomainPolicy
}

/// Per-host / wildcard download policies for incoming URLs.
enum DomainRuleStore {
    private static let rulesKey = "domainRules"
    private static let legacyAutoStartKey = "autoStartDomains"

    static func policy(for urlString: String) -> DomainPolicy {
        guard let host = host(from: urlString) else { return .default }
        return policy(forHost: host)
    }

    static func policy(forHost host: String) -> DomainPolicy {
        let normalized = normalize(host)
        guard !normalized.isEmpty else { return .default }
        migrateLegacyIfNeeded()

        let rules = allRules()
        if let match = rules.first(where: { matches(pattern: $0.pattern, host: normalized) }) {
            return match.policy
        }
        return .default
    }

    static func setPolicy(_ policy: DomainPolicy, forHost host: String) {
        let normalized = normalize(host)
        guard !normalized.isEmpty else { return }
        migrateLegacyIfNeeded()

        var rules = allRules().filter { normalize($0.pattern) != normalized }
        if policy != .default {
            rules.append(DomainRule(pattern: normalized, policy: policy))
        }
        save(rules)
    }

    static func allRules() -> [DomainRule] {
        migrateLegacyIfNeeded()
        guard let data = UserDefaults.standard.data(forKey: rulesKey),
              let rules = try? JSONDecoder().decode([DomainRule].self, from: data) else {
            return []
        }
        return rules.sorted { $0.pattern < $1.pattern }
    }

    static func host(from urlString: String) -> String? {
        guard let host = URL(string: urlString)?.host else { return nil }
        let normalized = normalize(host)
        return normalized.isEmpty ? nil : normalized
    }

    static func normalize(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Backward compatibility with AutoStartDomainStore callers.
    static func contains(host: String) -> Bool {
        policy(forHost: host) == .autoStart
    }

    static func add(host: String) {
        setPolicy(.autoStart, forHost: host)
    }

    static func addRule(pattern: String, policy: DomainPolicy) {
        let normalized = normalize(pattern)
        guard !normalized.isEmpty else { return }
        setPolicy(policy, forHost: normalized)
    }

    static func removeRule(pattern: String) {
        let normalized = normalize(pattern)
        guard !normalized.isEmpty else { return }
        migrateLegacyIfNeeded()
        let rules = allRules().filter { normalize($0.pattern) != normalized }
        save(rules)
    }

    static func clearAllRules() {
        UserDefaults.standard.removeObject(forKey: rulesKey)
        UserDefaults.standard.removeObject(forKey: legacyAutoStartKey)
    }

    private static func matches(pattern: String, host: String) -> Bool {
        let normalizedPattern = normalize(pattern)
        if normalizedPattern == host { return true }
        if normalizedPattern.hasPrefix("*.") {
            let suffix = String(normalizedPattern.dropFirst(2))
            return host == suffix || host.hasSuffix(".\(suffix)")
        }
        return false
    }

    private static func save(_ rules: [DomainRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
    }

    private static func migrateLegacyIfNeeded() {
        guard UserDefaults.standard.data(forKey: rulesKey) == nil,
              let legacy = UserDefaults.standard.stringArray(forKey: legacyAutoStartKey),
              !legacy.isEmpty else { return }

        let rules = legacy.map { DomainRule(pattern: normalize($0), policy: .autoStart) }
        save(rules)
        UserDefaults.standard.removeObject(forKey: legacyAutoStartKey)
    }
}
