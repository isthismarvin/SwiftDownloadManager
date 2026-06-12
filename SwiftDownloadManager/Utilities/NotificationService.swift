import Foundation
import AppKit
import UserNotifications
import os

@MainActor
enum NotificationService {
    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "Notifications")

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func postDownloadCompleted(fileName: String) {
        guard AppSettings.shared.notifyOnComplete else { return }
        post(
            title: L10n.t(de: "Download abgeschlossen", en: "Download Complete"),
            body: fileName
        )
    }

    static func postDownloadFailed(fileName: String, message: String) {
        guard AppSettings.shared.notifyOnFailed else { return }
        post(
            title: L10n.t(de: "Download fehlgeschlagen", en: "Download Failed"),
            body: "\(fileName): \(message)"
        )
    }

    static func postStallWarning(fileName: String, message: String) {
        guard AppSettings.shared.notifyOnStall else { return }
        post(
            title: L10n.t(de: "Download hängt", en: "Download Stalled"),
            body: "\(fileName): \(message)"
        )
    }

    static func postQueueBacklogWarning(message: String) {
        guard AppSettings.shared.notifyOnQueueBacklog else { return }
        post(
            title: L10n.t(de: "Warteschlange voll", en: "Queue Backlog"),
            body: message
        )
    }

    /// Shows the number of active downloads on the Dock icon.
    static func updateDockBadge(activeCount: Int) {
        guard AppSettings.shared.showDockBadge else {
            NSApplication.shared.dockTile.badgeLabel = ""
            return
        }
        NSApplication.shared.dockTile.badgeLabel = activeCount > 0 ? "\(activeCount)" : ""
    }

    private static func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if AppSettings.shared.playNotificationSound {
            content.sound = .default
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
