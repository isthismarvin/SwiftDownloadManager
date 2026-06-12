import Foundation
import SwiftData
import os

extension DownloadManager {
    func startIntelligenceMonitoring() {
        intelligenceMonitorTask?.cancel()
        intelligenceMonitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                self?.checkForStalledDownloads()
                self?.checkQueueBacklog()
            }
        }
    }

    func noteProgress(for id: UUID) {
        lastProgressAt[id] = Date()
    }

    func applyFairBandwidthSharing() {
        let settings = AppSettings.shared
        let baseLimit = settings.effectiveSpeedLimitBytesPerSecond
        guard settings.smartFeaturesEnabled, settings.fairBandwidthSharing else {
            engine.setSpeedLimit(baseLimit)
            return
        }

        let active = max(sessions.activeCount, 1)
        if baseLimit > 0, active > 1 {
            engine.setSpeedLimit(max(baseLimit / Int64(active), 100_000))
        } else {
            engine.setSpeedLimit(baseLimit)
        }
    }

    func findContentDuplicate(
        fileName: String,
        bytesTotal: Int64,
        saveDirectoryPath: String?,
        excluding excludedID: UUID? = nil
    ) -> DownloadItem? {
        guard AppSettings.shared.smartFeaturesEnabled,
              AppSettings.shared.detectContentDuplicates,
              bytesTotal > 0 else { return nil }
        guard let modelContext else { return nil }

        let descriptor = FetchDescriptor<DownloadItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return nil }

        return items.first { item in
            if let excludedID, item.id == excludedID { return false }
            guard item.status == .completed else { return false }
            guard item.fileName == fileName, item.bytesTotal == bytesTotal else { return false }
            if let saveDirectoryPath, let itemPath = item.saveDirectoryPath {
                return itemPath == saveDirectoryPath
            }
            return true
        }
    }

    func recordIntelligenceAfterCompletion(_ item: DownloadItem) {
        DownloadIntelligence.recordCompletedDownload(item)
    }

    private func checkForStalledDownloads() {
        guard AppSettings.shared.smartFeaturesEnabled,
              AppSettings.shared.stallDetectionEnabled,
              let modelContext else { return }

        let timeout = TimeInterval(AppSettings.shared.stallTimeoutSeconds)
        let now = Date()
        let descriptor = FetchDescriptor<DownloadItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }

        for item in items where item.status == .downloading {
            let last = lastProgressAt[item.id] ?? now
            guard now.timeIntervalSince(last) >= timeout else { continue }

            logger.warning("Stalled download detected: \(item.fileName, privacy: .public)")

            NotificationService.postStallWarning(
                fileName: item.fileName,
                message: L10n.t(
                    de: "Kein Fortschritt seit \(AppSettings.shared.stallTimeoutSeconds)s",
                    en: "No progress for \(AppSettings.shared.stallTimeoutSeconds)s"
                )
            )

            if AppSettings.shared.stallAutoRetry {
                engine.pauseDownload(id: item.id)
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(300))
                    self?.resumeDownload(id: item.id)
                }
            }

            lastProgressAt[item.id] = now
        }
    }

    private func checkQueueBacklog() {
        guard AppSettings.shared.smartFeaturesEnabled,
              AppSettings.shared.notifyOnQueueBacklog,
              let modelContext else { return }

        let descriptor = FetchDescriptor<DownloadItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }

        let queued = items.filter {
            $0.status == .queued || $0.status == .received || $0.status == .pendingConfirmation
        }.count

        let threshold = AppSettings.shared.queueBacklogThreshold
        guard queued >= threshold else {
            lastQueueBacklogNotified = nil
            return
        }

        if lastQueueBacklogNotified != queued {
            lastQueueBacklogNotified = queued
            NotificationService.postQueueBacklogWarning(
                message: L10n.t(
                    de: "\(queued) Downloads warten in der Warteschlange",
                    en: "\(queued) downloads waiting in queue"
                )
            )
        }
    }
}
