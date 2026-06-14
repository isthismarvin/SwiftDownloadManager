import SwiftUI

struct SpeedLimitControl: View {
    @Bindable var appSettings: AppSettings

    private static var presets: [(label: String, value: Int64, help: String)] {
        [
            ("∞", 0, L10n.t(
                de: "Keine Begrenzung — Downloads nutzen die volle verfügbare Bandbreite.",
                en: "No limit — downloads use the full available bandwidth."
            )),
            ("500K", 500_000, L10n.t(
                de: "Begrenzt alle Downloads zusammen auf 500 KB/s.",
                en: "Limits all downloads combined to 500 KB/s."
            )),
            ("1M", 1_000_000, L10n.t(
                de: "Begrenzt alle Downloads zusammen auf 1 MB/s.",
                en: "Limits all downloads combined to 1 MB/s."
            )),
            ("2M", 2_000_000, L10n.t(
                de: "Begrenzt alle Downloads zusammen auf 2 MB/s.",
                en: "Limits all downloads combined to 2 MB/s."
            )),
            ("5M", 5_000_000, L10n.t(
                de: "Begrenzt alle Downloads zusammen auf 5 MB/s.",
                en: "Limits all downloads combined to 5 MB/s."
            )),
        ]
    }

    private var customSpeedMB: Binding<Double> {
        Binding(
            get: { Double(appSettings.customSpeedLimitBytesPerSecond) / 1_000_000 },
            set: { appSettings.customSpeedLimitBytesPerSecond = Int64($0 * 1_000_000) }
        )
    }

    private var effectiveLimit: Int64 {
        appSettings.effectiveSpeedLimitBytesPerSecond
    }

    var body: some View {
        SettingsRoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t(de: "Globales Speed-Limit", en: "Global speed limit"))
                    .font(.subheadline.weight(.medium))
                    .settingsHelp(L10n.t(
                        de: "Gilt für alle gleichzeitig laufenden Downloads zusammen.",
                        en: "Applies to all concurrently running downloads combined."
                    ))

                if !appSettings.useCustomSpeedLimit {
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            Spacer(minLength: 0)
                            ForEach(Self.presets, id: \.value) { preset in
                                presetButton(preset)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                SettingsControlRow(alignment: .firstTextBaseline) {
                    Text(L10n.t(de: "Benutzerdefiniert", en: "Custom"))
                        .font(.caption)
                        .settingsHelp(L10n.t(
                            de: "Eigene Geschwindigkeit per Schieberegler statt der Presets.",
                            en: "Custom speed via slider instead of presets."
                        ))
                } control: {
                    Toggle("", isOn: $appSettings.useCustomSpeedLimit)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if appSettings.useCustomSpeedLimit {
                    SettingsControlRow(alignment: .center) {
                        Text(L10n.t(de: "Limit", en: "Limit"))
                            .font(.caption)
                            .settingsHelp(L10n.t(
                                de: "Maximale Gesamtgeschwindigkeit aller aktiven Downloads.",
                                en: "Maximum combined speed of all active downloads."
                            ))
                    } control: {
                        HStack(spacing: 10) {
                            Slider(value: customSpeedMB, in: 0.1...50, step: 0.1)
                            Text(String(format: "%.1f MB/s", customSpeedMB.wrappedValue))
                                .font(.caption.monospacedDigit())
                                .frame(width: 72, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if effectiveLimit > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "gauge.with.dots.needle.33percent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(speedHint(bytesPerSecond: effectiveLimit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .settingsHelp(L10n.t(
                        de: "Geschätzte Dauer für eine 100-MB-Datei bei diesem Limit.",
                        en: "Estimated duration for a 100 MB file at this limit."
                    ))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "gauge.with.dots.needle.100percent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(L10n.t(de: "Keine Geschwindigkeitsbegrenzung", en: "No speed limit"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .settingsPanelStack()
    }

    private func presetButton(_ preset: (label: String, value: Int64, help: String)) -> some View {
        let isSelected = appSettings.globalSpeedLimitBytesPerSecond == preset.value
        return Button {
            appSettings.globalSpeedLimitBytesPerSecond = preset.value
        } label: {
            Text(preset.label)
                .font(.caption.weight(.medium).monospacedDigit())
                .frame(minWidth: 36)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .appGlassRounded(isSelected: isSelected)
        .settingsHelp(preset.help)
    }

    private func speedHint(bytesPerSecond: Int64) -> String {
        let rate = Double(bytesPerSecond)
        let secondsFor100MB = (100 * 1_000_000) / rate
        let minutes = Int(secondsFor100MB) / 60
        let seconds = Int(secondsFor100MB) % 60
        if minutes > 0 {
            return L10n.t(
                de: "≈ \(minutes) Min \(seconds) s für 100 MB",
                en: "≈ \(minutes) min \(seconds) s for 100 MB"
            )
        }
        return L10n.t(de: "≈ \(seconds) s für 100 MB", en: "≈ \(seconds) s for 100 MB")
    }
}
