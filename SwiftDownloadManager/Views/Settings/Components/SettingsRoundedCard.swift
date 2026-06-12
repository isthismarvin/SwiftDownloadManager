import SwiftUI

struct SettingsRoundedCard<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .appGlassCard()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func settingsRoundedCard(padding: CGFloat = 12) -> some View {
        SettingsRoundedCard(padding: padding) { self }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func settingsPanelStack() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}
