import Foundation
import IOKit.pwr_mgt
import os

/// Manages macOS power assertions to prevent idle sleep while downloads are actively in progress.
@MainActor
final class SleepAssertionManager {
    static let shared = SleepAssertionManager()
    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "PowerAssertion")

    private var assertionID: IOPMAssertionID = 0
    private(set) var isSleepPrevented: Bool = false

    private init() {}

    /// Evaluates active downloads and user settings, creating or releasing the idle sleep assertion.
    func update(activeCount: Int) {
        let shouldPrevent = activeCount > 0 && AppSettings.shared.preventIdleSleepWhileDownloading

        if shouldPrevent && !isSleepPrevented {
            acquireAssertion(activeCount: activeCount)
        } else if !shouldPrevent && isSleepPrevented {
            releaseAssertion()
        }
    }

    private func acquireAssertion(activeCount: Int) {
        let reason = "Swift Download Manager is actively downloading \(activeCount) file\(activeCount == 1 ? "" : "s")" as CFString
        var newID: IOPMAssertionID = 0

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &newID
        )

        if result == kIOReturnSuccess {
            assertionID = newID
            isSleepPrevented = true
            Self.logger.info("Acquired idle sleep prevention assertion (ID: \(newID)) for \(activeCount) downloads")
        } else {
            Self.logger.error("Failed to acquire power assertion: error code \(result)")
        }
    }

    func releaseAssertion() {
        guard isSleepPrevented else { return }

        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            Self.logger.info("Released idle sleep prevention assertion (ID: \(self.assertionID))")
        } else {
            Self.logger.warning("IOPMAssertionRelease returned \(result)")
        }

        assertionID = 0
        isSleepPrevented = false
    }
}
