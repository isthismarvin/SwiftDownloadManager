import Foundation

// Chaos/stress tests — compiled with tests/main.swift via scripts/run-chaos-tests.sh

func runChaosTests(failures: inout Int) {
    print("Chaos — FileNameSanitizer extremes")
    chaosExpect(!FileNameSanitizer.sanitize(String(repeating: "a", count: 100_000)).isEmpty, "100k filename does not empty", failures: &failures)
    chaosExpectEqual(FileNameSanitizer.sanitize("file:name?.zip"), "file-name?.zip", "macOS-invalid chars replaced", failures: &failures)
    chaosExpect(FileNameSanitizer.sanitize("‮evil.zip").hasSuffix(".zip"), "RTL override char preserved", failures: &failures)
    chaosExpectEqual(FileNameSanitizer.sanitize("   "), "download", "whitespace-only filename fallback", failures: &failures)

    print("Chaos — HTTPRequestParser flooding")
    for i in 0..<1000 {
        let body = "{\"url\":\"https://example.com/\(i)\"}"
        let data = makeHTTPRequest(method: "POST", path: "/add", body: body)
        chaosExpect(HTTPRequestParser.parse(data: data) != nil, "parse iteration \(i)", failures: &failures)
    }

    print("Chaos — RequestHeadersHelper size")
    var hugeHeaders: [String: String] = [:]
    for i in 0..<500 {
        hugeHeaders["X-Header-\(i)"] = String(repeating: "x", count: 1024)
    }
    if let encoded = RequestHeadersHelper.encode(hugeHeaders) {
        chaosExpect(encoded.utf8.count > 500_000, "500 KB header JSON encodes", failures: &failures)
        let decoded = RequestHeadersHelper.decode(encoded)
        chaosExpectEqual(decoded.count, 500, "500 headers round-trip", failures: &failures)
    } else {
        chaosFail("failed to encode huge headers", failures: &failures)
    }

    print("Chaos — DomainRuleStore garbage patterns")
    DomainRuleStore.setPolicy(.autoStart, forHost: String(repeating: "x", count: 10_000))
    chaosExpect(DomainRuleStore.policy(forHost: String(repeating: "x", count: 10_000)) == .autoStart, "10k host rule stored", failures: &failures)
    DomainRuleStore.setPolicy(.default, forHost: String(repeating: "x", count: 10_000))

    print("Chaos — URLSchemeParser injection attempts")
    chaosExpect(URLSchemeParser.downloadURL(from: URL(string: "swiftdownloadmanager://add?url=file:///etc/passwd")!) == nil, "file scheme rejected", failures: &failures)
    let longPath = String(repeating: "a", count: 50_000)
    let schemeURL = URL(string: "swiftdownloadmanager://add?url=https%3A%2F%2Fexample.com%2F\(longPath)")!
    let parsed = URLSchemeParser.downloadURL(from: schemeURL)
    if parsed != nil {
        print("  WARN – URL scheme accepts very long URLs (\(parsed!.absoluteString.count) chars)")
    } else {
        print("  ok – URL scheme rejects/overlong encoded URL at parser level")
    }

    print("Chaos — SegmentIndexMap stress")
    var segments: [SegmentInfo] = []
    segments.reserveCapacity(10_000)
    for i in 0..<10_000 {
        segments.append(SegmentInfo(index: i % 100, startOffset: Int64(i), endOffset: Int64(i + 1), bytesReceived: 0, isCompleted: false))
    }
    let map = SegmentIndexMap.make(from: segments)
    chaosExpectEqual(map.count, 100, "10k segments with 100 duplicate indices collapse", failures: &failures)

    print("Chaos — filter simulation (O(n*m))")
    let query = String(repeating: "z", count: 10_000)
    let items = (0..<2000).map { i in ("file\(i).zip", "https://example.com/file\(i).zip") }
    let start = CFAbsoluteTimeGetCurrent()
    let _ = items.filter { $0.0.lowercased().contains(query.lowercased()) || $0.1.lowercased().contains(query.lowercased()) }
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    chaosExpect(elapsed < 1.0, "2000-item filter with 10k query under 1s (was \(elapsed)s)", failures: &failures)
    if elapsed > 0.05 {
        print("  WARN – filter took \(String(format: "%.3f", elapsed))s (UI jank risk)")
    }
}

private func chaosExpect(_ condition: Bool, _ message: String, failures: inout Int) {
    if condition {
        print("  ok – \(message)")
    } else {
        failures += 1
        print("  FAIL – \(message)")
    }
}

private func chaosExpectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, failures: inout Int) {
    chaosExpect(actual == expected, "\(message) [actual: \(actual), expected: \(expected)]", failures: &failures)
}

private func chaosFail(_ message: String, failures: inout Int) {
    failures += 1
    print("  FAIL – \(message)")
}
