import SwiftUI

/// Shared icon and color semantics for download status across sidebar, table, and inspector.
enum DownloadStatusAppearance {
    static func badge(
        for status: DownloadStatus,
        isScheduled: Bool = false,
        isHeldInQueue: Bool = false
    ) -> StatusBadgeInfo {
        switch status {
        case .received:
            return StatusBadgeInfo(
                label: L10n.t(de: "Empfangen", en: "Received"),
                icon: "tray.and.arrow.down",
                color: .secondary
            )
        case .pendingConfirmation:
            return StatusBadgeInfo(
                label: L10n.t(de: "Wartet auf Bestätigung", en: "Awaiting Confirmation"),
                icon: "hand.raised.circle.fill",
                color: .yellow
            )
        case .queued:
            if isScheduled {
                return StatusBadgeInfo(
                    label: L10n.t(de: "Geplant", en: "Scheduled"),
                    icon: "calendar.badge.clock",
                    color: .purple
                )
            }
            if isHeldInQueue {
                return StatusBadgeInfo(
                    label: L10n.t(de: "Gehalten", en: "Held"),
                    icon: "tray.fill",
                    color: .orange
                )
            }
            return StatusBadgeInfo(
                label: L10n.t(de: "In Warteschlange", en: "Queued"),
                icon: "clock.fill",
                color: .secondary
            )
        case .downloading:
            return StatusBadgeInfo(
                label: L10n.t(de: "Lädt herunter", en: "Downloading"),
                icon: "arrow.down.circle.fill",
                color: .blue
            )
        case .paused:
            return StatusBadgeInfo(
                label: L10n.t(de: "Pausiert", en: "Paused"),
                icon: "pause.circle.fill",
                color: .orange
            )
        case .completed:
            return StatusBadgeInfo(
                label: L10n.t(de: "Abgeschlossen", en: "Completed"),
                icon: "checkmark.circle.fill",
                color: .green
            )
        case .failed:
            return StatusBadgeInfo(
                label: L10n.t(de: "Fehlgeschlagen", en: "Failed"),
                icon: "xmark.circle.fill",
                color: .red
            )
        case .cancelled:
            return StatusBadgeInfo(
                label: L10n.t(de: "Abgebrochen", en: "Cancelled"),
                icon: "minus.circle.fill",
                color: .secondary
            )
        }
    }

    static func sidebarIcon(for selection: SidebarSelection) -> String {
        switch selection {
        case .allDownloads: return "tray.and.arrow.down.fill"
        case .queue: return "clock.fill"
        case .scheduled: return badge(for: .queued, isScheduled: true).icon
        case .downloading: return badge(for: .downloading).icon
        case .paused: return badge(for: .paused).icon
        case .completed: return badge(for: .completed).icon
        case .failed: return badge(for: .failed).icon
        case .missingFile: return "exclamationmark.triangle.fill"
        case .today: return "calendar"
        case .largeFiles: return "externaldrive.fill"
        case .allFiles, .library, .customFolder: return "folder.fill"
        }
    }

    static func sidebarColor(for selection: SidebarSelection) -> Color {
        switch selection {
        case .allDownloads, .allFiles, .library, .customFolder: return .blue
        case .queue: return badge(for: .queued).color
        case .scheduled: return badge(for: .queued, isScheduled: true).color
        case .downloading: return badge(for: .downloading).color
        case .paused: return badge(for: .paused).color
        case .completed: return badge(for: .completed).color
        case .failed: return badge(for: .failed).color
        case .missingFile: return .orange
        case .today: return .purple
        case .largeFiles: return .indigo
        }
    }
}
