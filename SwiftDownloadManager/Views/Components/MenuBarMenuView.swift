import SwiftUI
import SwiftData

struct MenuBarMenuView: View {
    @Bindable private var downloadManager = DownloadManager.shared
    @Query private var downloads: [DownloadItem]

    var body: some View {
        let activeCount = downloadManager.sessions.activeCount
        let failedCount = downloads.filter { $0.status == .failed || $0.status == .cancelled }.count
        let missingCount = downloads.filter {
            $0.status == .completed && FileLocationMonitor.shared.isMissing(id: $0.id)
        }.count
        let queuedCount = downloads.filter {
            $0.status == .queued || $0.status == .received || $0.status == .pendingConfirmation
        }.count

        Button(L10n.t(de: "Swift Download Manager öffnen", en: "Open Swift Download Manager")) {
            BackgroundAppManager.shared.showMainWindow()
        }

        if activeCount > 0 {
            Text(L10n.t(
                de: "\(activeCount) Download(s) aktiv",
                en: "\(activeCount) active download(s)"
            ))
            .disabled(true)
        }

        if queuedCount > 0 {
            Text(L10n.t(
                de: "\(queuedCount) in Warteschlange",
                en: "\(queuedCount) in queue"
            ))
            .disabled(true)
        }

        if failedCount > 0 {
            Text(L10n.t(
                de: "\(failedCount) fehlgeschlagen",
                en: "\(failedCount) failed"
            ))
            .disabled(true)
        }

        if missingCount > 0 {
            Text(L10n.t(
                de: "\(missingCount) Datei(en) fehlen",
                en: "\(missingCount) file(s) missing"
            ))
            .disabled(true)
        }

        Divider()

        Button(L10n.t(de: "Einstellungen…", en: "Settings…")) {
            BackgroundAppManager.shared.showMainWindow()
            SettingsNavigation.open()
        }

        Divider()

        Button(L10n.t(de: "Beenden", en: "Quit")) {
            NSApplication.shared.terminate(nil)
        }
    }
}

struct MenuBarStatusLabel: View {
    @Bindable private var downloadManager = DownloadManager.shared
    @Bindable private var fileMonitor = FileLocationMonitor.shared

    var body: some View {
        let _ = fileMonitor.revision
        let activeCount = downloadManager.sessions.activeCount
        let symbol: String = {
            if activeCount > 0 { return "arrow.down.circle.fill" }
            return "arrow.down.circle"
        }()

        Image(systemName: symbol)
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel(L10n.t(de: "Swift Download Manager", en: "Swift Download Manager"))
            .accessibilityValue(activeCount > 0
                ? L10n.t(de: "\(activeCount) aktiv", en: "\(activeCount) active")
                : L10n.t(de: "Bereit", en: "Ready"))
    }
}
