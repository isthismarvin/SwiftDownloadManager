import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var appSettings = AppSettings.shared

    private let initialSection: SettingsSection?
    @State private var selection: SettingsSection?

    init(initialSection: SettingsSection? = nil) {
        self.initialSection = initialSection
        _selection = State(initialValue: initialSection ?? .general)
    }

    var body: some View {
        let _ = appSettings.appLanguage
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                List(selection: $selection) {
                    Section {
                        ForEach(SettingsSection.allCases.filter { $0 != .about }) { section in
                            sidebarRow(for: section)
                        }
                    }

                    Section {
                        sidebarRow(for: .about)
                    }
                }
                .listStyle(.sidebar)
                .controlSize(.small)
                .frame(width: SettingsShared.sidebarWidth)

                Divider()

                detailPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            HStack {
                Spacer()
                Button(L10n.t(de: "Fertig", en: "Done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .controlSize(.small)
        .frame(
            minWidth: SettingsShared.windowMinWidth,
            idealWidth: SettingsShared.windowIdealWidth,
            minHeight: SettingsShared.windowMinHeight,
            idealHeight: SettingsShared.windowIdealHeight
        )
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsSection)) { notification in
            guard let section = notification.object as? SettingsSection else { return }
            selection = section
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        switch selection ?? .general {
        case .general:
            GeneralSettingsPanel()
        case .downloads:
            DownloadsSettingsPanel()
        case .network:
            NetworkSettingsPanel()
        case .integration:
            IntegrationSettingsPanel()
        case .intelligence:
            IntelligenceSettingsPanel()
        case .notifications:
            NotificationsSettingsPanel()
        case .advanced:
            AdvancedSettingsPanel()
        case .about:
            AboutSettingsPanel()
        }
    }

    private func sidebarRow(for section: SettingsSection) -> some View {
        Label(section.title, systemImage: section.symbol)
            .font(.callout)
            .tag(section)
            .help(section.help)
    }
}
