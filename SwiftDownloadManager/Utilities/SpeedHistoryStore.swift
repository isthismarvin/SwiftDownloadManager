import Foundation

private struct PersistedSpeedSample: Codable {
    let timestamp: TimeInterval
    let bytesPerSecond: Double
}

enum SpeedHistoryStore {
    static let maxSamples = 600

    static func decode(_ json: String?) -> [SpeedSample] {
        guard let json, !json.isEmpty,
              let data = json.data(using: .utf8),
              let persisted = try? JSONDecoder().decode([PersistedSpeedSample].self, from: data) else {
            return []
        }
        return persisted.map {
            SpeedSample(
                date: Date(timeIntervalSince1970: $0.timestamp),
                speedBytesPerSecond: $0.bytesPerSecond
            )
        }
    }

    static func encode(_ samples: [SpeedSample]) -> String? {
        guard !samples.isEmpty else { return nil }
        let capped = Array(samples.suffix(maxSamples))
        let persisted = capped.map {
            PersistedSpeedSample(
                timestamp: $0.date.timeIntervalSince1970,
                bytesPerSecond: $0.speedBytesPerSecond
            )
        }
        guard let data = try? JSONEncoder().encode(persisted) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum SpeedMetricsSummary {
    static func peakSpeed(from samples: [SpeedSample]) -> Double {
        samples.map(\.speedBytesPerSecond).max() ?? 0
    }

    static func averageSpeed(from samples: [SpeedSample]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let total = samples.reduce(0.0) { $0 + $1.speedBytesPerSecond }
        return total / Double(samples.count)
    }

    static func duration(
        samples: [SpeedSample],
        startedAt: Date,
        finishedAt: Date?
    ) -> TimeInterval? {
        if let first = samples.first?.date, let last = samples.last?.date, last > first {
            return last.timeIntervalSince(first)
        }
        if let finishedAt, finishedAt > startedAt {
            return finishedAt.timeIntervalSince(startedAt)
        }
        return nil
    }

    static func throughputAverage(bytesTotal: Int64, duration: TimeInterval?) -> Double {
        guard let duration, duration > 0, bytesTotal > 0 else { return 0 }
        return Double(bytesTotal) / duration
    }
}
