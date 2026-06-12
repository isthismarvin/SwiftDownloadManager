import Foundation
import os

enum SandboxDiagnostics {
    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "Sandbox")

    static func logStartupStatus() {
        let fileManager = FileManager.default

        guard let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            logger.error("Could not resolve Downloads directory URL")
            return
        }

        let resolved = downloadsURL.resolvingSymlinksInPath()
        logger.info("Downloads directory: \(resolved.path, privacy: .public)")

        if resolved.path.contains("/Library/Containers/") {
            logger.warning(
                "Downloads resolves inside the app container. Launch the signed .app (SweetPad: Build & Run / Xcode ⌘R), not SwiftUI Preview."
            )
        } else {
            logger.info("Downloads folder entitlement is active")
        }

        let probeURL = resolved.appendingPathComponent(".sdm-sandbox-probe")
        do {
            try Data().write(to: probeURL)
            try fileManager.removeItem(at: probeURL)
            logger.info("Downloads folder is writable")
        } catch {
            logger.error("Downloads folder is not writable: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func exportDiagnosticReport() -> String {
        let fileManager = FileManager.default
        let downloads = DownloadPathResolver.preferredDefaultDirectory().path
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.path ?? "—"
        let settings = AppSettings.shared

        var lines = [
            "Swift Download Manager — Diagnose",
            "Erstellt: \(ISO8601DateFormatter().string(from: Date()))",
            "",
            "Downloads: \(downloads)",
            "Application Support: \(appSupport)",
            "Parallele Downloads: \(AppSettings.shared.maxConcurrentDownloads)",
            "Speed-Limit: \(AppSettings.shared.effectiveSpeedLimitBytesPerSecond) B/s",
            "Bestätigungs-Dialog: \(settings.showConfirmationDialog)",
            "Completion-Dialog: \(settings.showCompletionDialog)",
            "Domain-Regeln: \(DomainRuleStore.allRules().count)",
            "Zuletzt verwendete Ordner: \(RecentDestinationsStore.all().count)",
        ]

        let probeURL = URL(fileURLWithPath: downloads).appendingPathComponent(".sdm-sandbox-probe")
        do {
            try Data().write(to: probeURL)
            try fileManager.removeItem(at: probeURL)
            lines.append("Downloads beschreibbar: ja")
        } catch {
            lines.append("Downloads beschreibbar: nein (\(error.localizedDescription))")
        }

        return lines.joined(separator: "\n")
    }
}
