import Foundation

func resetDomainRules() {
    UserDefaults.standard.removeObject(forKey: "domainRules")
    UserDefaults.standard.removeObject(forKey: "autoStartDomains")
}

func runDomainRuleStoreTests() {
    print("DomainRuleStore")

    resetDomainRules()
    expectEqual(DomainRuleStore.normalize("  Example.COM  "), "example.com", "normalize trims and lowercases")
    expectEqual(DomainRuleStore.host(from: "https://cdn.example.com/path"), "cdn.example.com", "host from https URL")
    expect(DomainRuleStore.host(from: "not-a-url") == nil, "invalid URL yields nil host")

    resetDomainRules()
    expectEqual(DomainRuleStore.policy(forHost: "unknown.example"), .default, "no rules yields default")

    resetDomainRules()
    DomainRuleStore.setPolicy(.autoStart, forHost: "files.example.com")
    expectEqual(DomainRuleStore.policy(forHost: "files.example.com"), .autoStart, "exact host match")
    expectEqual(DomainRuleStore.policy(for: "https://files.example.com/a.zip"), .autoStart, "policy from URL")

    resetDomainRules()
    DomainRuleStore.addRule(pattern: "*.cdn.net", policy: .blocked)
    expectEqual(DomainRuleStore.policy(forHost: "cdn.net"), .blocked, "wildcard matches base domain")
    expectEqual(DomainRuleStore.policy(forHost: "assets.cdn.net"), .blocked, "wildcard matches subdomain")
    expectEqual(DomainRuleStore.policy(forHost: "other.net"), .default, "wildcard does not over-match")

    resetDomainRules()
    DomainRuleStore.setPolicy(.alwaysAsk, forHost: "ask.example")
    DomainRuleStore.setPolicy(.default, forHost: "ask.example")
    expectEqual(DomainRuleStore.policy(forHost: "ask.example"), .default, "default policy removes rule")

    resetDomainRules()
    UserDefaults.standard.set(["Legacy.Host"], forKey: "autoStartDomains")
    expectEqual(DomainRuleStore.policy(forHost: "legacy.host"), .autoStart, "legacy autoStartDomains migrates")
    expect(UserDefaults.standard.stringArray(forKey: "autoStartDomains") == nil, "legacy key removed after migration")

    resetDomainRules()
    DomainRuleStore.setPolicy(.blocked, forHost: "remove.me")
    expectEqual(DomainRuleStore.allRules().count, 1, "one rule stored")
    DomainRuleStore.removeRule(pattern: "remove.me")
    expectEqual(DomainRuleStore.allRules().count, 0, "removeRule clears entry")
}
