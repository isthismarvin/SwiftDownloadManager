import SwiftUI

struct DownloadTableRowView: View {
    let item: DownloadItem
    let layout: TableColumnLayout
    let visibleColumns: [DownloadTableColumn]
    let isSelected: Bool
    let folders: [DownloadFolder]
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onMoveToFolder: (DownloadFolder?) -> Void

    @State private var isHovered = false

    private var viewModel: DownloadRowViewModel {
        DownloadRowViewModel(item: item)
    }

    var body: some View {
        HStack(spacing: 0) {
            nameColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .layoutPriority(1)

            ForEach(Array(visibleColumns.enumerated()), id: \.element.id) { index, column in
                dataColumn(column, isLast: index == visibleColumns.count - 1)
            }
        }
        .frame(height: AppTheme.rowHeight)
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 12)
                    .padding(.leading, 6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if viewModel.canOpenFile { viewModel.openFile() }
            }
        )
        .onHover { isHovered = $0 }
        .contextMenu { contextMenuContent }
        .overlay(alignment: .trailing) {
            if isHovered {
                hoverActions
                    .padding(.trailing, 8)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: String {
        L10n.t(
            de: """
            \(viewModel.fileName), \(viewModel.statusBadge.label), \(viewModel.progressText), \
            Geschwindigkeit \(viewModel.speedText), verbleibend \(viewModel.etaText)
            """,
            en: """
            \(viewModel.fileName), \(viewModel.statusBadge.label), \(viewModel.progressText), \
            speed \(viewModel.speedText), remaining \(viewModel.etaText)
            """
        )
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuContent: some View {
        if viewModel.canConfirm {
            Button(L10n.t(de: "Download starten", en: "Start Download"), systemImage: "play.circle.fill") {
                viewModel.confirm()
            }
        }
        if viewModel.canResume {
            Button(L10n.t(de: "Fortsetzen", en: "Resume"), systemImage: "play.fill") {
                viewModel.resume()
            }
        }
        if viewModel.canPause {
            Button(L10n.t(de: "Pausieren", en: "Pause"), systemImage: "pause.fill") {
                viewModel.pause()
            }
        }
        if viewModel.canCancel {
            Button(L10n.t(de: "Abbrechen", en: "Cancel"), systemImage: "stop.fill") {
                viewModel.cancel()
            }
        }

        Divider()

        if viewModel.canRevealInFinder {
            Button(L10n.t(de: "Im Finder anzeigen", en: "Reveal in Finder"), systemImage: "folder.fill") {
                viewModel.revealInFinder()
            }
            Button(L10n.t(de: "Datei öffnen", en: "Open File"), systemImage: "arrow.up.right.square") {
                viewModel.openFile()
            }
        }

        if viewModel.canUnzip {
            Button(L10n.t(de: "Archiv öffnen", en: "Open Archive"), systemImage: "archivebox") {
                viewModel.unzip()
            }
        }

        Button(L10n.t(de: "URL kopieren", en: "Copy URL"), systemImage: "doc.on.doc") {
            viewModel.copyURL()
        }

        if !folders.isEmpty {
            Menu(L10n.t(de: "In Ordner verschieben", en: "Move to Folder"), systemImage: "folder.badge.plus") {
                Button(L10n.t(de: "Keiner", en: "None"), systemImage: "minus.circle") {
                    onMoveToFolder(nil)
                }
                ForEach(folders) { folder in
                    Button(folder.name, systemImage: "folder.fill") {
                        onMoveToFolder(folder)
                    }
                }
            }
        }

        Divider()

        Button(L10n.t(de: "Löschen", en: "Delete"), systemImage: "trash", role: .destructive) {
            onDelete()
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func dataColumn(_ column: DownloadTableColumn, isLast: Bool) -> some View {
        Group {
            switch column {
            case .name:
                EmptyView()
            case .date:
                Text(viewModel.dateText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            case .progress:
                progressColumn
            case .speed:
                Text(viewModel.speedText)
                    .font(.system(size: 12))
                    .foregroundStyle(item.status == .downloading ? .primary : .secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.35), value: viewModel.speedText)
            case .status:
                StatusBadge(info: viewModel.statusBadge)
            case .size:
                Text(viewModel.sizeText)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            case .eta:
                Text(viewModel.etaText)
                    .font(.system(size: 12))
                    .foregroundStyle(item.status == .downloading ? .primary : .secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.35), value: viewModel.etaText)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, isLast ? 16 : 0)
        .frame(
            width: layout.widths.width(for: column),
            alignment: column == .status ? .center : .leading
        )
    }

    private var nameColumn: some View {
        HStack(spacing: 10) {
            fileIconView
            fileNameLabels
        }
    }

    @ViewBuilder
    private var fileNameLabels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.fileName)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            if viewModel.status == .completed && viewModel.fileIsMissing {
                Text(L10n.t(de: "Datei nicht gefunden", en: "File not found"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } else {
                Text(viewModel.subtitleText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var fileIconView: some View {
        let icon = FileTypeHelper.systemIcon(for: viewModel.fileName)
        if let fileURL = viewModel.draggableFileURL {
            DraggableFileIcon(
                fileURL: fileURL,
                icon: icon,
                size: 32,
                onDoubleClick: { viewModel.openFile() },
                onFileExported: {
                    DownloadManager.shared.noteFileExternallyRelocated(id: item.id)
                }
            )
            .frame(width: 32, height: 32)
            .help(L10n.t(
                de: "Auf Desktop oder in den Finder ziehen zum Verschieben",
                en: "Drag to Desktop or Finder to move"
            ))
        } else {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .opacity(viewModel.fileIsMissing ? 0.45 : 1)

                if viewModel.status == .completed && viewModel.fileIsMissing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .offset(x: 4, y: -2)
                }
            }
        }
    }

    @ViewBuilder
    private var progressColumn: some View {
        if viewModel.showsProgressBar {
            HStack(spacing: 8) {
                if viewModel.usesSegmentedProgress {
                    SegmentVisualizerView(
                        segments: viewModel.segments,
                        bytesTotal: viewModel.bytesTotal,
                        downloadCompleted: viewModel.status == .completed
                    )
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                } else {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(viewModel.progressTint)
                                    .frame(width: max(geo.size.width * viewModel.progress, 0))
                            }
                        }
                        .clipShape(Capsule())
                }

                if viewModel.showsPercentLabel, layout.widths.progress >= 88 {
                    Text(viewModel.progressText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        } else {
            EmptyView()
        }
    }

    private var hoverActions: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                if viewModel.canResume {
                    actionButton(
                        icon: "play.fill",
                        help: L10n.t(de: "Fortsetzen", en: "Resume")
                    ) { viewModel.resume() }
                }
                if viewModel.canPause {
                    actionButton(
                        icon: "pause.fill",
                        help: L10n.t(de: "Pausieren", en: "Pause")
                    ) { viewModel.pause() }
                }
                if viewModel.canCancel {
                    actionButton(
                        icon: "stop.fill",
                        help: L10n.t(de: "Abbrechen", en: "Cancel")
                    ) { viewModel.cancel() }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .appGlassCapsule()
        }
    }

    private func actionButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.caption)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
