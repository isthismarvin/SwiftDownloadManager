import SwiftUI

struct SelectionActionBar: View {
    @Bindable var viewModel: DownloadListViewModel
    let downloads: [DownloadItem]
    @Namespace private var actionGlassNamespace

    private var selectedItems: [DownloadItem] {
        downloads.filter { viewModel.selectedDownloadIDs.contains($0.id) }
    }

    private var canResumeAny: Bool {
        selectedItems.contains { DownloadRowViewModel(item: $0).canResume }
    }

    private var canPauseAny: Bool {
        selectedItems.contains { DownloadRowViewModel(item: $0).canPause }
    }

    private var canCancelAny: Bool {
        selectedItems.contains { DownloadRowViewModel(item: $0).canCancel }
    }

    private var hasActions: Bool {
        canResumeAny || canPauseAny || canCancelAny
    }

    private var actionLayoutSignature: String {
        [
            canResumeAny ? "r" : "",
            canPauseAny ? "p" : "",
            canCancelAny ? "c" : "",
        ].joined()
    }

    var body: some View {
        if hasActions {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 6) {
                    if canResumeAny {
                        morphingActionButton(
                            id: "resume",
                            icon: "play.fill",
                            label: L10n.t(de: "Fortsetzen", en: "Resume"),
                            action: { viewModel.resumeAllSelected(from: downloads) }
                        )
                    }

                    if canPauseAny {
                        morphingActionButton(
                            id: "pause",
                            icon: "pause.fill",
                            label: L10n.t(de: "Pausieren", en: "Pause"),
                            action: { viewModel.pauseAllSelected(from: downloads) }
                        )
                    }

                    if canCancelAny {
                        morphingActionButton(
                            id: "cancel",
                            icon: "stop.fill",
                            label: L10n.t(de: "Abbrechen", en: "Cancel"),
                            action: { viewModel.cancelAllSelected(from: downloads) }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .animation(.snappy(duration: 0.25), value: actionLayoutSignature)
            .accessibilityElement(children: .contain)
        }
    }

    private func morphingActionButton(
        id: String,
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .appGlassChip(interactive: true)
        .glassEffectID("selection-\(id)", in: actionGlassNamespace)
        .help(label)
        .accessibilityLabel(label)
    }
}
