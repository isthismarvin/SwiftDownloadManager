import SwiftUI

struct DownloadDetailInspector: View {
    let item: DownloadItem
    @Binding var isCollapsed: Bool
    @Binding var expandedHeight: CGFloat

    @State private var resizeDragStartHeight: CGFloat?

    private var viewModel: DownloadDetailViewModel {
        DownloadDetailViewModel(item: item)
    }

    var body: some View {
        inspectorContent
            .frame(maxWidth: .infinity)
            .frame(
                height: isCollapsed ? AppTheme.inspectorCollapsedHeight : expandedHeight,
                alignment: .top
            )
            .overlay(alignment: .top) {
                if !isCollapsed {
                    inspectorResizeHandle
                }
            }
            .clipShape(inspectorShape)
            .glassEffect(.regular, in: inspectorShape)
            .animation(AppTheme.inspectorSpring, value: isCollapsed)
            .animation(AppTheme.inspectorSpring, value: expandedHeight)
    }

    private var inspectorShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: isCollapsed
                ? AppTheme.inspectorCollapsedHeight / 2
                : AppTheme.cornerRadius,
            style: .continuous
        )
    }

    private var inspectorContent: some View {
        VStack(spacing: 0) {
            if isCollapsed {
                collapsedBar
                    .transition(.opacity)
            } else {
                expandedChrome
                    .transition(.inspectorExpand)
            }
        }
        .clipped()
    }

    // MARK: - Collapsed

    private var collapsedBar: some View {
        HStack(spacing: AppTheme.compactPadding) {
            collapseButton

            Text(viewModel.fileName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            StatusBadge(info: viewModel.statusBadge)
                .fixedSize()

            collapsedTrailingMetrics
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, AppTheme.contentPadding)
        .padding(.vertical, AppTheme.compactPadding)
    }

    @ViewBuilder
    private var collapsedTrailingMetrics: some View {
        switch viewModel.status {
        case .downloading:
            ViewThatFits(in: .horizontal) {
                collapsedDownloadingMetrics(showSpeed: true, showETA: true)
                collapsedDownloadingMetrics(showSpeed: true, showETA: false)
                collapsedDownloadingMetrics(showSpeed: false, showETA: false)
            }
        case .completed:
            collapsedCompletedMetrics
        case .failed:
            collapsedFailedIndicator
        default:
            if !viewModel.subtitleText.isEmpty {
                collapsedMetricLabel(viewModel.subtitleText)
            }
        }
    }

    private func collapsedDownloadingMetrics(showSpeed: Bool, showETA: Bool) -> some View {
        HStack(spacing: 8) {
            Text(viewModel.progressText)
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)

            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)
                .tint(viewModel.progressTint)
                .frame(width: showSpeed ? 64 : 48)

            if showSpeed {
                Text(viewModel.speedText)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if showETA {
                Text(viewModel.etaText)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var collapsedCompletedMetrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                collapsedMetricLabel(viewModel.sizeText)
                collapsedSeparatorDot
                collapsedMetricLabel(viewModel.completedRelativeText)
                if let ext = viewModel.fileExtensionText {
                    collapsedSeparatorDot
                    collapsedMetricLabel(ext)
                }
            }
            HStack(spacing: 6) {
                collapsedMetricLabel(viewModel.sizeText)
                collapsedSeparatorDot
                collapsedMetricLabel(viewModel.completedRelativeText)
            }
            collapsedMetricLabel(viewModel.sizeText)
        }
    }

    private var collapsedSeparatorDot: some View {
        Text("·")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.tertiary)
    }

    private func collapsedMetricLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var collapsedFailedIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .help(viewModel.errorMessage ?? L10n.t(de: "Fehlgeschlagen", en: "Failed"))
    }

    // MARK: - Expanded

    private var expandedChrome: some View {
        VStack(spacing: 0) {
            expandedHeader

            Divider()
                .overlay(AppTheme.separatorColor)

            threeColumnLayout
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.vertical, 10)
                .frame(maxHeight: .infinity)
        }
    }

    private var expandedHeader: some View {
        HStack(spacing: AppTheme.compactPadding) {
            collapseButton
            Spacer(minLength: 0)
            inspectorActions
        }
        .padding(.horizontal, AppTheme.contentPadding)
        .padding(.vertical, AppTheme.compactPadding)
    }

    private var threeColumnLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            leftOverviewColumn
                .frame(minWidth: 200, maxWidth: 280)
                .layoutPriority(1)

            columnDivider

            middleMetricsColumn
                .frame(width: 164)

            columnDivider

            rightPanelColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(AppTheme.separatorColor)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    // MARK: - Left: File Overview

    private var leftOverviewColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            columnTitle(L10n.t(de: "Datei", en: "File"))

            HStack(alignment: .top, spacing: 8) {
                fileTypeIcon
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.fileName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)
                        .truncationMode(.middle)

                    HStack(spacing: 6) {
                        StatusBadge(info: viewModel.statusBadge)
                            .fixedSize()
                        if let ext = viewModel.fileExtensionText {
                            Text(ext)
                                .font(.system(size: 10, weight: .medium).monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        if let category = viewModel.categoryText {
                            Text(category)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            if viewModel.showsProgressBar {
                HStack(spacing: 8) {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .tint(viewModel.progressTint)
                    if viewModel.showsPercentLabel {
                        Text(viewModel.progressText)
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                overviewRow(
                    icon: "arrow.down.circle",
                    label: viewModel.status == .completed
                        ? L10n.t(de: "Größe", en: "Size")
                        : L10n.t(de: "Fortschritt", en: "Progress"),
                    value: viewModel.status == .completed
                        ? viewModel.sizeText
                        : "\(viewModel.downloadedText) / \(viewModel.totalText)"
                )
                overviewRow(
                    icon: "folder",
                    label: L10n.t(de: "Speicherort", en: "Save to"),
                    value: viewModel.savePathText,
                    action: viewModel.canRevealSaveLocation ? { viewModel.revealSaveLocation() } : nil,
                    actionHelp: L10n.t(de: "Im Finder anzeigen", en: "Reveal in Finder")
                )
                urlOverviewRow
                overviewRow(
                    icon: "tray.and.arrow.down",
                    label: L10n.t(de: "Quelle", en: "Source"),
                    value: "\(viewModel.sourceText) · \(viewModel.createdAtText)"
                )
                overviewRow(
                    icon: "arrow.trianglehead.clockwise.rotate.90",
                    label: L10n.t(de: "Fortsetzbar", en: "Resumable"),
                    value: viewModel.supportsResumeText
                )
            }

            if let error = viewModel.errorMessage {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var urlOverviewRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Text("URL")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .leading)

            Text(viewModel.urlText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: viewModel.copyURL) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L10n.t(de: "URL kopieren", en: "Copy URL"))
        }
    }

    // MARK: - Middle: Chart Metrics

    private var middleMetricsColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            columnTitle(L10n.t(de: "Transfer", en: "Transfer"))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(middleMetricRows, id: \.label) { row in
                    metricRow(
                        icon: row.icon,
                        label: row.label,
                        value: row.value,
                        tint: row.tint
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private struct MetricRowData {
        let icon: String
        let label: String
        let value: String
        var tint: Color = .secondary
    }

    private var middleMetricRows: [MetricRowData] {
        switch viewModel.status {
        case .downloading:
            return [
                MetricRowData(
                    icon: "speedometer",
                    label: L10n.t(de: "Aktuell", en: "Current"),
                    value: viewModel.speedText,
                    tint: .blue
                ),
                MetricRowData(
                    icon: "gauge.with.dots.needle.33percent",
                    label: L10n.t(de: "Ø Geschwindigkeit", en: "Avg Speed"),
                    value: viewModel.hasSpeedHistory ? viewModel.averageSpeedText : "—",
                    tint: .green
                ),
                MetricRowData(
                    icon: "bolt.fill",
                    label: L10n.t(de: "Spitzengeschw.", en: "Peak Speed"),
                    value: viewModel.hasSpeedHistory ? viewModel.peakSpeedText : "—",
                    tint: .orange
                ),
                MetricRowData(
                    icon: "clock",
                    label: L10n.t(de: "Verbleibend", en: "Remaining"),
                    value: viewModel.etaText
                ),
                MetricRowData(
                    icon: "network",
                    label: L10n.t(de: "Verbindungen", en: "Connections"),
                    value: viewModel.connectionsText
                ),
                MetricRowData(
                    icon: "square.split.2x2",
                    label: L10n.t(de: "Segmente", en: "Segments"),
                    value: viewModel.segmentsCountText
                ),
            ]
        case .completed:
            var rows = [
                MetricRowData(
                    icon: "timer",
                    label: L10n.t(de: "Dauer", en: "Duration"),
                    value: viewModel.downloadDurationText
                ),
                MetricRowData(
                    icon: "gauge.with.dots.needle.33percent",
                    label: L10n.t(de: "Ø Geschwindigkeit", en: "Avg Speed"),
                    value: viewModel.averageSpeedText,
                    tint: .green
                ),
                MetricRowData(
                    icon: "bolt.fill",
                    label: L10n.t(de: "Spitzengeschw.", en: "Peak Speed"),
                    value: viewModel.peakSpeedText,
                    tint: .orange
                ),
                MetricRowData(
                    icon: "calendar",
                    label: L10n.t(de: "Abgeschlossen", en: "Completed"),
                    value: viewModel.completedRelativeText
                ),
            ]
            if !viewModel.fileExistsOnDisk {
                rows.append(
                    MetricRowData(
                        icon: "exclamationmark.triangle.fill",
                        label: L10n.t(de: "Datei", en: "File"),
                        value: L10n.t(de: "Nicht gefunden", en: "Not found"),
                        tint: .orange
                    )
                )
            }
            return rows
        case .paused:
            return [
                MetricRowData(
                    icon: "gauge.with.dots.needle.33percent",
                    label: L10n.t(de: "Ø Geschwindigkeit", en: "Avg Speed"),
                    value: viewModel.hasSpeedHistory ? viewModel.averageSpeedText : "—"
                ),
                MetricRowData(
                    icon: "bolt.fill",
                    label: L10n.t(de: "Spitzengeschw.", en: "Peak Speed"),
                    value: viewModel.hasSpeedHistory ? viewModel.peakSpeedText : "—",
                    tint: .orange
                ),
                MetricRowData(
                    icon: "network",
                    label: L10n.t(de: "Verbindungen", en: "Connections"),
                    value: viewModel.connectionsText
                ),
                MetricRowData(
                    icon: "square.split.2x2",
                    label: L10n.t(de: "Segmente", en: "Segments"),
                    value: viewModel.segmentsCountText
                ),
            ]
        case .failed:
            return [
                MetricRowData(
                    icon: "xmark.circle",
                    label: L10n.t(de: "Status", en: "Status"),
                    value: viewModel.statusBadge.label,
                    tint: .red
                ),
                MetricRowData(
                    icon: "arrow.down.circle",
                    label: L10n.t(de: "Heruntergeladen", en: "Downloaded"),
                    value: viewModel.downloadedText
                ),
            ]
        default:
            return [
                MetricRowData(
                    icon: "doc",
                    label: L10n.t(de: "Status", en: "Status"),
                    value: viewModel.statusBadge.label
                ),
                MetricRowData(
                    icon: "internaldrive",
                    label: L10n.t(de: "Größe", en: "Size"),
                    value: viewModel.sizeText
                ),
                MetricRowData(
                    icon: "network",
                    label: L10n.t(de: "Verbindungen", en: "Connections"),
                    value: viewModel.connectionsText
                ),
            ]
        }
    }

    // MARK: - Right: Chart / Connections

    @ViewBuilder
    private var rightPanelColumn: some View {
        if viewModel.showsSpeedChart {
            VStack(alignment: .leading, spacing: 6) {
                columnTitle(L10n.t(de: "Geschwindigkeit", en: "Speed"))

                SpeedChartView(
                    samples: viewModel.speedSamples,
                    caption: viewModel.status == .downloading ? viewModel.speedText : "",
                    isHistorical: viewModel.status != .downloading,
                    showsHeader: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.segments.count > 1 {
                    SegmentVisualizerView(
                        segments: viewModel.segments,
                        bytesTotal: item.bytesTotal,
                        downloadCompleted: viewModel.status == .completed
                    )
                    .frame(height: 6)
                }
            }
        } else {
            connectionsPanel
        }
    }

    private var connectionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            columnTitle(L10n.t(de: "Verbindungen", en: "Connections"))

            if viewModel.segments.count > 1 {
                SegmentVisualizerView(
                    segments: viewModel.segments,
                    bytesTotal: item.bytesTotal,
                    downloadCompleted: viewModel.status == .completed
                )
                .frame(height: 8)

                Text(L10n.t(
                    de: "\(viewModel.segmentsCountText) Segmente · \(viewModel.connectionsText)× Verbindungen",
                    en: "\(viewModel.segmentsCountText) segments · \(viewModel.connectionsText)× connections"
                ))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    ForEach(Array(viewModel.segments.sorted(by: { $0.index < $1.index }).prefix(6))) { segment in
                        compactSegmentRow(segment)
                    }
                }
            } else {
                Text(L10n.t(
                    de: "Einzelne Verbindung",
                    en: "Single connection"
                ))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

                if viewModel.showsProgressBar {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .tint(viewModel.progressTint)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Components

    private var fileTypeIcon: some View {
        Image(nsImage: FileTypeHelper.systemIcon(for: viewModel.fileName))
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private func columnTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    private func overviewRow(
        icon: String,
        label: String,
        value: String,
        action: (() -> Void)? = nil,
        actionHelp: String? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 12)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .leading)

            if let action {
                Button(action: action) {
                    Text(value)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .underline(pattern: .dot, color: .secondary.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help(actionHelp ?? label)
            } else {
                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func metricRow(icon: String, label: String, value: String, tint: Color = .secondary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 12)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint == .secondary ? .primary : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var inspectorResizeHandle: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.primary.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 6)
                .padding(.bottom, 4)
                .frame(width: 120, height: 16)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if resizeDragStartHeight == nil {
                                resizeDragStartHeight = expandedHeight
                            }
                            let proposed = (resizeDragStartHeight ?? expandedHeight) - value.translation.height
                            expandedHeight = min(
                                max(proposed, AppTheme.inspectorExpandedHeightMin),
                                AppTheme.inspectorExpandedHeightMax
                            )
                        }
                        .onEnded { _ in
                            resizeDragStartHeight = nil
                        }
                )
                .help(L10n.t(de: "Inspector-Höhe anpassen", en: "Resize inspector"))
        }
        .frame(maxWidth: .infinity)
    }

    private var collapseButton: some View {
        Button {
            withAnimation(AppTheme.inspectorSpring) {
                isCollapsed.toggle()
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .appGlassChip(interactive: true)
        .animation(AppTheme.inspectorSpring, value: isCollapsed)
        .help(isCollapsed
            ? L10n.t(de: "Inspector einblenden", en: "Expand Inspector")
            : L10n.t(de: "Inspector ausblenden", en: "Collapse Inspector"))
        .accessibilityLabel(isCollapsed
            ? L10n.t(de: "Inspector einblenden", en: "Expand Inspector")
            : L10n.t(de: "Inspector ausblenden", en: "Collapse Inspector"))
    }

    private var inspectorActions: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                if viewModel.canResume {
                    inspectorActionButton(
                        icon: "play.fill",
                        help: L10n.t(de: "Fortsetzen", en: "Resume"),
                        action: viewModel.resume
                    )
                }
                if viewModel.canPause {
                    inspectorActionButton(
                        icon: "pause.fill",
                        help: L10n.t(de: "Pausieren", en: "Pause"),
                        action: viewModel.pause
                    )
                }
                if viewModel.canCancel {
                    inspectorActionButton(
                        icon: "stop.fill",
                        help: L10n.t(de: "Abbrechen", en: "Cancel"),
                        action: viewModel.cancel
                    )
                }
                if viewModel.canOpenFile {
                    inspectorActionButton(
                        icon: "arrow.up.forward.square",
                        help: L10n.t(de: "Datei öffnen", en: "Open File"),
                        action: viewModel.openFile
                    )
                }
                if viewModel.canRevealInFinder {
                    inspectorActionButton(
                        icon: "folder.fill",
                        help: L10n.t(de: "Im Finder anzeigen", en: "Reveal in Finder"),
                        action: viewModel.revealInFinder
                    )
                }
                inspectorActionButton(
                    icon: "link",
                    help: L10n.t(de: "URL kopieren", en: "Copy URL"),
                    action: viewModel.copyURL
                )
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .appGlassCapsule()
        }
    }

    private func inspectorActionButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func compactSegmentRow(_ segment: DownloadSegment) -> some View {
        let progress = viewModel.segmentProgress(segment)

        return HStack(spacing: 6) {
            Text(L10n.t(de: "S\(segment.index + 1)", en: "S\(segment.index + 1)"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .leading)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(segment.isCompleted ? .green : .accentColor)
                .frame(height: 3)

            Text("\(Int(progress * 100))%")
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            if segment.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 9))
            }
        }
    }
}

private extension AnyTransition {
    static var inspectorExpand: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 10)),
            removal: .opacity.combined(with: .offset(y: 6))
        )
    }
}
