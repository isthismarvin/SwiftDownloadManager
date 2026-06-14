import SwiftUI

/// Vertical divider between toolbar sections — used only in the brand pill (name | speed).
struct ToolbarSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(.separator)
            .frame(width: 1, height: 16)
    }
}

struct ToolbarBrandSpeedGroup: View {
    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                AppBrandHeader(
                    iconSize: 24,
                    titleFont: .subheadline.weight(.semibold),
                    leadingPadding: 8,
                    trailingPadding: 0,
                    spacing: 8
                )

                ToolbarSectionDivider()

                ToolbarAggregateSpeedView(showsBackground: false)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

struct ToolbarAggregateSpeedView: View {
    var showsBackground = true
    @Bindable private var downloadManager = DownloadManager.shared

    private var displaySpeed: String {
        downloadManager.aggregateDisplaySpeed > 0
            ? TimeFormatter.formatSpeed(downloadManager.aggregateDisplaySpeed)
            : "0 MB/s"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(downloadManager.aggregateDisplaySpeed > 0 ? .green : .secondary)

            Text(displaySpeed)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(downloadManager.aggregateDisplaySpeed > 0 ? .primary : .secondary)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.35), value: displaySpeed)
        }
        .padding(.horizontal, showsBackground ? 10 : 4)
        .padding(.vertical, 4)
        .modifier(ToolbarSpeedBackground(showsBackground: showsBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t(de: "Gesamtgeschwindigkeit", en: "Total speed"))
        .accessibilityValue(displaySpeed)
        .help(L10n.t(
            de: "Summe aller aktiven Download-Geschwindigkeiten",
            en: "Combined speed of all active downloads"
        ))
    }
}

private struct ToolbarSpeedBackground: ViewModifier {
    let showsBackground: Bool

    func body(content: Content) -> some View {
        if showsBackground {
            content.appGlassChip()
        } else {
            content
        }
    }
}

struct ToolbarSpeedLimitPopover: View {
    @Bindable private var appSettings = AppSettings.shared
    @State private var isPresented = false

    private var speedLimitHelp: String {
        let limit = appSettings.effectiveSpeedLimitBytesPerSecond
        if limit > 0 {
            return L10n.t(
                de: "Speed-Limit: \(TimeFormatter.formatSpeed(Double(limit)))",
                en: "Speed limit: \(TimeFormatter.formatSpeed(Double(limit)))"
            )
        }
        return L10n.t(de: "Kein Speed-Limit", en: "No speed limit")
    }

    private var isSpeedLimitActive: Bool {
        appSettings.effectiveSpeedLimitBytesPerSecond > 0
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            AppToolbarIcon(
                systemName: speedLimitIcon,
                foregroundStyle: isSpeedLimitActive
                    ? AnyShapeStyle(.orange)
                    : AnyShapeStyle(.primary)
            )
        }
        .help(speedLimitHelp)
        .accessibilityLabel(L10n.t(de: "Speed-Limit", en: "Speed limit"))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ToolbarSpeedLimitPopoverContent()
                .frame(width: 300)
                .padding(14)
        }
    }

    private var speedLimitIcon: String {
        isSpeedLimitActive
            ? "gauge.with.dots.needle.33percent"
            : "gauge.with.dots.needle.100percent"
    }
}

private struct ToolbarSpeedLimitPopoverContent: View {
    @Bindable private var appSettings = AppSettings.shared

    private static var presets: [(label: String, value: Int64, help: String)] {
        [
            ("∞", 0, L10n.t(de: "Keine Begrenzung", en: "No limit")),
            ("500K", 500_000, L10n.t(de: "500 KB/s", en: "500 KB/s")),
            ("1M", 1_000_000, L10n.t(de: "1 MB/s", en: "1 MB/s")),
            ("2M", 2_000_000, L10n.t(de: "2 MB/s", en: "2 MB/s")),
            ("5M", 5_000_000, L10n.t(de: "5 MB/s", en: "5 MB/s")),
        ]
    }

    private var customSpeedMB: Binding<Double> {
        Binding(
            get: { Double(appSettings.customSpeedLimitBytesPerSecond) / 1_000_000 },
            set: { appSettings.customSpeedLimitBytesPerSecond = Int64($0 * 1_000_000) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t(de: "Globales Speed-Limit", en: "Global speed limit"))
                .font(.subheadline.weight(.semibold))

            if !appSettings.useCustomSpeedLimit {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(Self.presets, id: \.value) { preset in
                            presetButton(preset)
                        }
                    }
                }
            }

            Toggle(isOn: $appSettings.useCustomSpeedLimit) {
                Text(L10n.t(de: "Benutzerdefiniert", en: "Custom"))
                    .font(.caption)
            }
            .toggleStyle(.switch)

            if appSettings.useCustomSpeedLimit {
                HStack(spacing: 10) {
                    Slider(value: customSpeedMB, in: 0.1...50, step: 0.1)
                    Text(String(format: "%.1f MB/s", customSpeedMB.wrappedValue))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                }
            }

            if appSettings.effectiveSpeedLimitBytesPerSecond > 0 {
                Text(L10n.t(
                    de: "Aktiv: \(TimeFormatter.formatSpeed(Double(appSettings.effectiveSpeedLimitBytesPerSecond)))",
                    en: "Active: \(TimeFormatter.formatSpeed(Double(appSettings.effectiveSpeedLimitBytesPerSecond)))"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(L10n.t(de: "Keine Geschwindigkeitsbegrenzung", en: "No speed limit"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(L10n.t(de: "Netzwerk-Einstellungen…", en: "Network Settings…")) {
                SettingsNavigation.open(to: .network)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func presetButton(_ preset: (label: String, value: Int64, help: String)) -> some View {
        let isSelected = !appSettings.useCustomSpeedLimit
            && appSettings.globalSpeedLimitBytesPerSecond == preset.value

        return Button {
            appSettings.useCustomSpeedLimit = false
            appSettings.globalSpeedLimitBytesPerSecond = preset.value
        } label: {
            Text(preset.label)
                .font(.caption.weight(.medium).monospacedDigit())
                .frame(minWidth: 32)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .appGlassRounded(isSelected: isSelected)
        .help(preset.help)
    }
}
