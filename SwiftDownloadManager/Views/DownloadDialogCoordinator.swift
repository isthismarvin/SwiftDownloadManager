import SwiftUI
import SwiftData
import AppKit

/// Presents confirmation and completion flows in a floating panel above other apps.
struct DownloadDialogCoordinator: ViewModifier {
    @Bindable var downloadManager: DownloadManager
    @Bindable var viewModel: DownloadListViewModel
    let downloads: [DownloadItem]
    let folders: [DownloadFolder]

    func body(content: Content) -> some View {
        content
            .onAppear(perform: refreshAll)
            .onChange(of: downloads.map(\.id)) { _, _ in refreshAll() }
            .onChange(of: completionQueueToken) { _, _ in
                viewModel.refreshCompletionDialog(from: downloads)
                presentActivePanelIfNeeded()
            }
            .onChange(of: viewModel.pendingConfirmation?.id) { _, _ in
                presentActivePanelIfNeeded()
            }
            .onChange(of: confirmationBatchToken) { _, _ in
                presentActivePanelIfNeeded()
            }
            .onChange(of: viewModel.pendingCompletion?.id) { _, _ in
                presentActivePanelIfNeeded()
            }
    }

    private var completionQueueToken: String {
        downloadManager.completionDialogQueue.map(\.uuidString).joined(separator: ",")
    }

    private var confirmationBatchToken: String {
        viewModel.pendingConfirmationBatch?.map(\.id.uuidString).joined(separator: ",") ?? ""
    }

    private func refreshAll() {
        viewModel.clearStaleDialogState(from: downloads)
        viewModel.refreshPendingConfirmation(from: downloads)
        viewModel.refreshCompletionDialog(from: downloads)
        presentActivePanelIfNeeded()
    }

    private func presentActivePanelIfNeeded() {
        if let batch = viewModel.pendingConfirmationBatch, batch.count >= 2 {
            showBatchConfirmationPanel(items: batch)
        } else if let item = viewModel.pendingConfirmation {
            showConfirmationPanel(for: item)
        } else if let item = viewModel.pendingCompletion {
            showCompletionPanel(for: item)
        } else {
            FloatingDialogPanel.dismiss()
        }
    }

    private func afterDialogDismissed() {
        viewModel.refreshPendingConfirmation(from: downloads)
        viewModel.refreshCompletionDialog(from: downloads)
        presentActivePanelIfNeeded()
    }

    private func showConfirmationPanel(for item: DownloadItem) {
        FloatingDialogPanel.present(
            title: L10n.t(de: "Download bestätigen", en: "Confirm Download"),
            content: {
                DownloadConfirmationView(
                    item: item,
                    duplicateItem: viewModel.pendingConfirmationDuplicate,
                    folders: folders,
                    onConfirm: { options in
                        FloatingDialogPanel.dismiss()
                        viewModel.confirmPendingDownload(options: options)
                        afterDialogDismissed()
                    },
                    onQueueLater: { options in
                        FloatingDialogPanel.dismiss()
                        viewModel.queuePendingDownloadLater(options: options)
                        afterDialogDismissed()
                    },
                    onCancel: {
                        FloatingDialogPanel.dismiss()
                        viewModel.rejectPendingDownload()
                        afterDialogDismissed()
                    },
                    onShowDuplicate: { duplicateID in
                        FloatingDialogPanel.dismiss()
                        viewModel.showDuplicateDownload(id: duplicateID)
                        afterDialogDismissed()
                    }
                )
            },
            onUserClose: {
                viewModel.rejectPendingDownload()
                afterDialogDismissed()
            },
            size: NSSize(width: 700, height: 560)
        )
    }

    private func showBatchConfirmationPanel(items: [DownloadItem]) {
        FloatingDialogPanel.present(
            title: L10n.t(de: "Downloads bestätigen", en: "Confirm Downloads"),
            content: {
                BatchDownloadConfirmationView(
                    items: items,
                    onConfirm: { ids, startImmediately in
                        FloatingDialogPanel.dismiss()
                        viewModel.confirmPendingBatch(
                            ids: ids,
                            startImmediately: startImmediately,
                            from: downloads
                        )
                        afterDialogDismissed()
                    },
                    onCancel: {
                        FloatingDialogPanel.dismiss()
                        viewModel.rejectPendingBatch(from: downloads)
                        afterDialogDismissed()
                    }
                )
            },
            onUserClose: {
                viewModel.rejectPendingBatch(from: downloads)
                afterDialogDismissed()
            },
            size: NSSize(width: 560, height: 440)
        )
    }

    private func showCompletionPanel(for item: DownloadItem) {
        FloatingDialogPanel.present(
            title: L10n.t(de: "Download abgeschlossen", en: "Download Complete"),
            content: {
                DownloadCompletionView(
                    item: item,
                    onDismiss: {
                        FloatingDialogPanel.dismiss()
                        viewModel.dismissCompletionDialog()
                        afterDialogDismissed()
                    },
                    onShowInApp: {
                        FloatingDialogPanel.dismiss()
                        viewModel.showCompletedDownloadInApp(id: item.id)
                        afterDialogDismissed()
                    }
                )
            },
            onUserClose: {
                viewModel.dismissCompletionDialog()
                afterDialogDismissed()
            },
            size: NSSize(width: 660, height: 320)
        )
    }
}

extension View {
    func downloadDialogCoordinator(
        downloadManager: DownloadManager,
        viewModel: DownloadListViewModel,
        downloads: [DownloadItem],
        folders: [DownloadFolder]
    ) -> some View {
        modifier(DownloadDialogCoordinator(
            downloadManager: downloadManager,
            viewModel: viewModel,
            downloads: downloads,
            folders: folders
        ))
    }
}
