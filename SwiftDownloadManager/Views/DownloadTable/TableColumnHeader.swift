import SwiftUI

struct TableColumnHeader: View {
    let column: DownloadTableColumn
    let width: CGFloat
    var alignment: Alignment = .leading
    var resizable: Bool = false
    var widthBinding: Binding<CGFloat>?
    var activeSort: DownloadSortOrder?
    var sortAscending: Bool = false
    var onSort: (() -> Void)?
    var onMoveColumn: ((DownloadTableColumn, DownloadTableColumn) -> Void)?
    @Binding var dropTargetColumn: DownloadTableColumn?

    private var showsTitle: Bool {
        !column.isIconOnly && width >= column.iconOnlyThreshold
    }

    private var isActive: Bool {
        activeSort == column.sortOrder
    }

    var body: some View {
        headerLabel
            .overlay(alignment: .trailing) {
                if resizable, let widthBinding {
                    ResizableDivider(width: widthBinding)
                }
            }
            .background {
                if dropTargetColumn == column {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                }
            }
            .onTapGesture { onSort?() }
            .draggable(column.rawValue) {
                dragPreview
            }
            .dropDestination(for: String.self) { items, _ in
                guard column.isReorderable,
                      let raw = items.first,
                      let source = DownloadTableColumn(rawValue: raw),
                      source.isReorderable,
                      source != column else {
                    return false
                }
                onMoveColumn?(source, column)
                dropTargetColumn = nil
                return true
            } isTargeted: { targeted in
                dropTargetColumn = targeted ? column : (dropTargetColumn == column ? nil : dropTargetColumn)
            }
            .help(sortHelpText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(sortAccessibilityLabel)
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private var headerLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: column.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .accessibilityHidden(showsTitle)

            if showsTitle {
                Text(column.shortTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.55))
            }

            if isActive {
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.leading, 10)
        .frame(width: width, alignment: alignment)
        .contentShape(Rectangle())
    }

    private var dragPreview: some View {
        HStack(spacing: 4) {
            Image(systemName: column.icon)
            Text(column.shortTitle)
        }
        .font(.system(size: 10, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
    }

    private var sortHelpText: String {
        let reorderHint = L10n.t(de: "Ziehen zum Verschieben", en: "Drag to reorder")
        if isActive {
            return L10n.t(
                de: "\(column.title) — \(sortAscending ? "aufsteigend" : "absteigend") sortiert. Erneut klicken zum Umschalten. \(reorderHint).",
                en: "\(column.title) — sorted \(sortAscending ? "ascending" : "descending"). Click again to reverse. \(reorderHint)."
            )
        }
        return L10n.t(
            de: "Nach \(column.title) sortieren. \(reorderHint).",
            en: "Sort by \(column.title). \(reorderHint)."
        )
    }

    private var sortAccessibilityLabel: String {
        if isActive {
            return L10n.t(
                de: "\(column.title), \(sortAscending ? "aufsteigend" : "absteigend") sortiert",
                en: "\(column.title), sorted \(sortAscending ? "ascending" : "descending")"
            )
        }
        return L10n.t(de: "Nach \(column.title) sortieren", en: "Sort by \(column.title)")
    }
}

struct TableNameColumnHeader: View {
    var activeSort: DownloadSortOrder?
    var sortAscending: Bool = false
    var onSort: (() -> Void)?

    private var isActive: Bool {
        activeSort == DownloadTableColumn.name.sortOrder
    }

    var body: some View {
        Button {
            onSort?()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: DownloadTableColumn.name.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)

                Text(DownloadTableColumn.name.shortTitle)
                    .lineLimit(1)
                    .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.55))

                if isActive {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isActive
            ? L10n.t(
                de: "Name — \(sortAscending ? "aufsteigend" : "absteigend") sortiert. Erneut klicken zum Umschalten.",
                en: "Name — sorted \(sortAscending ? "ascending" : "descending"). Click again to reverse."
            )
            : L10n.t(de: "Nach Name sortieren", en: "Sort by name"))
        .accessibilityLabel(isActive
            ? L10n.t(
                de: "Name, \(sortAscending ? "aufsteigend" : "absteigend") sortiert",
                en: "Name, sorted \(sortAscending ? "ascending" : "descending")"
            )
            : L10n.t(de: "Nach Name sortieren", en: "Sort by name"))
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}
