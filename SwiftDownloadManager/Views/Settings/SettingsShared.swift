import SwiftUI

extension View {
    @ViewBuilder
    func settingsHelp(_ text: String?) -> some View {
        if let text, !text.isEmpty {
            self.help(text)
        } else {
            self
        }
    }
}

enum SettingsShared {
    static let sidebarWidth: CGFloat = 192
    static let panelMinWidth: CGFloat = 390
    static let controlMinWidth: CGFloat = 148
    static let windowMinWidth: CGFloat = 676
    static let windowMinHeight: CGFloat = 468
    static let windowIdealWidth: CGFloat = 702
    static let windowIdealHeight: CGFloat = 494
}

enum SettingsPanelLayout {
    case standard
    case about
}

struct SettingsPanelContainer<Content: View>: View {
    let title: String
    var layout: SettingsPanelLayout = .standard
    @ViewBuilder var content: () -> Content

    init(
        _ title: String,
        layout: SettingsPanelLayout = .standard,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.layout = layout
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                content()
                    .frame(maxWidth: .infinity, alignment: layout == .about ? .center : .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: SettingsShared.panelMinWidth, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingsPanelSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsControlRow<Label: View, Control: View>: View {
    var alignment: VerticalAlignment = .center
    @ViewBuilder var label: () -> Label
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: alignment, spacing: 12) {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)

            control()
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: min(120, SettingsShared.controlMinWidth), alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

