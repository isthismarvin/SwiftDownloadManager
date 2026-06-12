import Foundation

// Unit-Test-Runner (ohne XCTest-Target): wird per swiftc zusammen mit den
// getesteten Quelldateien kompiliert. Aufruf siehe tests/README.md.

var failures = 0

func expect(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        print("  ok – \(message)")
    } else {
        failures += 1
        print("  FAIL – \(message) (\(file):\(line))")
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, line: Int = #line) {
    expect(actual == expected, "\(message) [actual: \(actual), expected: \(expected)]", line: line)
}

// MARK: - FileNameSanitizer

print("FileNameSanitizer")
expectEqual(FileNameSanitizer.sanitize("report.pdf"), "report.pdf", "plain name passes through")
expectEqual(FileNameSanitizer.sanitize("../../.zshrc"), ".zshrc", "path traversal collapses to last component")
expectEqual(FileNameSanitizer.sanitize("/etc/passwd"), "passwd", "absolute path collapses to last component")
expectEqual(FileNameSanitizer.sanitize("a/b/c.txt"), "c.txt", "nested path collapses")
expectEqual(FileNameSanitizer.sanitize(""), "download", "empty name falls back")
expectEqual(FileNameSanitizer.sanitize(".."), "download", "dot-dot falls back")
expectEqual(FileNameSanitizer.sanitize("  spaced.zip  "), "spaced.zip", "whitespace trimmed")
expectEqual(FileNameSanitizer.sanitize("evil\u{0}.txt"), "evil.txt", "null bytes removed")
expectEqual(FileNameSanitizer.sanitize("file:name?.zip"), "file-name?.zip", "invalid macOS chars replaced")
expectEqual(FileNameSanitizer.sanitize("📦 release.zip"), "📦 release.zip", "emoji filename preserved")
expectEqual(FileNameSanitizer.sanitize(String(repeating: "a", count: 512)), String(repeating: "a", count: 512), "very long filename preserved")

// MARK: - HTTPRequestParser

print("HTTPRequestParser")

func makeHTTPRequest(method: String, path: String, body: String = "", contentLength: Int? = nil) -> Data {
    let length = contentLength ?? body.utf8.count
    let head = "\(method) \(path) HTTP/1.1\r\nContent-Length: \(length)\r\n\r\n\(body)"
    return Data(head.utf8)
}

do {
    let payload = #"{"url":"https://example.com/file.zip"}"#
    let request = HTTPRequestParser.parse(data: makeHTTPRequest(method: "POST", path: "/add", body: payload))
    expect(request != nil, "valid POST /add parses")
    expectEqual(request?.method, "POST", "method parsed")
    expectEqual(request?.path, "/add", "path parsed")
    expectEqual(String(data: request?.body ?? Data(), encoding: .utf8), payload, "body parsed")
} 

expect(HTTPRequestParser.parse(data: makeHTTPRequest(method: "POST", path: "/add", body: "{}", contentLength: -1)) == nil, "negative Content-Length rejected")
expect(HTTPRequestParser.parse(data: makeHTTPRequest(method: "GET", path: "/ping", body: "", contentLength: 0)) != nil, "zero Content-Length accepted")
expect(HTTPRequestParser.parse(data: Data("   \r\n\r\n".utf8)) == nil, "blank request line rejected")
expect(
    HTTPRequestParser.parse(data: makeHTTPRequest(method: "POST", path: "/add", body: "x", contentLength: HTTPRequestParser.maxBodySize + 1)) == nil,
    "oversized Content-Length rejected"
)

// MARK: - SegmentIndexMap

print("SegmentIndexMap")
do {
    let segments = [
        SegmentInfo(index: 0, startOffset: 0, endOffset: 100, bytesReceived: 0, isCompleted: false),
        SegmentInfo(index: 0, startOffset: 0, endOffset: 200, bytesReceived: 0, isCompleted: false),
        SegmentInfo(index: 1, startOffset: 101, endOffset: 300, bytesReceived: 0, isCompleted: false),
    ]
    let map = SegmentIndexMap.make(from: segments)
    expectEqual(map.count, 2, "duplicate indices collapse")
    expectEqual(map[0]?.endOffset, 200, "last duplicate wins")
    expectEqual(map[1]?.endOffset, 300, "unique index preserved")
}


print("HTTPHeaderHelper.parseContentDisposition")
expectEqual(
    HTTPHeaderHelper.parseContentDisposition(#"attachment; filename="example.zip""#),
    "example.zip",
    "quoted filename"
)
expectEqual(
    HTTPHeaderHelper.parseContentDisposition("attachment; filename=plain.txt"),
    "plain.txt",
    "unquoted filename"
)
expectEqual(
    HTTPHeaderHelper.parseContentDisposition("attachment; filename=first.txt; size=42"),
    "first.txt",
    "unquoted filename cut at semicolon"
)
expectEqual(
    HTTPHeaderHelper.parseContentDisposition("attachment; filename*=UTF-8''na%C3%AFve%20file.tar.gz"),
    "naïve file.tar.gz",
    "RFC 5987 encoded filename"
)
expectEqual(
    HTTPHeaderHelper.parseContentDisposition("attachment; filename*=UTF-8''enc.bin; size=42"),
    "enc.bin",
    "RFC 5987 filename cut at semicolon"
)
expectEqual(
    HTTPHeaderHelper.parseContentDisposition("inline"),
    nil,
    "no filename yields nil"
)
expectEqual(
    HTTPHeaderHelper.parseContentDisposition(nil),
    nil,
    "nil header yields nil"
)

// MARK: - SegmentCountPolicy

print("SegmentCountPolicy")
do {
    let tiers = SegmentCountPolicy.defaultTiers
    expectEqual(
        SegmentCountPolicy.connections(for: 2 * 1_048_576, tiers: tiers, fallback: 4),
        1,
        "2 MB uses 1 connection"
    )
    expectEqual(
        SegmentCountPolicy.connections(for: 30 * 1_048_576, tiers: tiers, fallback: 4),
        2,
        "30 MB uses 2 connections"
    )
    expectEqual(
        SegmentCountPolicy.connections(for: 500 * 1_048_576, tiers: tiers, fallback: 4),
        6,
        "500 MB uses 6 connections"
    )
    expectEqual(
        SegmentCountPolicy.connections(for: 5 * 1_024 * 1_048_576, tiers: tiers, fallback: 4),
        8,
        "5 GB uses catch-all connections"
    )
    expectEqual(
        SegmentCountPolicy.connections(for: 0, tiers: tiers, fallback: 4),
        4,
        "unknown size uses fallback"
    )
}

// MARK: - SegmentPlanner

print("SegmentPlanner")
do {
    let plan = SegmentPlanner.plan(bytesTotal: 100_000_000, preferredCount: 4, supportsResume: true)
    expectEqual(plan.count, 4, "100 MB / 4 segments")
    expectEqual(plan[0].startOffset, 0, "first segment starts at 0")
    expectEqual(plan[3].endOffset, 99_999_999, "last segment ends at bytesTotal-1")
    var covered: Int64 = 0
    for (i, seg) in plan.enumerated() {
        expect(seg.endOffset >= seg.startOffset, "segment \(i) non-empty")
        if i > 0 {
            expectEqual(seg.startOffset, plan[i - 1].endOffset + 1, "segment \(i) is contiguous")
        }
        covered += seg.endOffset - seg.startOffset + 1
    }
    expectEqual(covered, 100_000_000, "segments cover the whole file")
}
do {
    let plan = SegmentPlanner.plan(bytesTotal: 500_000, preferredCount: 8, supportsResume: true)
    expectEqual(plan.count, 1, "tiny file gets a single segment")
    expectEqual(plan[0].endOffset, 499_999, "single segment is a closed range")
}
do {
    let plan = SegmentPlanner.plan(bytesTotal: 3_000_000, preferredCount: 8, supportsResume: true)
    expectEqual(plan.count, 2, "3 MB capped at 2 segments (min 1 MB each)")
}
do {
    let plan = SegmentPlanner.plan(bytesTotal: 100_000_000, preferredCount: 4, supportsResume: false)
    expectEqual(plan.count, 1, "no range support yields a single segment")
    expectEqual(plan[0].endOffset, -1, "single stream is open-ended")
}
do {
    let plan = SegmentPlanner.plan(bytesTotal: -1, preferredCount: 4, supportsResume: true)
    expectEqual(plan.count, 1, "unknown size yields a single segment")
    expectEqual(plan[0].endOffset, -1, "unknown size is open-ended")
}

// MARK: - SpeedLimiter

print("SpeedLimiter")
do {
    let limiter = SpeedLimiter()
    expectEqual(limiter.delayBeforeWrite(bytesCount: 1_000_000), 0, "no limit means no delay")

    limiter.setLimit(1_000_000) // 1 MB/s
    let first = limiter.delayBeforeWrite(bytesCount: 500_000)
    expect(first < 0.01, "first chunk passes immediately [\(first)]")
    let second = limiter.delayBeforeWrite(bytesCount: 500_000)
    expect(abs(second - 0.5) < 0.05, "second chunk waits ~0.5 s [\(second)]")
    let third = limiter.delayBeforeWrite(bytesCount: 1_000_000)
    expect(abs(third - 1.0) < 0.05, "third chunk waits ~1.0 s [\(third)]")
}
do {
    // Atomic reservation: concurrent callers must serialize against the limit.
    let limiter = SpeedLimiter()
    limiter.setLimit(10_000_000) // 10 MB/s
    let group = DispatchGroup()
    let lock = NSLock()
    var totalDelayedBytes: Double = 0
    var maxDelay: TimeInterval = 0
    for _ in 0..<20 {
        group.enter()
        DispatchQueue.global().async {
            let delay = limiter.delayBeforeWrite(bytesCount: 1_000_000)
            lock.lock()
            maxDelay = max(maxDelay, delay)
            totalDelayedBytes += 1_000_000
            lock.unlock()
            group.leave()
        }
    }
    group.wait()
    // 20 MB at 10 MB/s: the last chunk must be scheduled ~1.9 s out. Without
    // atomic reservation every caller would get ~0 delay (the old N-fold bug).
    expect(maxDelay > 1.5, "20 concurrent chunks serialize against the limit [maxDelay \(maxDelay)]")
}

// MARK: - DomainRuleStore

runDomainRuleStoreTests()

// MARK: - DestinationConflictResolver

print("DestinationConflictResolver")
do {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("sdm-unittest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let existing = tmp.appendingPathComponent("report.pdf")
    FileManager.default.createFile(atPath: existing.path, contents: Data("x".utf8))

    let renamed = HTTPHeaderHelper.targetFileURL(in: tmp, fileName: "report.pdf", policy: .rename)
    expectEqual(renamed.lastPathComponent, "report (1).pdf", "rename policy picks next free name")

    MainActor.assumeIsolated {
        AppSettings.shared.conflictPolicy = .rename
        let item = DownloadItem(saveDirectoryPath: tmp.path)
        let preview = DestinationConflictResolver.preview(for: item, fileName: "report.pdf")
        expect(preview?.willRename == true, "preview detects existing file")
        expectEqual(preview?.resolvedFileName, "report (1).pdf", "preview resolved file name")

        let noRenamePreview = DestinationConflictResolver.Preview(
            directory: tmp,
            resolvedFileName: "new.bin",
            willRename: false
        )
        expect(DestinationConflictResolver.message(for: noRenamePreview) == nil, "no message when not renaming")

        let renamePreview = DestinationConflictResolver.Preview(
            directory: tmp,
            resolvedFileName: "report (1).pdf",
            willRename: true
        )
        let message = DestinationConflictResolver.message(for: renamePreview)
        expect(message?.contains("report (1).pdf") == true, "rename message mentions resolved name [\(message ?? "nil")]")
    }
}

// MARK: - Chaos / stress

runChaosTests(failures: &failures)

// MARK: - Result

if failures > 0 {
    print("\n\(failures) TEST(S) FAILED")
    exit(1)
}
print("\nALL TESTS PASSED")
exit(0)
