import Foundation

/// Download table columns (excluding layout/view concerns).
enum DownloadTableColumn: String, CaseIterable, Hashable, Identifiable {
    case name
    case date
    case progress
    case speed
    case status
    case size
    case eta

    var id: String { rawValue }

    static let defaultDataColumnOrder: [DownloadTableColumn] = [
        .date, .progress, .speed, .status, .size, .eta,
    ]

    var isReorderable: Bool {
        self != .name
    }

    var sortOrder: DownloadSortOrder {
        switch self {
        case .name: return .name
        case .date: return .dateAdded
        case .progress: return .progress
        case .speed: return .speed
        case .status: return .status
        case .size: return .size
        case .eta: return .eta
        }
    }

    static func normalizedOrder(_ stored: [DownloadTableColumn]) -> [DownloadTableColumn] {
        var result = stored.filter(\.isReorderable)
        for column in defaultDataColumnOrder where !result.contains(column) {
            result.append(column)
        }
        return result
    }
}
