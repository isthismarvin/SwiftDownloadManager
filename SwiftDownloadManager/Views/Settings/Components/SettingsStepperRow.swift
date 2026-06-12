import SwiftUI

struct SettingsStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var unit: String = ""
    var help: String? = nil

    var body: some View {
        SettingsControlRow(alignment: .firstTextBaseline) {
            Text(label)
                .lineLimit(2)
        } control: {
            HStack(spacing: 8) {
                Text(displayValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
        .settingsHelp(help)
    }

    private var displayValue: String {
        unit.isEmpty ? "\(value)" : "\(value) \(unit)"
    }
}
