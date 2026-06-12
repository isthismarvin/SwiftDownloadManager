import SwiftUI

struct SidebarBottomBar: View {
    @Bindable var viewModel: DownloadListViewModel
    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 0) {
                SidebarBarIconButton(
                    systemName: "gearshape",
                    help: L10n.t(de: "Einstellungen", en: "Settings"),
                    accessibilityLabel: L10n.t(de: "Einstellungen", en: "Settings")
                ) {
                    viewModel.presentSettings()
                }
                .frame(maxWidth: .infinity)

                SidebarBarIconButton(
                    systemName: "clock",
                    help: L10n.t(de: "Verlauf", en: "History"),
                    accessibilityLabel: L10n.t(de: "Verlauf", en: "History")
                ) {
                    viewModel.isShowingHistorySheet = true
                }
                .frame(maxWidth: .infinity)

                SidebarBarIconButton(
                    systemName: appSettings.defaultSaveDirectoryBookmark == nil ? "folder" : "folder.fill",
                    help: downloadsFolderHelp,
                    accessibilityLabel: L10n.t(de: "Downloads-Ordner im Finder öffnen", en: "Open downloads folder in Finder")
                ) {
                    FinderHelper.openDefaultSaveDirectory()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appGlassCapsule(interactive: false)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private var downloadsFolderHelp: String {
        L10n.t(
            de: "Downloads-Ordner im Finder öffnen:\n\(appSettings.defaultSaveDirectoryPath)",
            en: "Open downloads folder in Finder:\n\(appSettings.defaultSaveDirectoryPath)"
        )
    }
}

private struct SidebarBarIcon: View {
    let systemName: String
    var color: Color = .secondary

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
    }
}

private struct SidebarBarIconButton: View {
    let systemName: String
    var color: Color = .secondary
    let help: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SidebarBarIcon(systemName: systemName, color: color)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(accessibilityLabel)
    }
}
