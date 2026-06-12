import Foundation

struct SegmentCountTier: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var maxSizeMB: Int
    var connections: Int

    init(id: UUID = UUID(), maxSizeMB: Int, connections: Int) {
        self.id = id
        self.maxSizeMB = max(0, maxSizeMB)
        self.connections = min(8, max(1, connections))
    }

    var isCatchAll: Bool { maxSizeMB == 0 }
}

enum SegmentCountPolicy {
    static let defaultTiers: [SegmentCountTier] = [
        SegmentCountTier(maxSizeMB: 4, connections: 1),
        SegmentCountTier(maxSizeMB: 50, connections: 2),
        SegmentCountTier(maxSizeMB: 200, connections: 4),
        SegmentCountTier(maxSizeMB: 1_024, connections: 6),
        SegmentCountTier(maxSizeMB: 0, connections: 8),
    ]

    static func normalizedTiers(_ tiers: [SegmentCountTier]) -> [SegmentCountTier] {
        var working = tiers.map {
            SegmentCountTier(id: $0.id, maxSizeMB: $0.maxSizeMB, connections: $0.connections)
        }
        guard !working.isEmpty else { return defaultTiers }

        let bounded = working.filter { !$0.isCatchAll }.sorted { $0.maxSizeMB < $1.maxSizeMB }
        var seen = Set<Int>()
        var uniqueBounded: [SegmentCountTier] = []
        for tier in bounded {
            guard !seen.contains(tier.maxSizeMB) else { continue }
            seen.insert(tier.maxSizeMB)
            uniqueBounded.append(tier)
        }

        let catchAll = working.first(where: \.isCatchAll)
            ?? SegmentCountTier(maxSizeMB: 0, connections: 8)

        return uniqueBounded + [catchAll]
    }

    static func connections(for bytesTotal: Int64, tiers: [SegmentCountTier], fallback: Int) -> Int {
        guard bytesTotal > 0 else { return clampConnections(fallback) }

        let normalized = normalizedTiers(tiers)
        let sizeMB = Double(bytesTotal) / 1_048_576.0

        for tier in normalized where !tier.isCatchAll {
            if sizeMB <= Double(tier.maxSizeMB) {
                return clampConnections(tier.connections)
            }
        }

        if let catchAll = normalized.first(where: \.isCatchAll) {
            return clampConnections(catchAll.connections)
        }

        return clampConnections(fallback)
    }

    static func clampConnections(_ value: Int) -> Int {
        min(8, max(1, value))
    }
}
