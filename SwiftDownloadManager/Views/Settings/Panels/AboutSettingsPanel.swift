import SwiftUI

struct AboutSettingsPanel: View {
    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Über", en: "About"), layout: .about) {
            AboutAppHero()
                .frame(maxWidth: 380)
                .frame(maxWidth: .infinity)
        }
    }
}
