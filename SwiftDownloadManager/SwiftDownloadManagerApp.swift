import SwiftUI
import SwiftData
import AppKit

@main
struct SwiftDownloadManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let persistenceController = PersistenceController.shared
    @State private var listViewModel = DownloadListViewModel()
    @Bindable private var appSettings = AppSettings.shared

    var body: some Scene {
        let _ = appSettings.appLanguage
        // A single main window (not a WindowGroup): a download manager has
        // exactly one queue; multiple windows would just show duplicates.
        Window("", id: "main") {
            DownloadListView(viewModel: listViewModel)
                .modelContainer(persistenceController.container)
                .overlay(alignment: .top) {
                    if persistenceController.isDegradedMode {
                        degradedModeBanner
                    }
                }
                .onOpenURL { url in
                    guard let downloadURL = URLSchemeParser.downloadURL(from: url) else { return }
                    listViewModel.receiveDownload(url: downloadURL, source: .external)
                    AppActivation.bringToForeground()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.t(de: "Download hinzufügen…", en: "Add Download…")) {
                    listViewModel.isShowingAddSheet = true
                }
                .keyboardShortcut("n")

                Button(L10n.t(de: "Download aus Zwischenablage", en: "Add Download from Clipboard")) {
                    listViewModel.pasteAndDownload()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appSettings) {
                Button(L10n.t(de: "Einstellungen…", en: "Settings…")) {
                    SettingsNavigation.open()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu(L10n.t(de: "Download", en: "Download")) {
                Button(L10n.t(de: "Downloads suchen", en: "Search Downloads")) {
                    listViewModel.isSearchPresented = true
                }
                .keyboardShortcut("f")

                Divider()

                Button(L10n.t(de: "Pausieren / Fortsetzen", en: "Pause / Resume")) {
                    listViewModel.togglePauseResumeSelected()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!listViewModel.hasSelection)

                Button(L10n.t(de: "Fortsetzen", en: "Resume")) {
                    listViewModel.resumeSelected()
                }
                .keyboardShortcut("r")
                .disabled(!listViewModel.hasSelection)

                Button(L10n.t(de: "Abbrechen", en: "Cancel")) {
                    listViewModel.cancelSelected()
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!listViewModel.hasSelection)

                Button(L10n.t(de: "Löschen", en: "Delete")) {
                    listViewModel.triggerDeleteSelectionFromShortcut()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!listViewModel.hasSelection)

                Divider()

                Button(L10n.t(de: "Alle fortsetzen", en: "Resume All")) {
                    listViewModel.startAll()
                }
                Button(L10n.t(de: "Alle pausieren", en: "Pause All")) {
                    listViewModel.pauseAll()
                }

                Divider()

                Button(appSettings.inspectorCollapsed
                    ? L10n.t(de: "Inspector einblenden", en: "Show Inspector")
                    : L10n.t(de: "Inspector ausblenden", en: "Hide Inspector")) {
                    withAnimation(AppTheme.inspectorSpring) {
                        appSettings.inspectorCollapsed.toggle()
                    }
                }
                .keyboardShortcut("i")
            }
        }

        MenuBarExtra(isInserted: $appSettings.showMenuBarIcon) {
            MenuBarMenuView()
        } label: {
            MenuBarStatusLabel()
        }
        .menuBarExtraStyle(.menu)
    }

    private var degradedModeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(L10n.t(
                de: "Datenbank konnte nicht geladen werden. Downloads werden nur für diese Sitzung gespeichert.",
                en: "Could not load the database. Downloads will only be saved for this session."
            ))
            .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .appGlassBanner(tint: .orange)
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t(
            de: "Warnung: Datenbank im eingeschränkten Modus",
            en: "Warning: database running in degraded mode"
        ))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchAtLoginManager.syncWithPreference(AppSettings.shared.launchAtLogin)
        BackgroundAppManager.shared.installMainWindowDelegate()
        BackgroundAppManager.shared.applyStartupPresentation()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            DownloadManager.shared.reconcileAllCompletedFileLocations()

            let server = LocalHTTPServer.shared
            guard server.isListening else { return }
            if server.extensionConnectionState == .disconnected {
                server.beginExtensionSearch()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            BackgroundAppManager.shared.showMainWindow()
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        LocalHTTPServer.shared.stop()

        let manager = DownloadManager.shared
        guard manager.hasActiveDownloads else {
            manager.flushPendingChanges()
            return .terminateNow
        }

        guard AppSettings.shared.pauseDownloadsOnQuit else {
            manager.flushPendingChanges()
            return .terminateNow
        }

        // Pause everything so partial progress is persisted and resumable,
        // then let the engine's pause events drain before the process exits.
        Task { @MainActor in
            manager.pauseAll()
            try? await Task.sleep(for: .milliseconds(400))
            manager.flushPendingChanges()
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
