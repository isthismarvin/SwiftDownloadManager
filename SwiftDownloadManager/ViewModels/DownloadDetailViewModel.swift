import Foundation
import AppKit
import SwiftUI

/// Reads the SwiftData item and metrics tracker during `body` evaluation so
/// live progress and speed stay in sync with the download table.
@MainActor
struct DownloadDetailViewModel {
    private let row: DownloadRowViewModel
    private let item: DownloadItem
    private let metrics: DownloadMetricsTracker

    init(item: DownloadItem, metrics: DownloadMetricsTracker? = nil) {
        self.item = item
        self.metrics = metrics ?? DownloadManager.shared.metricsTracker(for: item.id)
        self.row = DownloadRowViewModel(item: item, metrics: self.metrics)
    }

    var fileName: String { row.fileName }
    var status: DownloadStatus { row.status }
    var statusBadge: StatusBadgeInfo { row.statusBadge }
    var progress: Double { row.progress }
    var progressText: String { row.progressText }
    var progressTint: Color { row.progressTint }
    var showsProgressBar: Bool { row.showsProgressBar }
    var showsPercentLabel: Bool { row.showsPercentLabel }

    var downloadedText: String { ByteFormatter.format(row.bytesReceived) }
    var totalText: String { row.bytesTotal > 0 ? ByteFormatter.format(row.bytesTotal) : L10n.unknown }
    var speedText: String { row.speedText }
    var etaText: String { row.etaText }
    var connectionsText: String { "\(metrics.activeConnections)" }

    var savePathText: String {
        if let path = resolvedFileURL?.path {
            return path
        }
        if let path = item.localFilePath {
            return path
        }
        if let dir = item.saveDirectoryPath {
            return (dir as NSString).appendingPathComponent(item.fileName)
        }
        return "~/Downloads/\(item.fileName)"
    }

    var completedAtText: String {
        L10n.formatRelativeDateTime(item.completedAt ?? item.createdAt)
    }

    var createdAtText: String {
        L10n.formatRelativeDateTime(item.createdAt)
    }

    var urlText: String { item.urlString }
    var sourceText: String { item.source?.displayName ?? L10n.unknown }

    var supportsResumeText: String {
        item.supportsResume ? L10n.yes : L10n.no
    }

    var segmentsCountText: String {
        "\(max(item.segments.count, item.preferredSegmentsCount))"
    }

    var errorMessage: String? { item.errorMessage }
    var segments: [DownloadSegment] { item.segments }
    var speedSamples: [SpeedSample] {
        let live = metrics.exportSamples()
        if !live.isEmpty { return live }
        return SpeedHistoryStore.decode(item.speedHistoryJSON)
    }

    var hasSpeedHistory: Bool { !speedSamples.isEmpty }
    var showsSpeedChart: Bool { status == .downloading || hasSpeedHistory }
    var subtitleText: String { row.subtitleText }
    var sizeText: String { row.sizeText }

    var peakSpeedText: String {
        TimeFormatter.formatSpeed(SpeedMetricsSummary.peakSpeed(from: speedSamples))
    }

    var averageSpeedText: String {
        let sampleAverage = SpeedMetricsSummary.averageSpeed(from: speedSamples)
        let duration = SpeedMetricsSummary.duration(
            samples: speedSamples,
            startedAt: item.createdAt,
            finishedAt: item.completedAt
        )
        let throughput = SpeedMetricsSummary.throughputAverage(
            bytesTotal: item.bytesReceived,
            duration: duration
        )
        let value = max(throughput, sampleAverage)
        return TimeFormatter.formatSpeed(value)
    }

    var downloadDurationText: String {
        TimeFormatter.formatDuration(
            SpeedMetricsSummary.duration(
                samples: speedSamples,
                startedAt: item.createdAt,
                finishedAt: item.completedAt
            )
        )
    }

    var inspectorInsight: String? {
        DownloadIntelligence.inspectorInsight(
            item: item,
            samples: speedSamples,
            averageSpeed: SpeedMetricsSummary.averageSpeed(from: speedSamples),
            peakSpeed: SpeedMetricsSummary.peakSpeed(from: speedSamples)
        )
    }

    var speedChartCaption: String {
        if status == .downloading {
            return speedText
        }
        return L10n.t(
            de: "Ø \(averageSpeedText) · Spitze \(peakSpeedText)",
            en: "Avg \(averageSpeedText) · Peak \(peakSpeedText)"
        )
    }

    var fileExtensionText: String? {
        let ext = URL(fileURLWithPath: item.fileName).pathExtension.lowercased()
        return ext.isEmpty ? nil : ".\(ext)"
    }

    var categoryText: String? {
        if let category = item.libraryCategory {
            return category.displayName
        }
        return FileTypeHelper.category(for: item.fileName)?.displayName
    }

    var fileIsMissing: Bool {
        let _ = FileLocationMonitor.shared.revision
        return FileLocationMonitor.shared.isMissing(id: item.id)
    }

    var fileExistsOnDisk: Bool {
        let _ = FileLocationMonitor.shared.revision
        return FileLocationMonitor.shared.isAvailable(id: item.id, item: item)
    }

    var fileAvailabilityText: String {
        guard item.localFilePath != nil else {
            return L10n.t(de: "Kein Pfad", en: "No path")
        }
        if fileExistsOnDisk {
            return L10n.t(de: "Datei vorhanden", en: "File available")
        }
        return L10n.t(de: "Nicht gefunden", en: "Not found")
    }

    var resolvedFileURL: URL? {
        let _ = FileLocationMonitor.shared.revision
        return FileLocationMonitor.shared.resolvedURL(for: item)
    }

    var completedRelativeText: String {
        let date = item.completedAt ?? item.createdAt
        return date.formatted(.relative(presentation: .named))
    }

    var completedAtDetailText: String {
        let date = item.completedAt ?? item.createdAt
        let absolute = date.formatted(date: .abbreviated, time: .shortened)
        return "\(absolute) · \(completedRelativeText)"
    }

    var canPause: Bool { row.canPause }
    var canResume: Bool { row.canResume }
    var canCancel: Bool { row.canCancel }
    var canRevealInFinder: Bool { row.canRevealInFinder }
    var canOpenFile: Bool { row.canOpenFile }

    func pause() { row.pause() }
    func resume() { row.resume() }
    func cancel() { row.cancel() }
    func revealInFinder() { row.revealInFinder() }
    func openFile() { row.openFile() }
    func copyURL() { row.copyURL() }

    var canRevealSaveLocation: Bool {
        canRevealInFinder
            || item.saveDirectoryPath != nil
            || AppSettings.shared.resolvedDefaultSaveDirectory() != nil
    }

    func revealSaveLocation() {
        if canRevealInFinder {
            revealInFinder()
            return
        }
        if let path = item.saveDirectoryPath {
            NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
            return
        }
        if let url = AppSettings.shared.resolvedDefaultSaveDirectory() {
            NSWorkspace.shared.open(url)
        }
    }

    func segmentProgress(_ segment: DownloadSegment) -> Double {
        segment.displayProgress(bytesTotal: item.bytesTotal, downloadCompleted: status == .completed)
    }

    func segmentReceivedText(_ segment: DownloadSegment) -> String {
        ByteFormatter.format(
            segment.displayBytesReceived(bytesTotal: item.bytesTotal, downloadCompleted: status == .completed)
        )
    }

    func segmentSizeText(_ segment: DownloadSegment) -> String {
        let size = segment.byteCapacity(bytesTotal: item.bytesTotal)
        guard size > 0 else { return L10n.unknown }
        return ByteFormatter.format(size)
    }
}
