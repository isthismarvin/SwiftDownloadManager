import Foundation
import Observation
import os
import ServiceManagement

/// Registers the app as a login item via `SMAppService` (macOS 13+).
@MainActor
enum LaunchAtLoginManager {
    private static let logger = Logger(
        subsystem: "nrw.marvin.SwiftDownloadManager",
        category: "LaunchAtLogin"
    )

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static var statusFootnote: String? {
        switch SMAppService.mainApp.status {
        case .requiresApproval:
            return L10n.t(
                de: "Erlaube den Start in Systemeinstellungen → Allgemein → Beim Anmelden öffnen.",
                en: "Allow launch in System Settings → General → Open at Login."
            )
        case .notFound:
            return L10n.t(
                de: "Login-Item nicht gefunden — Schalter erneut aktivieren.",
                en: "Login item not found — toggle the switch again."
            )
        default:
            return nil
        }
    }

    /// Aligns `SMAppService` with the stored user preference (e.g. on launch).
    static func syncWithPreference(_ enabled: Bool) {
        let registered = isEnabled
        guard enabled != registered else { return }
        setEnabled(enabled)
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Registered login item")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Unregistered login item")
            }
        } catch {
            logger.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
