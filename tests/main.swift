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

do {
    let raw = "POST /add HTTP/1.1\r\nOrigin: chrome-extension://abcdef\r\nX-SDM-Handshake: extension\r\nContent-Length: 2\r\n\r\n{}"
    let req = HTTPRequestParser.parse(data: Data(raw.utf8))
    expect(req != nil, "parses request with custom headers")
    expectEqual(req?.headers["origin"], "chrome-extension://abcdef", "origin header parsed")
    expectEqual(req?.headers["x-sdm-handshake"], "extension", "handshake header parsed")
}

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

// MARK: - SegmentPlanner.planDynamicSplit (Dynamic Re-segmentation)

print("SegmentPlanner.planDynamicSplit")
do {
    // Basic split of a 10MB segment with 0 bytes downloaded
    let segments = [
        SegmentInfo(index: 0, startOffset: 0, endOffset: 9_999_999, bytesReceived: 0, isCompleted: false)
    ]
    let split = SegmentPlanner.planDynamicSplit(
        segments: segments,
        activeTaskIndices: [0],
        maxConcurrentTasks: 4,
        currentActiveTaskCount: 1
    )
    expect(split != nil, "10 MB segment splits when 1 of 4 connections active")
    if let split {
        expectEqual(split.parentIndex, 0, "parent index is 0")
        expectEqual(split.parentNewEndOffset, 4_999_999, "parent gets first half [0 - 4,999,999]")
        expectEqual(split.childIndex, 1, "child index is 1")
        expectEqual(split.childStartOffset, 5_000_000, "child gets second half start [5,000,000]")
        expectEqual(split.childEndOffset, 9_999_999, "child gets second half end [9,999,999]")
        expectEqual(split.parentNewEndOffset + 1, split.childStartOffset, "parent and child are contiguous")
    }
}
do {
    // When current active tasks >= maxConcurrentTasks, should not split
    let segments = [
        SegmentInfo(index: 0, startOffset: 0, endOffset: 100_000_000, bytesReceived: 0, isCompleted: false)
    ]
    let split = SegmentPlanner.planDynamicSplit(
        segments: segments,
        activeTaskIndices: [0],
        maxConcurrentTasks: 1,
        currentActiveTaskCount: 1
    )
    expect(split == nil, "no split when task count reaches maxConcurrentTasks")
}
do {
    // When remaining un-downloaded bytes is below minSpanToSplit (4 MB)
    let segments = [
        SegmentInfo(index: 0, startOffset: 0, endOffset: 3_000_000, bytesReceived: 0, isCompleted: false)
    ]
    let split = SegmentPlanner.planDynamicSplit(
        segments: segments,
        activeTaskIndices: [0],
        maxConcurrentTasks: 4,
        currentActiveTaskCount: 1
    )
    expect(split == nil, "no split when remaining is under 4 MB threshold")
}
do {
    // Selects the segment with the largest remaining bytes
    let segments = [
        SegmentInfo(index: 0, startOffset: 0, endOffset: 9_999_999, bytesReceived: 4_000_000, isCompleted: false), // 6 MB remaining
        SegmentInfo(index: 1, startOffset: 10_000_000, endOffset: 29_999_999, bytesReceived: 0, isCompleted: false), // 20 MB remaining
        SegmentInfo(index: 2, startOffset: 30_000_000, endOffset: 39_999_999, bytesReceived: 39_000_000, isCompleted: true) // completed
    ]
    let split = SegmentPlanner.planDynamicSplit(
        segments: segments,
        activeTaskIndices: [0, 1],
        maxConcurrentTasks: 4,
        currentActiveTaskCount: 2
    )
    expect(split != nil, "splits largest candidate")
    if let split {
        expectEqual(split.parentIndex, 1, "chose segment 1 (20 MB remaining vs 6 MB)")
        expectEqual(split.childIndex, 3, "child index is next max index (2 + 1 = 3)")
        expectEqual(split.parentNewEndOffset, 19_999_999, "parent shortened to 19,999,999")
        expectEqual(split.childStartOffset, 20_000_000, "child starts at 20,000,000")
        expectEqual(split.childEndOffset, 29_999_999, "child ends at 29,999,999")
    }
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

// MARK: - ClipboardMonitor

print("ClipboardMonitor")
expect(ClipboardMonitor.extractDownloadableURL(from: "https://example.com/archive.zip") != nil, "detects .zip archive")
expect(ClipboardMonitor.extractDownloadableURL(from: "https://example.com/installer.dmg") != nil, "detects .dmg disk image")
expect(ClipboardMonitor.extractDownloadableURL(from: "https://example.com/video.mp4?token=abc") != nil, "detects .mp4 with query params")
expect(ClipboardMonitor.extractDownloadableURL(from: "https://example.com/document.pdf") != nil, "detects .pdf document")
expect(ClipboardMonitor.extractDownloadableURL(from: "https://example.com/article/home") == nil, "ignores regular web pages")
expect(ClipboardMonitor.extractDownloadableURL(from: "not a url") == nil, "ignores non-url text")
expect(ClipboardMonitor.extractDownloadableURL(from: "ftp://example.com/file.zip") == nil, "ignores non-http(s) schemes")

// MARK: - BatchURLParser

print("BatchURLParser")
do {
    let numericItems = BatchURLParser.parse(text: "https://example.com/file_[01-05].zip")
    expectEqual(numericItems.count, 5, "expands 5 numeric items with leading zero")
    expectEqual(numericItems.first?.url.absoluteString, "https://example.com/file_01.zip", "first item has 01")
    expectEqual(numericItems.last?.url.absoluteString, "https://example.com/file_05.zip", "last item has 05")
}

do {
    let unpaddedItems = BatchURLParser.parse(text: "https://example.com/file_[8-11].zip")
    expectEqual(unpaddedItems.count, 4, "expands unpadded range")
    expectEqual(unpaddedItems[0].url.absoluteString, "https://example.com/file_8.zip", "unpadded 8")
    expectEqual(unpaddedItems[3].url.absoluteString, "https://example.com/file_11.zip", "unpadded 11")
}

do {
    let charItems = BatchURLParser.parse(text: "https://example.com/part_[a-d].tar")
    expectEqual(charItems.count, 4, "expands character range")
    expectEqual(charItems[0].url.absoluteString, "https://example.com/part_a.tar", "part_a")
    expectEqual(charItems[3].url.absoluteString, "https://example.com/part_d.tar", "part_d")
}

do {
    let multiLineText = """
    Check these files:
    https://site.com/one.zip and also
    https://site.com/two.dmg
    <a href="https://site.com/three.pkg">link</a>
    """
    let extracted = BatchURLParser.parse(text: multiLineText)
    expectEqual(extracted.count, 3, "extracts 3 URLs from multi-line freeform text")
    expectEqual(extracted[0].fileName, "one.zip", "extracted one.zip")
    expectEqual(extracted[1].fileName, "two.dmg", "extracted two.dmg")
    expectEqual(extracted[2].fileName, "three.pkg", "extracted three.pkg")
}

// MARK: - FileChecksumService

print("FileChecksumService")
do {
    let testTempFile = FileManager.default.temporaryDirectory.appendingPathComponent("sdm_test_\(UUID().uuidString).txt")
    try? "hello world".data(using: .utf8)?.write(to: testTempFile)
    let sema = DispatchSemaphore(value: 0)
    var computedSHA: String?
    Task {
        computedSHA = try? await FileChecksumService.computeSHA256(for: testTempFile)
        sema.signal()
    }
    sema.wait()
    expectEqual(computedSHA, "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9", "computes exact SHA-256")
    try? FileManager.default.removeItem(at: testTempFile)
}

// MARK: - DownloadPriority & SpeedLimiter

print("DownloadPriority & SpeedLimiter")
do {
    expect(DownloadPriority.high.sortWeight > DownloadPriority.normal.sortWeight, "high priority has higher sort weight than normal")
    expect(DownloadPriority.normal.sortWeight > DownloadPriority.low.sortWeight, "normal priority has higher sort weight than low")
    expectEqual(DownloadPriority.high.displayName, "High", "high display name")
    expectEqual(DownloadPriority.low.displayName, "Low", "low display name")

    struct FakeItem {
        let name: String
        let priority: DownloadPriority
        let createdAt: Date
    }

    let t0 = Date(timeIntervalSince1970: 100)
    let t1 = Date(timeIntervalSince1970: 200)
    let t2 = Date(timeIntervalSince1970: 300)

    let items = [
        FakeItem(name: "low-early", priority: .low, createdAt: t0),
        FakeItem(name: "normal-mid", priority: .normal, createdAt: t1),
        FakeItem(name: "high-late", priority: .high, createdAt: t2),
        FakeItem(name: "high-early", priority: .high, createdAt: t0)
    ]

    let sorted = items.sorted { lhs, rhs in
        if lhs.priority.sortWeight != rhs.priority.sortWeight {
            return lhs.priority.sortWeight > rhs.priority.sortWeight
        }
        return lhs.createdAt < rhs.createdAt
    }

    expectEqual(sorted[0].name, "high-early", "highest priority earliest first")
    expectEqual(sorted[1].name, "high-late", "highest priority later second")
    expectEqual(sorted[2].name, "normal-mid", "normal priority third")
    expectEqual(sorted[3].name, "low-early", "low priority last")

    // SpeedLimitPreset
    expectEqual(SpeedLimitPreset.matching(bytes: nil), .unlimited, "nil bytes matches unlimited")
    expectEqual(SpeedLimitPreset.matching(bytes: 0), .unlimited, "0 bytes matches unlimited")
    expectEqual(SpeedLimitPreset.matching(bytes: 1_048_576), .mb1, "1MB matches mb1")
    expectEqual(SpeedLimitPreset.format(bytesPerSecond: 0), "Unlimited", "0 formats as unlimited")

    // SpeedLimiter
    let limiter = SpeedLimiter()
    limiter.setLimit(0)
    expectEqual(limiter.delayBeforeWrite(bytesCount: 1024), 0, "unlimited produces 0 delay")

    limiter.setLimit(1000)
    _ = limiter.delayBeforeWrite(bytesCount: 500)
    let delay2 = limiter.delayBeforeWrite(bytesCount: 500)
    expect(delay2 > 0, "consecutive chunk produces delay according to speed limit")
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
