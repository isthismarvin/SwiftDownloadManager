import Foundation

/// Speed limiter shared across downloads, based on a virtual clock.
/// Each chunk atomically reserves a time slot proportional to its size, so the
/// combined throughput of any number of concurrent segments never exceeds the
/// limit (the previous token bucket let N segments overshoot N-fold).
final class SpeedLimiter: @unchecked Sendable {
    private let lock = NSLock()
    private var limit: Int64 = 0
    private var nextSlot = Date.distantPast

    func setLimit(_ limit: Int64) {
        lock.lock()
        self.limit = limit
        self.nextSlot = Date.distantPast
        lock.unlock()
    }

    /// Returns the delay in seconds before `bytesCount` may be written (0 = immediate).
    func delayBeforeWrite(bytesCount: Int) -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }

        guard limit > 0 else { return 0 }

        let now = Date()
        let start = max(now, nextSlot)
        // Cap the virtual clock to 5.0 seconds in the future so that bursts or low speed limits
        // do not schedule writes tens of seconds out into GCD timers.
        let horizon = now.addingTimeInterval(5.0)
        let scheduled = start.addingTimeInterval(Double(bytesCount) / Double(limit))
        nextSlot = min(scheduled, horizon)
        return start.timeIntervalSince(now)
    }
}
