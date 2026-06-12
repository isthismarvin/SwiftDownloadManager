import SwiftUI

struct TableColumnOrderSettingsSection: View {
    @Bindable private var appSettings = AppSettings.shared

    private var columns: [DownloadTableColumn] {
        DownloadTableColumn.normalizedOrder(
            appSettings.tableColumnOrder.compactMap(DownloadTableColumn.init(rawValue:))
        ).filter(\.isReorderable)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t(de: "Spaltenreihenfolge", en: "Column order"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                    columnRow(column, index: index, total: columns.count)
                }
            }

            Button(L10n.t(de: "Standard wiederherstellen", en: "Restore defaults")) {
                appSettings.resetTableColumnOrder()
            }
            .buttonStyle(.link)
            .font(.caption)
            .help(L10n.t(
                de: "Setzt die Spaltenreihenfolge auf Datum, Fortschritt, Geschwindigkeit, Status, Größe, Verbleibend zurück.",
                en: "Resets column order to date, progress, speed, status, size, remaining."
            ))
        }
        .settingsHelp(L10n.t(
            de: "Die Namensspalte bleibt links fixiert. In der Tabelle kannst du Spalten auch per Drag & Drop umsortieren.",
            en: "The name column stays fixed on the left. You can also reorder columns by drag and drop in the table."
        ))
    }

    private func columnRow(_ column: DownloadTableColumn, index: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: column.icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(column.title)
                .font(.callout)

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                moveButton(
                    systemName: "chevron.up",
                    enabled: index > 0,
                    help: L10n.t(de: "Nach oben", en: "Move up")
                ) {
                    appSettings.moveTableColumn(column, direction: -1)
                }

                moveButton(
                    systemName: "chevron.down",
                    enabled: index < total - 1,
                    help: L10n.t(de: "Nach unten", en: "Move down")
                ) {
                    appSettings.moveTableColumn(column, direction: 1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
    }

    private func moveButton(
        systemName: String,
        enabled: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? .secondary : .tertiary)
        .disabled(!enabled)
        .help(help)
    }
}
