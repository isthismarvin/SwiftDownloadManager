import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum DownloadPriority: String, CaseIterable, Identifiable, Codable, Sendable {
    case high
    case normal
    case low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high:
            return L10n.t(de: "Hoch", en: "High")
        case .normal:
            return L10n.t(de: "Normal", en: "Normal")
        case .low:
            return L10n.t(de: "Niedrig", en: "Low")
        }
    }

    var sortWeight: Int {
        switch self {
        case .high: return 3
        case .normal: return 2
        case .low: return 1
        }
    }

    var iconName: String {
        switch self {
        case .high: return "arrow.up.circle.fill"
        case .normal: return "minus.circle"
        case .low: return "arrow.down.circle"
        }
    }

#if canImport(SwiftUI)
    var tintColor: Color {
        switch self {
        case .high: return .red
        case .normal: return .secondary
        case .low: return .blue
        }
    }
#endif
}

enum SpeedLimitPreset: Int64, CaseIterable, Identifiable, Sendable {
    case unlimited = 0
    case kb256 = 262_144
    case kb512 = 524_288
    case mb1 = 1_048_576
    case mb2 = 2_097_152
    case mb5 = 5_242_880
    case mb10 = 10_485_760
    case mb25 = 26_214_400
    case mb50 = 52_428_800

    var id: Int64 { rawValue }

    var label: String {
        switch self {
        case .unlimited:
            return L10n.t(de: "Unbegrenzt", en: "Unlimited")
        case .kb256:
            return "256 KB/s"
        case .kb512:
            return "512 KB/s"
        case .mb1:
            return "1 MB/s"
        case .mb2:
            return "2 MB/s"
        case .mb5:
            return "5 MB/s"
        case .mb10:
            return "10 MB/s"
        case .mb25:
            return "25 MB/s"
        case .mb50:
            return "50 MB/s"
        }
    }

    static func matching(bytes: Int64?) -> SpeedLimitPreset? {
        guard let bytes = bytes, bytes > 0 else { return .unlimited }
        return allCases.first { $0.rawValue == bytes }
    }

    static func format(bytesPerSecond: Int64?) -> String {
        guard let bytes = bytesPerSecond, bytes > 0 else {
            return L10n.t(de: "Unbegrenzt", en: "Unlimited")
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary) + "/s"
    }
}
