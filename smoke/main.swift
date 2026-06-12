import Foundation

// Smoke-Test-Harness für DownloadEngine (wird nicht mit der App ausgeliefert).
// Aufruf: enginetest <url> <bytesTotal> <complete|pause>

let args = CommandLine.arguments
guard args.count >= 4,
      let url = URL(string: args[1]),
      let total = Int64(args[2]) else {
    print("usage: enginetest <url> <bytesTotal> <complete|pause>")
    exit(2)
}
let mode = args[3]

let engine = DownloadEngine()
let filePath = NSTemporaryDirectory() + "engine-smoke-\(mode).bin"
try? FileManager.default.removeItem(atPath: filePath)

func makeSegments(count: Int, total: Int64) -> [SegmentInfo] {
    let size = total / Int64(count)
    return (0..<count).map { i in
        let start = Int64(i) * size
        let end = (i == count - 1) ? total - 1 : start + size - 1
        return SegmentInfo(index: i, startOffset: start, endOffset: end, bytesReceived: 0, isCompleted: false)
    }
}

let id = UUID()
let done = DispatchSemaphore(value: 0)
var sawPause = false
var pauseTriggered = false

Task {
    for await event in engine.eventStream {
        switch event {
        case .progress(_, let received, let bytesTotal):
            if received % (5 * 1024 * 1024) < 65536 {
                print("progress \(received)/\(bytesTotal)")
            }
            if mode == "pause" && !pauseTriggered && received > 2 * 1024 * 1024 {
                pauseTriggered = true
                DispatchQueue.global().async {
                    print("PAUSING (progress-based)")
                    engine.pauseDownload(id: id)
                }
            }
        case .paused(_, let segments, let received, _):
            sawPause = true
            print("PAUSED at \(received) bytes, segments: \(segments.map(\.bytesReceived))")
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                print("RESUMING")
                engine.startSegmentedDownload(
                    id: id, url: url, filePath: filePath,
                    bytesTotal: total, segments: segments
                )
            }
        case .completed(_, let localURL):
            print("COMPLETED \(localURL.path)")
            done.signal()
        case .failed(_, let error):
            print("FAILED \(error.localizedDescription)")
            exit(1)
        case .restartedAsSingleStream(_, let bytesTotal):
            print("RESTARTED AS SINGLE STREAM (total \(bytesTotal))")
        case .segmentProgress:
            break
        }
    }
}

let limitBytesPerSecond: Int64 = args.count > 4 ? (Int64(args[4]) ?? 2_000_000) : 2_000_000
if mode == "limit" {
    engine.setSpeedLimit(limitBytesPerSecond)
}

let startTime = Date()
print("starting \(mode) test → \(filePath)")
engine.startSegmentedDownload(
    id: id, url: url, filePath: filePath,
    bytesTotal: total, segments: makeSegments(count: 4, total: total)
)

let result = done.wait(timeout: .now() + 120)
guard result == .success else {
    print("TIMEOUT — download did not complete in 120 s")
    exit(1)
}
if mode == "pause" && !sawPause {
    print("WARNING: pause event never arrived")
    exit(1)
}

let attrs = try FileManager.default.attributesOfItem(atPath: filePath)
let size = attrs[.size] as? Int64 ?? -1
print("final size \(size), expected \(total): \(size == total ? "OK" : "MISMATCH")")

let peakMB = Double(peakResidentBytes()) / 1_048_576
print(String(format: "peak resident memory overall: %.0f MB", peakMB))

if mode == "limit" {
    let elapsed = Date().timeIntervalSince(startTime)
    let expected = Double(total) / Double(limitBytesPerSecond)
    print(String(format: "elapsed %.1f s (expected ≥ %.1f s at limit)", elapsed, expected * 0.85))
    let peakMemoryMB = Double(peakResidentBytes()) / 1_048_576
    print(String(format: "peak resident memory: %.0f MB", peakMemoryMB))
    guard elapsed >= expected * 0.85 else {
        print("LIMIT VIOLATED — finished too fast")
        exit(1)
    }
}
exit(size == total ? 0 : 1)

func peakResidentBytes() -> UInt64 {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return UInt64(usage.ru_maxrss)
}
