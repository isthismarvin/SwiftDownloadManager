import SwiftUI

/// Responsive column visibility and width scaling for the download table.
struct TableColumnLayout {
    var widths: ColumnWidths
    var showsDate: Bool
    var showsProgress: Bool
    var showsSpeed: Bool
    var showsStatus: Bool
    var showsSize: Bool
    var showsETA: Bool

    static func make(availableWidth: CGFloat, userWidths: ColumnWidths) -> TableColumnLayout {
        let horizontalPadding: CGFloat = 32
        let nameMinimum: CGFloat = 140

        var showsDate = true
        var showsProgress = true
        var showsSpeed = true
        let showsStatus = true
        var showsSize = true
        var showsETA = true

        if availableWidth < 620 { showsDate = false }
        if availableWidth < 560 { showsETA = false }
        if availableWidth < 480 { showsSize = false }
        if availableWidth < 400 { showsSpeed = false }
        if availableWidth < 320 { showsProgress = false }

        let widths = userWidths.clamped(
            availableWidth: availableWidth,
            nameMinimum: nameMinimum,
            horizontalPadding: horizontalPadding,
            showsDate: showsDate,
            showsProgress: showsProgress,
            showsSpeed: showsSpeed,
            showsStatus: showsStatus,
            showsSize: showsSize,
            showsETA: showsETA
        )

        return TableColumnLayout(
            widths: widths,
            showsDate: showsDate,
            showsProgress: showsProgress,
            showsSpeed: showsSpeed,
            showsStatus: showsStatus,
            showsSize: showsSize,
            showsETA: showsETA
        )
    }
}

private extension ColumnWidths {
    func clamped(
        availableWidth: CGFloat,
        nameMinimum: CGFloat,
        horizontalPadding: CGFloat,
        showsDate: Bool,
        showsProgress: Bool,
        showsSpeed: Bool,
        showsStatus: Bool,
        showsSize: Bool,
        showsETA: Bool
    ) -> ColumnWidths {
        var result = self

        func visibleTotal() -> CGFloat {
            var total: CGFloat = 0
            if showsDate { total += result.date }
            if showsProgress { total += result.progress }
            if showsSpeed { total += result.speed }
            if showsStatus { total += result.status }
            if showsSize { total += result.size }
            if showsETA { total += result.eta }
            return total
        }

        let maxColumnSpace = max(availableWidth - nameMinimum - horizontalPadding, ColumnWidths.minWidth)
        var total = visibleTotal()
        guard total > maxColumnSpace, maxColumnSpace > 0 else { return result }

        let scale = maxColumnSpace / total
        if showsDate { result.date = max(ColumnWidths.minWidth, result.date * scale) }
        if showsProgress { result.progress = max(ColumnWidths.minWidth, result.progress * scale) }
        if showsSpeed { result.speed = max(ColumnWidths.minWidth, result.speed * scale) }
        if showsStatus { result.status = max(ColumnWidths.minWidth, result.status * scale) }
        if showsSize { result.size = max(ColumnWidths.minWidth, result.size * scale) }
        if showsETA { result.eta = max(ColumnWidths.minWidth, result.eta * scale) }

        total = visibleTotal()
        if total > maxColumnSpace {
            let secondScale = maxColumnSpace / total
            if showsDate { result.date = max(ColumnWidths.minWidth, result.date * secondScale) }
            if showsProgress { result.progress = max(ColumnWidths.minWidth, result.progress * secondScale) }
            if showsSpeed { result.speed = max(ColumnWidths.minWidth, result.speed * secondScale) }
            if showsStatus { result.status = max(ColumnWidths.minWidth, result.status * secondScale) }
            if showsSize { result.size = max(ColumnWidths.minWidth, result.size * secondScale) }
            if showsETA { result.eta = max(ColumnWidths.minWidth, result.eta * secondScale) }
        }

        return result
    }
}
