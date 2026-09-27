import SwiftUI

struct SelectionActionBar: View {
    @Bindable var viewModel: DownloadListViewModel
    let downloads: [DownloadItem]
    @Namespace private var actionGlassNamespace

    private struct Actions {
        var canResume = false
        var canPause = false
        var canCancel = false
        var hasActions: Bool { canResume || canPause || canCancel }
        var signature: String {
            [canResume ? "r" : "", canPause ? "p" : "", canCancel ? "c" : ""].joined()
        }
    }

    private var actions: Actions {
        guard !viewModel.selectedDownloadIDs.isEmpty else { return Actions() }
        var result = Actions()
        for item in downloads where viewModel.selectedDownloadIDs.contains(item.id) {
            let row = DownloadRowViewModel(item: item)
            if row.canResume { result.canResume = true }
            if row.canPause { result.canPause = true }
            if row.canCancel { result.canCancel = true }
            if result.canResume && result.canPause && result.canCancel {
                break
            }
        }
        return result
    }

    var body: some View {
        let acts = actions
        if acts.hasActions {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 6) {
                    if acts.canResume {
                        morphingActionButton(
                            id: "resume",
                            icon: "play.fill",
                            label: L10n.t(de: "Fortsetzen", en: "Resume"),
                            action: { viewModel.resumeAllSelected(from: downloads) }
                        )
                    }

                    if acts.canPause {
                        morphingActionButton(
                            id: "pause",
                            icon: "pause.fill",
                            label: L10n.t(de: "Pausieren", en: "Pause"),
                            action: { viewModel.pauseAllSelected(from: downloads) }
                        )
                    }

                    if acts.canCancel {
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
            .animation(.snappy(duration: 0.25), value: acts.signature)
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
