import SwiftUI

struct SegmentCountBySizeSettingsSection: View {
    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsToggleRow(
                title: L10n.t(de: "Verbindungen nach Dateigröße", en: "Connections by file size"),
                systemImage: "square.split.2x2",
                isOn: $appSettings.sizeBasedSegmentCountEnabled,
                help: L10n.t(
                    de: "Legt die Anzahl paralleler Verbindungen anhand der Dateigröße fest. SegmentPlanner begrenzt zusätzlich nach Mindestsegmentgröße.",
                    en: "Sets the number of parallel connections based on file size. SegmentPlanner also caps by minimum segment size."
                )
            )

            if appSettings.sizeBasedSegmentCountEnabled {
                tierHeader

                ForEach(Array(appSettings.segmentCountTiers.enumerated()), id: \.element.id) { index, tier in
                    tierRow(index: index, tier: tier)
                    if index < appSettings.segmentCountTiers.count - 1 {
                        Divider()
                    }
                }

                tierActions
            }
        }
    }

    private var tierHeader: some View {
        HStack(spacing: 12) {
            Text(L10n.t(de: "Dateigröße", en: "File size"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(L10n.t(de: "Verbindungen", en: "Connections"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.top, 4)
    }

    private func tierRow(index: Int, tier: SegmentCountTier) -> some View {
        SettingsControlRow(alignment: .firstTextBaseline) {
            if tier.isCatchAll {
                Text(L10n.t(de: "Größere Dateien", en: "Larger files"))
                    .font(.callout)
            } else {
                HStack(spacing: 6) {
                    Text(L10n.t(de: "Bis", en: "Up to"))
                        .foregroundStyle(.secondary)
                    Stepper("", value: sizeBinding(for: tier.id), in: 1...51_200, step: sizeStep(for: tier.maxSizeMB))
                        .labelsHidden()
                    Text("\(tier.maxSizeMB) MB")
                        .monospacedDigit()
                }
                .font(.callout)
            }
        } control: {
            HStack(spacing: 8) {
                Text("\(tier.connections)×")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Stepper("", value: connectionsBinding(for: tier.id), in: 1...8)
                    .labelsHidden()
            }
        }
    }

    private var tierActions: some View {
        HStack(spacing: 12) {
            Button(L10n.t(de: "Stufe hinzufügen", en: "Add tier")) {
                appSettings.addSegmentCountTier()
            }
            .disabled(!appSettings.canAddSegmentCountTier)

            Button(L10n.t(de: "Letzte Stufe entfernen", en: "Remove last tier")) {
                appSettings.removeLastBoundedSegmentCountTier()
            }
            .disabled(!appSettings.canRemoveSegmentCountTier)
        }
        .buttonStyle(.link)
        .font(.caption)
        .padding(.top, 2)
    }

    private func sizeBinding(for id: UUID) -> Binding<Int> {
        Binding(
            get: {
                appSettings.segmentCountTiers.first(where: { $0.id == id })?.maxSizeMB ?? 1
            },
            set: { newValue in
                appSettings.updateSegmentCountTier(id: id, maxSizeMB: max(1, newValue))
            }
        )
    }

    private func connectionsBinding(for id: UUID) -> Binding<Int> {
        Binding(
            get: {
                appSettings.segmentCountTiers.first(where: { $0.id == id })?.connections ?? 1
            },
            set: { newValue in
                appSettings.updateSegmentCountTier(id: id, connections: newValue)
            }
        )
    }

    private func sizeStep(for currentMB: Int) -> Int {
        if currentMB < 20 { return 1 }
        if currentMB < 200 { return 5 }
        if currentMB < 2_000 { return 50 }
        return 256
    }
}
