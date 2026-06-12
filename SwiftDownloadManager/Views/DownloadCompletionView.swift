import SwiftUI
import AppKit

struct DownloadCompletionView: View {
    let item: DownloadItem
    let onDismiss: () -> Void
    let onShowInApp: () -> Void

    @Bindable private var fileMonitor = FileLocationMonitor.shared

    private var fileURL: URL? {
        let _ = fileMonitor.revision
        return fileMonitor.resolvedURL(for: item)
    }

    private var fileIsMissing: Bool {
        let _ = fileMonitor.revision
        return fileMonitor.isMissing(id: item.id)
    }

    private var canOpenArchive: Bool {
        guard let path = fileURL else { return false }
        let ext = path.pathExtension.lowercased()
        return ["zip", "gz", "tar", "bz2", "xz", "7z", "rar", "tgz", "tbz2", "cab"].contains(ext)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            fileCard
            metadata
            actionButtons
        }
        .padding(AppTheme.dialogPadding)
        .frame(width: 620, height: 280)
        .interactiveDismissDisabled()
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t(de: "Download abgeschlossen", en: "Download Complete"))
                    .font(.headline)
                Text(item.fileName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: openFile)
                    .help(L10n.t(de: "Doppelklick zum Öffnen", en: "Double-click to open"))
            }
        }
    }

    private var fileCard: some View {
        HStack(spacing: AppTheme.sectionSpacing) {
            if let fileURL {
                DraggableFileIcon(
                    fileURL: fileURL,
                    icon: FileTypeHelper.systemIcon(for: item.fileName),
                    size: 40,
                    onDoubleClick: openFile,
                    onFileExported: {
                        DownloadManager.shared.noteFileExternallyRelocated(id: item.id)
                    }
                )
                .frame(width: 40, height: 40)
                .help(L10n.t(
                    de: "Ziehen zum Verschieben · Doppelklick zum Öffnen",
                    en: "Drag to move · Double-click to open"
                ))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: openFile)
                Text(L10n.t(
                    de: "Doppelklick öffnen · Icon ziehen zum Verschieben",
                    en: "Double-click to open · drag icon to move"
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(AppTheme.sectionSpacing)
        .background(
            AppTheme.subtleBackground,
            in: RoundedRectangle(cornerRadius: AppTheme.itemSpacing, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.itemSpacing, style: .continuous)
                .stroke(AppTheme.separatorColor, lineWidth: 1)
        )
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            if item.bytesTotal > 0 {
                Label(ByteFormatter.format(item.bytesTotal), systemImage: "internaldrive")
            }
            if let path = fileURL?.path ?? item.localFilePath, !path.isEmpty {
                Label(path, systemImage: fileIsMissing ? "exclamationmark.triangle" : "folder")
                    .foregroundStyle(fileIsMissing ? .orange : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if fileIsMissing {
                Text(L10n.t(
                    de: "Die Datei wurde im Finder nicht gefunden.",
                    en: "The file could not be found in Finder."
                ))
                .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            primaryActionButtons
            stackedActionButtons
        }
    }

    private var primaryActionButtons: some View {
        HStack(spacing: AppTheme.compactPadding) {
            actionButtonGroup
            Spacer(minLength: 0)
            Button(L10n.t(de: "Fertig", en: "Done")) {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var stackedActionButtons: some View {
        VStack(alignment: .leading, spacing: AppTheme.compactPadding) {
            actionButtonGroup
            HStack {
                Spacer()
                Button(L10n.t(de: "Fertig", en: "Done")) {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var actionButtonGroup: some View {
        HStack(spacing: AppTheme.compactPadding) {
            Button(action: openFile) {
                Label(L10n.t(de: "Öffnen", en: "Open"), systemImage: "arrow.up.right.square")
            }

            Button(action: revealInFinder) {
                Label(L10n.t(de: "Finder", en: "Finder"), systemImage: "folder")
            }

            if canOpenArchive {
                Button(action: openArchive) {
                    Label(L10n.t(de: "Archiv öffnen", en: "Open Archive"), systemImage: "archivebox")
                }
            }

            Button(action: onShowInApp) {
                Label(
                    L10n.t(de: "In Swift Download Manager anzeigen", en: "Show in Swift Download Manager"),
                    systemImage: "tray.and.arrow.down.fill"
                )
                .lineLimit(1)
            }
        }
    }

    private func openFile() {
        guard let url = fileURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func revealInFinder() {
        guard let url = fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openArchive() {
        guard let url = fileURL else { return }
        NSWorkspace.shared.open(url)
    }
}
