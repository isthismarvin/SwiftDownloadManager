import AppKit
import Foundation
import os

enum SystemPowerHelper: Sendable {
    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "Power")

    @MainActor
    static func executeOnQueueCompleteAction() {
        let action = AppSettings.shared.onQueueCompleteAction
        switch action {
        case .doNothing:
            break
        case .sleepMac:
            logger.info("Putting Mac to sleep per onQueueCompleteAction")
            sleepMac()
        case .quitApp:
            logger.info("Quitting application per onQueueCompleteAction")
            NSApplication.shared.terminate(nil)
        }
    }

    static func sleepMac() {
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptSource = "tell application \"Finder\" to sleep"
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                if let error {
                    logger.error("Failed to sleep Mac: \(String(describing: error))")
                }
            }
        }
    }
}
