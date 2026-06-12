import SwiftUI

extension DownloadTableColumn {
    @MainActor
    var title: String {
        switch self {
        case .name: return L10n.t(de: "Name", en: "Name")
        case .date: return L10n.t(de: "Datum", en: "Date")
        case .progress: return L10n.t(de: "Fortschritt", en: "Progress")
        case .speed: return L10n.t(de: "Geschwindigkeit", en: "Speed")
        case .status: return L10n.t(de: "Status", en: "Status")
        case .size: return L10n.t(de: "Größe", en: "Size")
        case .eta: return L10n.t(de: "Verbleibend", en: "Remaining")
        }
    }

    @MainActor
    var shortTitle: String {
        switch self {
        case .name: return title
        case .date: return title
        case .progress: return L10n.t(de: "Fortsch.", en: "Progress")
        case .speed: return L10n.t(de: "Tempo", en: "Speed")
        case .status: return title
        case .size: return title
        case .eta: return L10n.t(de: "Rest", en: "ETA")
        }
    }

    var icon: String {
        switch self {
        case .name: return "doc.text"
        case .date: return "calendar"
        case .progress: return "chart.bar.fill"
        case .speed: return "gauge.with.dots.needle.33percent"
        case .status: return "circle.dotted.circle"
        case .size: return "internaldrive"
        case .eta: return "clock"
        }
    }

    /// Below this width the header shows only the icon.
    var iconOnlyThreshold: CGFloat {
        switch self {
        case .name: return 0
        case .status: return .infinity
        default: return 52
        }
    }

    var isIconOnly: Bool {
        self == .status
    }
}

extension TableColumnLayout {
    func visibleDataColumns(in order: [DownloadTableColumn]) -> [DownloadTableColumn] {
        order.filter(isColumnVisible)
    }

    func isColumnVisible(_ column: DownloadTableColumn) -> Bool {
        switch column {
        case .name: return true
        case .date: return showsDate
        case .progress: return showsProgress
        case .speed: return showsSpeed
        case .status: return showsStatus
        case .size: return showsSize
        case .eta: return showsETA
        }
    }
}

extension ColumnWidths {
    func width(for column: DownloadTableColumn) -> CGFloat {
        switch column {
        case .name: return 0
        case .date: return date
        case .progress: return progress
        case .speed: return speed
        case .status: return status
        case .size: return size
        case .eta: return eta
        }
    }

    mutating func setWidth(_ value: CGFloat, for column: DownloadTableColumn) {
        switch column {
        case .name: break
        case .date: date = value
        case .progress: progress = value
        case .speed: speed = value
        case .status: status = value
        case .size: size = value
        case .eta: eta = value
        }
    }

    static func widthBinding(
        for column: DownloadTableColumn,
        in columns: Binding<ColumnWidths>
    ) -> Binding<CGFloat> {
        Binding(
            get: { columns.wrappedValue.width(for: column) },
            set: { newValue in
                var updated = columns.wrappedValue
                updated.setWidth(newValue, for: column)
                columns.wrappedValue = updated
            }
        )
    }
}
