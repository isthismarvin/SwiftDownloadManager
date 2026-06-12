import Foundation
import Observation

struct SpeedSample: Identifiable {
    let id: UUID
    let date: Date
    let speedBytesPerSecond: Double

    init(date: Date, speedBytesPerSecond: Double) {
        self.id = UUID()
        self.date = date
        self.speedBytesPerSecond = speedBytesPerSecond
    }
}

@Observable
@MainActor
final class DownloadMetricsTracker {
    private(set) var currentSpeed: Double = 0
    /// Smoothed speed for UI labels — updates at a lower cadence than raw chunks.
    private(set) var displaySpeed: Double = 0
    /// Smoothed ETA for UI labels, derived from `displaySpeed`.
    private(set) var displayETA: TimeInterval?
    private(set) var speedSamples: [SpeedSample] = []
    private(set) var activeConnections: Int = 0
    /// Live progress for the UI. SwiftData only persists these values at a low
    /// cadence; rows read the tracker to stay smooth without store churn.
    private(set) var liveBytesReceived: Int64 = 0
    private(set) var liveBytesTotal: Int64 = -1

    private var lastBytesReceived: Int64 = 0
    private var lastUpdateDate: Date?
    private var lastSampleDate: Date?
    private var lastDisplayRefreshDate: Date?

    static let maxSamples = SpeedHistoryStore.maxSamples
    private static let sampleInterval: TimeInterval = 1.0
    /// EMA weight of the newest measurement (0…1, higher = more reactive).
    private static let speedSmoothing = 0.12
    /// How often UI-facing speed/ETA values may move toward their targets.
    private static let displayRefreshInterval: TimeInterval = 0.75
    /// Blend factor per display refresh (0…1, lower = smoother labels).
    private static let displayBlend: Double = 0.28

    func eta(remainingBytes: Int64) -> TimeInterval? {
        guard remainingBytes > 0, currentSpeed > 0 else { return nil }
        return Double(remainingBytes) / currentSpeed
    }

    func update(bytesReceived: Int64, bytesTotal: Int64, connections: Int) {
        activeConnections = connections
        liveBytesReceived = bytesReceived
        liveBytesTotal = bytesTotal
        let now = Date()

        if let lastUpdate = lastUpdateDate {
            let elapsed = now.timeIntervalSince(lastUpdate)
            if elapsed > 0 {
                let delta = Double(bytesReceived - lastBytesReceived)
                if delta >= 0 {
                    let instantSpeed = delta / elapsed
                    // Exponential moving average instead of the raw instant
                    // value — keeps speed and ETA from jumping around with
                    // every chunk burst.
                    if currentSpeed <= 0 {
                        currentSpeed = instantSpeed
                    } else {
                        currentSpeed = Self.speedSmoothing * instantSpeed
                            + (1 - Self.speedSmoothing) * currentSpeed
                    }
                }
            }
        }

        lastBytesReceived = bytesReceived
        lastUpdateDate = now

        let remaining = bytesTotal > 0 ? bytesTotal - bytesReceived : Int64(0)
        let targetETA = eta(remainingBytes: remaining)
        refreshDisplayValues(now: now, targetSpeed: currentSpeed, targetETA: targetETA)

        if shouldRecordSample(at: now) {
            recordSample(speed: currentSpeed, at: now)
            lastSampleDate = now
        }
    }

    func reset() {
        currentSpeed = 0
        displaySpeed = 0
        displayETA = nil
        speedSamples = []
        activeConnections = 0
        liveBytesReceived = 0
        liveBytesTotal = -1
        lastBytesReceived = 0
        lastUpdateDate = nil
        lastSampleDate = nil
        lastDisplayRefreshDate = nil
    }

    func loadPersistedSamples(_ samples: [SpeedSample]) {
        guard !samples.isEmpty else { return }
        speedSamples = Array(samples.suffix(Self.maxSamples))
        if let last = speedSamples.last {
            currentSpeed = last.speedBytesPerSecond
            displaySpeed = last.speedBytesPerSecond
            lastSampleDate = last.date
        }
    }

    func exportSamples() -> [SpeedSample] {
        speedSamples
    }

    private func refreshDisplayValues(
        now: Date,
        targetSpeed: Double,
        targetETA: TimeInterval?
    ) {
        if let lastDisplayRefreshDate,
           now.timeIntervalSince(lastDisplayRefreshDate) < Self.displayRefreshInterval {
            return
        }
        lastDisplayRefreshDate = now

        if displaySpeed <= 0 || targetSpeed <= 0 {
            displaySpeed = targetSpeed
        } else {
            displaySpeed += (targetSpeed - displaySpeed) * Self.displayBlend
        }

        guard let targetETA, targetETA.isFinite, targetETA > 0 else {
            displayETA = nil
            return
        }

        if let displayETA {
            self.displayETA = displayETA + (targetETA - displayETA) * Self.displayBlend
        } else {
            displayETA = targetETA
        }
    }

    private func shouldRecordSample(at date: Date) -> Bool {
        guard let lastSampleDate else { return true }
        return date.timeIntervalSince(lastSampleDate) >= Self.sampleInterval
    }

    private func recordSample(speed: Double, at date: Date) {
        speedSamples.append(SpeedSample(date: date, speedBytesPerSecond: speed))
        if speedSamples.count > Self.maxSamples {
            speedSamples.removeFirst(speedSamples.count - Self.maxSamples)
        }
    }
}
