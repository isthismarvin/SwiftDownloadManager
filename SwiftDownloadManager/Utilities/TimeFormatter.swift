import Foundation

enum TimeFormatter {
    static func formatETA(_ interval: TimeInterval?) -> String {
        guard let interval, interval.isFinite, interval > 0 else { return "–" }
        return formatETA(seconds: quantizeETA(interval))
    }

    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "–" }
        let mbps = bytesPerSecond / 1_000_000
        if mbps >= 1 {
            let quantized = (mbps * 10).rounded() / 10
            return String(format: "%.1f MB/s", quantized)
        }
        let kbps = (bytesPerSecond / 1_000).rounded()
        return String(format: "%.0f KB/s", kbps)
    }

    /// Quantize ETA so labels do not flicker every second.
    private static func quantizeETA(_ interval: TimeInterval) -> Int {
        let seconds = max(interval, 1)
        let step: TimeInterval
        if seconds < 120 {
            step = 5
        } else if seconds < 600 {
            step = 15
        } else if seconds < 3600 {
            step = 30
        } else {
            step = 60
        }
        return Int((seconds / step).rounded() * step)
    }

    private static func formatETA(seconds totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    static func formatDuration(_ interval: TimeInterval?) -> String {
        guard let interval, interval.isFinite, interval > 0 else { return "–" }

        let totalSeconds = Int(interval.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
