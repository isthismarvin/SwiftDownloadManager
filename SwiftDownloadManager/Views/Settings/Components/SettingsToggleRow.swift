import SwiftUI

struct SettingsToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    var subtitle: String? = nil
    var help: String? = nil

    var body: some View {
        SettingsControlRow(alignment: .firstTextBaseline) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .lineLimit(2)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
        } control: {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .settingsHelp(help)
    }
}
