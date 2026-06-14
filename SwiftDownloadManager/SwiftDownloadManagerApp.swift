import SwiftUI
import SwiftData
import AppKit

@main
struct SwiftDownloadManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let persistenceController = PersistenceController.shared
    @State private var listViewModel = DownloadListViewModel()
    @Bindable private var appSettings = AppSettings.shared
    @Bindable private var shortcutSettings = AppShortcutSettings.shared

    var body: some Scene {
        let _ = appSettings.appLanguage
        let _ = shortcutSettings.revision
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
                .appShortcut(.addDownload)

                Button(L10n.t(de: "Download aus Zwischenablage", en: "Add Download from Clipboard")) {
                    listViewModel.pasteAndDownload()
                }
                .appShortcut(.addFromClipboard)

                Divider()

                Button(L10n.t(de: "Datei öffnen", en: "Open File")) {
                    listViewModel.openSelectedFile()
                }
                .appShortcut(.openFile)
                .disabled(!listViewModel.canOpenSelected || !listViewModel.canUseMainShortcuts)

                Button(L10n.t(de: "Im Finder anzeigen", en: "Reveal in Finder")) {
                    listViewModel.revealSelectedInFinder()
                }
                .appShortcut(.revealInFinder)
                .disabled(!listViewModel.canRevealSelectedInFinder || !listViewModel.canUseMainShortcuts)

                Button(L10n.t(de: "URL kopieren", en: "Copy URL")) {
                    listViewModel.copySelectedURL()
                }
                .appShortcut(.copyURL)
                .disabled(!listViewModel.canCopySelectedURL || !listViewModel.canUseMainShortcuts)

                Divider()

                Button(L10n.t(de: "Downloads-Ordner öffnen", en: "Open Downloads Folder")) {
                    listViewModel.openDownloadsFolder()
                }
                .appShortcut(.openDownloadsFolder)

                Button(L10n.t(de: "Neuer Ordner", en: "New Folder")) {
                    listViewModel.showNewFolderAlert()
                }
                .appShortcut(.newFolder)
                .disabled(!listViewModel.canUseMainShortcuts)
            }

            CommandGroup(after: .pasteboard) {
                Button(L10n.t(de: "Alles auswählen", en: "Select All")) {
                    listViewModel.selectAllVisible()
                }
                .appShortcut(.selectAll)
                .disabled(!listViewModel.canUseMainShortcuts)

                Button(L10n.t(de: "Auswahl aufheben", en: "Deselect All")) {
                    listViewModel.clearSelection()
                }
                .appShortcut(.deselectAll)
                .disabled(!listViewModel.hasSelection || !listViewModel.canUseMainShortcuts)

                Divider()

                Button(L10n.t(de: "Löschen", en: "Delete")) {
                    listViewModel.triggerDeleteSelectionFromShortcut()
                }
                .appShortcut(.delete)
                .disabled(!listViewModel.hasSelection || !listViewModel.canUseMainShortcuts)
            }

            CommandMenu(L10n.t(de: "Download", en: "Download")) {
                Button(L10n.t(de: "Downloads suchen", en: "Search Downloads")) {
                    listViewModel.performSearch()
                }
                .appShortcut(.search)

                Divider()

                Button(L10n.t(de: "Fortsetzen", en: "Resume")) {
                    listViewModel.resumeSelected()
                }
                .appShortcut(.resume)
                .disabled(
                    !listViewModel.hasSelection
                        || !listViewModel.canResumeSelected
                        || !listViewModel.canUseMainShortcuts
                )

                Button(L10n.t(de: "Pausieren", en: "Pause")) {
                    listViewModel.pauseSelected()
                }
                .appShortcut(.pause)
                .disabled(
                    !listViewModel.hasSelection
                        || !listViewModel.canPauseSelected
                        || !listViewModel.canUseMainShortcuts
                )

                Button(L10n.t(de: "Abbrechen", en: "Cancel")) {
                    listViewModel.cancelSelected()
                }
                .appShortcut(.cancel)
                .disabled(
                    !listViewModel.hasSelection
                        || !listViewModel.canCancelSelected
                        || !listViewModel.canUseMainShortcuts
                )

                Divider()

                Button(L10n.t(de: "Alle fortsetzen", en: "Resume All")) {
                    listViewModel.startAll()
                }
                .appShortcut(.resumeAll)
                .disabled(!listViewModel.canResumeAll)

                Button(L10n.t(de: "Alle pausieren", en: "Pause All")) {
                    listViewModel.pauseAll()
                }
                .appShortcut(.pauseAll)
                .disabled(!listViewModel.canPauseAll)

                Divider()

                Button(L10n.t(de: "Abgeschlossene löschen", en: "Clear Completed")) {
                    listViewModel.clearCompleted()
                }
                .appShortcut(.clearCompleted)
                .disabled(!listViewModel.canUseMainShortcuts)
            }

            CommandGroup(after: .sidebar) {
                Button(L10n.t(de: "Alle Downloads", en: "All Downloads")) {
                    listViewModel.selectSidebarFilter(.allDownloads)
                }
                .appShortcut(.filterAllDownloads)

                Button(L10n.t(de: "Warteschlange", en: "Queue")) {
                    listViewModel.selectSidebarFilter(.queue)
                }
                .appShortcut(.filterQueue)

                Button(L10n.t(de: "Laufend", en: "Downloading")) {
                    listViewModel.selectSidebarFilter(.downloading)
                }
                .appShortcut(.filterDownloading)

                Button(L10n.t(de: "Pausiert", en: "Paused")) {
                    listViewModel.selectSidebarFilter(.paused)
                }
                .appShortcut(.filterPaused)

                Button(L10n.t(de: "Abgeschlossen", en: "Completed")) {
                    listViewModel.selectSidebarFilter(.completed)
                }
                .appShortcut(.filterCompleted)

                Button(L10n.t(de: "Fehlgeschlagen", en: "Failed")) {
                    listViewModel.selectSidebarFilter(.failed)
                }
                .appShortcut(.filterFailed)

                Button(L10n.t(de: "Geplant", en: "Scheduled")) {
                    listViewModel.selectSidebarFilter(.scheduled)
                }
                .appShortcut(.filterScheduled)
            }

            CommandGroup(after: .toolbar) {
                Button(L10n.t(de: "Verlauf", en: "History")) {
                    listViewModel.showHistory()
                }
                .appShortcut(.history)
                .disabled(!listViewModel.canUseMainShortcuts)

                Button(appSettings.inspectorCollapsed
                    ? L10n.t(de: "Inspector einblenden", en: "Show Inspector")
                    : L10n.t(de: "Inspector ausblenden", en: "Hide Inspector")) {
                    listViewModel.toggleInspector()
                }
                .appShortcut(.inspector)
                .disabled(!listViewModel.canUseMainShortcuts)
            }

            CommandGroup(replacing: .appSettings) {
                Button(L10n.t(de: "Einstellungen…", en: "Settings…")) {
                    SettingsNavigation.open()
                }
                .appShortcut(.settings)
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
