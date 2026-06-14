import Foundation
import Observation
import SwiftUI
import AppKit

/// Lightweight value type: reads the SwiftData item and the metrics tracker
/// directly during `body` evaluation, so SwiftUI observation registers on the
/// underlying objects. Previously this was an @Observable class re-allocated on
/// every property access of every row render.
@MainActor
struct DownloadRowViewModel {
    private let item: DownloadItem
    private let metrics: DownloadMetricsTracker
    private let fileMonitor = FileLocationMonitor.shared

    init(item: DownloadItem, metrics: DownloadMetricsTracker? = nil) {
        self.item = item
        self.metrics = metrics ?? DownloadManager.shared.metricsTracker(for: item.id)
    }

    private var fileMonitorRevision: UInt64 { fileMonitor.revision }

    private var downloadID: UUID { item.id }
    var fileName: String { item.fileName }
    var status: DownloadStatus { item.status }
    var isHeldInQueue: Bool { item.holdInQueue && item.status == .queued }
    var isScheduled: Bool {
        guard let scheduled = item.scheduledStartAt else { return false }
        return scheduled > Date() && (status == .queued || status == .paused)
    }
    var urlString: String { item.urlString }
    var localFilePath: String? { resolvedFileURL?.path ?? item.localFilePath }

    var resolvedFileURL: URL? {
        let _ = fileMonitorRevision
        return fileMonitor.resolvedURL(for: item)
    }

    var fileIsMissing: Bool {
        let _ = fileMonitorRevision
        return fileMonitor.isMissing(id: downloadID)
    }

    var draggableFileURL: URL? {
        guard canRevealInFinder, let url = resolvedFileURL else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Live progress comes from the tracker while downloading; the store only
    /// persists progress at the (slow) save cadence.
    var bytesReceived: Int64 {
        if item.status == .downloading, metrics.liveBytesReceived > 0 {
            return metrics.liveBytesReceived
        }
        return item.bytesReceived
    }

    var bytesTotal: Int64 {
        if item.status == .downloading, metrics.liveBytesTotal > 0 {
            return metrics.liveBytesTotal
        }
        return item.bytesTotal
    }

    var progress: Double {
        guard bytesTotal > 0 else { return 0.0 }
        return Double(bytesReceived) / Double(bytesTotal)
    }

    var progressText: String {
        guard bytesTotal > 0 else { return "0%" }
        return "\(Int(progress * 100))%"
    }

    var speedText: String {
        switch status {
        case .downloading:
            return TimeFormatter.formatSpeed(metrics.displaySpeed)
        default:
            return "–"
        }
    }

    var etaText: String {
        guard status == .downloading else { return "–" }
        return TimeFormatter.formatETA(metrics.displayETA)
    }

    var subtitleText: String {
        if let detail = DownloadIntelligence.statusDetail(for: item, metrics: metrics) {
            return detail
        }
        if isScheduled, let scheduled = item.scheduledStartAt {
            return L10n.t(
                de: "Geplant: \(L10n.formatRelativeDateTime(scheduled))",
                en: "Scheduled: \(L10n.formatRelativeDateTime(scheduled))"
            )
        }
        if bytesReceived > 0 && bytesTotal > 0 {
            return "\(ByteFormatter.format(bytesReceived)) \(L10n.t(de: "von", en: "of")) \(ByteFormatter.format(bytesTotal))"
        }
        if bytesTotal > 0 {
            return ByteFormatter.format(bytesTotal)
        }
        return ByteFormatter.format(bytesReceived)
    }

    var sizeText: String {
        if bytesTotal > 0 {
            return ByteFormatter.format(bytesTotal)
        }
        return ByteFormatter.format(bytesReceived)
    }

    var dateText: String {
        L10n.formatRelativeDateTime(item.createdAt)
    }

    var statusBadge: StatusBadgeInfo {
        DownloadStatusAppearance.badge(
            for: status,
            isScheduled: isScheduled,
            isHeldInQueue: isHeldInQueue
        )
    }

    /// True for completed archive files the user can extract in place.
    var canUnzip: Bool {
        guard status == .completed, let path = localFilePath else { return false }
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return ["zip", "gz", "tar", "bz2", "xz", "7z", "rar", "tgz", "tbz2", "cab"].contains(ext)
    }

    func unzip() {
        guard let path = localFilePath else { return }
        // Open with the system's default handler for archive files
        // (Archive Utility on stock macOS). This is sandbox-safe and extracts
        // the archive to the same folder automatically.
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    var progressTint: Color {
        switch status {
        case .completed: return .green
        case .paused, .queued, .cancelled, .received, .pendingConfirmation: return .gray
        case .failed: return .red
        default: return .blue
        }
    }

    var showsPercentLabel: Bool {
        status == .downloading || status == .completed
    }

    var showsProgressBar: Bool {
        status != .failed && status != .cancelled
    }

    var segments: [DownloadSegment] {
        item.segments
    }

    var usesSegmentedProgress: Bool {
        segments.count > 1
    }

    var canConfirm: Bool {
        status == .received || status == .pendingConfirmation
    }

    var canPause: Bool {
        status == .downloading || status == .queued
    }

    var canResume: Bool {
        status == .paused || status == .failed || isHeldInQueue
    }

    var canCancel: Bool {
        status == .downloading || status == .paused || status == .queued
            || status == .received || status == .pendingConfirmation
    }

    var canDelete: Bool {
        true
    }

    var canRevealInFinder: Bool {
        status == .completed && resolvedFileURL != nil && !fileIsMissing
    }

    var canOpenFile: Bool {
        canRevealInFinder
    }

    func pause() {
        DownloadManager.shared.pauseDownload(id: downloadID)
    }

    func resume() {
        if isHeldInQueue {
            DownloadManager.shared.releaseHeldDownload(id: downloadID)
        } else {
            DownloadManager.shared.startDownload(id: downloadID)
        }
    }

    func confirm() {
        DownloadManager.shared.confirmDownload(id: downloadID)
    }

    func cancel() {
        if canConfirm {
            DownloadManager.shared.rejectDownload(id: downloadID)
        } else {
            DownloadManager.shared.cancelDownload(id: downloadID)
        }
    }

    func delete() {
        DownloadManager.shared.deleteDownload(id: downloadID)
    }

    func revealInFinder() {
        DownloadManager.shared.reconcileFileLocation(for: downloadID)
        guard let url = resolvedFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFile() {
        DownloadManager.shared.reconcileFileLocation(for: downloadID)
        guard let url = resolvedFileURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
    }
}
