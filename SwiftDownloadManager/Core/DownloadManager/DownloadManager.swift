import AppKit
import Foundation
import SwiftData
import Observation
import os

enum ReceiveDownloadOutcome: Sendable {
    case awaitingConfirmation(UUID)
    case queued(UUID)
    case duplicateAwaitingConfirmation(newID: UUID, existingID: UUID)
    case blocked
}

enum DownloadSortOrder: String, CaseIterable, Identifiable, Codable {
    case dateAdded
    case name
    case progress
    case speed
    case status
    case size
    case eta

    var id: String { rawValue }

    static func fromPersisted(_ raw: String?) -> DownloadSortOrder {
        switch raw {
        case "dateAdded", "Date Added": return .dateAdded
        case "name", "Name": return .name
        case "progress", "Progress": return .progress
        case "speed", "Speed": return .speed
        case "status", "Status": return .status
        case "size", "Size": return .size
        case "eta", "ETA": return .eta
        default: return .dateAdded
        }
    }

    /// Default direction when the user selects this column for the first time.
    var prefersAscending: Bool {
        switch self {
        case .name, .status, .eta: return true
        case .dateAdded, .progress, .speed, .size: return false
        }
    }

    var displayName: String {
        switch self {
        case .dateAdded: return L10n.t(de: "Datum", en: "Date")
        case .name: return L10n.t(de: "Name", en: "Name")
        case .progress: return L10n.t(de: "Fortschritt", en: "Progress")
        case .speed: return L10n.t(de: "Geschwindigkeit", en: "Speed")
        case .status: return L10n.t(de: "Status", en: "Status")
        case .size: return L10n.t(de: "Größe", en: "Size")
        case .eta: return L10n.t(de: "Verbleibend", en: "Remaining")
        }
    }
}

@Observable
@MainActor
final class DownloadManager {
    static let shared = DownloadManager()

    let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "DownloadManager")

    private(set) var modelContext: ModelContext?
    let engine = DownloadEngine()
    let sessions = DownloadSessionRegistry()
    var metricsTrackers: [UUID: DownloadMetricsTracker] = [:]
    private(set) var aggregateDisplaySpeed: Double = 0
    var pendingSave = false
    var saveDebounceTask: Task<Void, Never>?
    var metadataProbeTasks: [UUID: Task<Void, Never>] = [:]
    var prepareDownloadTasks: [UUID: Task<Void, Never>] = [:]
    var metadataProbeGeneration: [UUID: UInt64] = [:]
    var prepareDownloadGeneration: [UUID: UInt64] = [:]
    /// Security-scoped directory URLs held open while a download writes into a
    /// user-selected folder. Released when the download stops.
    var scopedDirectories: [UUID: URL] = [:]
    /// Progress arriving from the engine is kept in memory and only flushed to
    /// SwiftData at the debounced save cadence — live UI reads the metrics
    /// trackers instead of the store.
    var progressCache: [UUID: (received: Int64, total: Int64)] = [:]
    var segmentProgressCache: [UUID: [Int: Int64]] = [:]
    var isConfigured = false
    var isListeningToEngine = false
    var schedulerTask: Task<Void, Never>?
    /// Downloads waiting for the completion dialog (FIFO).
    var completionDialogQueue: [UUID] = []
    /// Per-download conflict policy chosen in the confirmation dialog when global policy is `.ask`.
    var conflictPolicyOverrides: [UUID: DestinationConflictPolicy] = [:]
    var lastProgressAt: [UUID: Date] = [:]
    var intelligenceMonitorTask: Task<Void, Never>?
    var lastQueueBacklogNotified: Int?

    private init() {}

    // MARK: - Setup

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext

        if !isConfigured {
            isConfigured = true
            SandboxDiagnostics.logStartupStatus()
            startListeningToEngineEvents()
            applyFairBandwidthSharing()
            applySegmentRetries(AppSettings.shared.segmentRetries)
            repairInterruptedDownloads()
            pruneHistory(olderThanDays: AppSettings.shared.historyRetentionDays)
            NotificationService.requestAuthorization()
            LocalHTTPServer.shared.start()
            startScheduler()
            FileLocationMonitor.shared.start { [weak self] in
                self?.reconcileAllCompletedFileLocations()
            }
            reconcileAllCompletedFileLocations()
            startIntelligenceMonitoring()
            logger.info("DownloadManager configured")
        }

        refreshAggregateDisplaySpeed()
        processQueue()
    }

    // MARK: - App lifecycle

    var hasActiveDownloads: Bool {
        sessions.activeCount > 0
    }

    /// Synchronously persists all pending changes (used right before quit).
    func flushPendingChanges() {
        saveNow()
    }

    func togglePauseResume(id: UUID) {
        guard let item = fetchItem(id: id) else { return }
        switch item.status {
        case .downloading, .queued:
            pauseDownload(id: id)
        case .paused, .failed, .cancelled:
            startDownload(id: id)
        case .received, .pendingConfirmation, .completed:
            break
        }
    }

    /// Only downloads that were actively running when the app quit are paused.
    private func repairInterruptedDownloads() {
        guard let modelContext = modelContext else { return }
        let descriptor = FetchDescriptor<DownloadItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }

        var changed = false
        for item in items where item.status == .downloading {
            item.status = .paused
            changed = true
            logger.info("Paused interrupted download \(item.fileName, privacy: .public)")
        }
        for item in items where item.status == .received {
            startMetadataProbe(for: item.id)
        }
        if changed {
            saveNow()
        }
        sessions.resetAll()
    }

    func metricsTracker(for id: UUID) -> DownloadMetricsTracker {
        if let tracker = metricsTrackers[id] {
            return tracker
        }
        let tracker = DownloadMetricsTracker()
        if let item = fetchItem(id: id) {
            tracker.loadPersistedSamples(SpeedHistoryStore.decode(item.speedHistoryJSON))
        }
        metricsTrackers[id] = tracker
        return tracker
    }

    func effectiveConflictPolicy(for downloadID: UUID) -> DestinationConflictPolicy {
        conflictPolicyOverrides[downloadID] ?? AppSettings.shared.conflictPolicy
    }

    func refreshAggregateDisplaySpeed() {
        aggregateDisplaySpeed = fetchAllItemsForUI()
            .filter { $0.status == .downloading }
            .reduce(0.0) { partial, item in
                partial + metricsTracker(for: item.id).displaySpeed
            }
    }
}
