import SwiftUI
import AppKit

struct DownloadTableView: View {
    @Bindable var viewModel: DownloadListViewModel
    let downloads: [DownloadItem]
    let folders: [DownloadFolder]
    let hasAnyDownloads: Bool

    @State private var columns = ColumnWidths.default
    @State private var dropTargetColumn: DownloadTableColumn?

    var body: some View {
        GeometryReader { geometry in
            let layout = TableColumnLayout.make(
                availableWidth: geometry.size.width,
                userWidths: columns
            )
            let visibleColumns = layout.visibleDataColumns(in: viewModel.tableColumnOrder)

            VStack(spacing: 0) {
                tableHeader(layout: layout, visibleColumns: visibleColumns)

                Divider()
                    .overlay(AppTheme.separatorColor)

                if downloads.isEmpty {
                    if hasAnyDownloads {
                        filteredEmptyState
                    } else {
                        emptyState
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(downloads) { item in
                                DownloadTableRowView(
                                    item: item,
                                    layout: layout,
                                    visibleColumns: visibleColumns,
                                    isSelected: viewModel.selectedDownloadIDs.contains(item.id),
                                    folders: folders,
                                    onSelect: {
                                        let flags = NSEvent.modifierFlags
                                        viewModel.handleDownloadSelection(
                                            id: item.id,
                                            in: downloads,
                                            commandPressed: flags.contains(.command),
                                            shiftPressed: flags.contains(.shift)
                                        )
                                    },
                                    onDelete: {
                                        viewModel.requestDelete(item)
                                    },
                                    onMoveToFolder: { folder in
                                        viewModel.moveDownload(item, to: folder)
                                    }
                                )

                                if item.id != downloads.last?.id {
                                    Divider()
                                        .overlay(AppTheme.separatorColor)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .scrollEdgeEffectStyle(.soft, for: .vertical)
                }
            }
        }
    }

    // MARK: - Header

    private func tableHeader(
        layout: TableColumnLayout,
        visibleColumns: [DownloadTableColumn]
    ) -> some View {
        HStack(spacing: 0) {
            TableNameColumnHeader(
                activeSort: viewModel.tableSortOrder,
                sortAscending: viewModel.tableSortAscending,
                onSort: { viewModel.toggleTableSort(for: .name) }
            )

            ForEach(Array(visibleColumns.enumerated()), id: \.element.id) { index, column in
                sortableHeader(
                    column,
                    layout: layout,
                    isLast: index == visibleColumns.count - 1
                )
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.tertiary)
        .textCase(.none)
        .frame(height: 30)
        .background(AppTheme.tableHeaderBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.tableHeaderBorder)
                .frame(height: 1)
        }
    }

    private func sortableHeader(
        _ column: DownloadTableColumn,
        layout: TableColumnLayout,
        isLast: Bool
    ) -> some View {
        let resizable = column != .status
        return TableColumnHeader(
            column: column,
            width: layout.widths.width(for: column),
            alignment: column == .status ? .center : .leading,
            resizable: resizable,
            widthBinding: resizable ? ColumnWidths.widthBinding(for: column, in: $columns) : nil,
            activeSort: viewModel.tableSortOrder,
            sortAscending: viewModel.tableSortAscending,
            onSort: { viewModel.toggleTableSort(for: column) },
            onMoveColumn: { source, target in
                viewModel.moveTableColumn(from: source, to: target)
            },
            dropTargetColumn: $dropTargetColumn
        )
        .padding(.trailing, isLast ? 6 : 0)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.t(de: "Keine Downloads", en: "No Downloads"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Button(L10n.t(de: "Download hinzufügen", en: "Add Download")) {
                viewModel.isShowingAddSheet = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.t(de: "Keine Ergebnisse", en: "No Results"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(L10n.t(
                de: "Keine Downloads entsprechen dem aktuellen Filter oder der Suche.",
                en: "No downloads match the current filter or search."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
            Button(L10n.t(de: "Filter zurücksetzen", en: "Reset Filter")) {
                viewModel.searchText = ""
                viewModel.selectedSidebarItem = .allDownloads
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
