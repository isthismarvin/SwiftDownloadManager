import SwiftUI

struct BatchDownloadConfirmationView: View {
    let items: [DownloadItem]
    @State private var selectedIDs: Set<UUID>
    let onConfirm: (_ ids: [UUID], _ startImmediately: Bool) -> Void
    let onCancel: () -> Void

    init(
        items: [DownloadItem],
        onConfirm: @escaping (_ ids: [UUID], _ startImmediately: Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.items = items
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _selectedIDs = State(initialValue: Set(items.map(\.id)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.contentPadding) {
            Text(L10n.t(de: "Mehrere Downloads bestätigen", en: "Confirm Multiple Downloads"))
                .font(.headline)

            Text(L10n.t(
                de: "\(items.count) Downloads warten auf Bestätigung.",
                en: "\(items.count) downloads are awaiting confirmation."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        HStack(spacing: AppTheme.itemSpacing) {
                            Toggle(isOn: binding(for: item.id)) {
                                HStack(spacing: AppTheme.itemSpacing) {
                                    Image(nsImage: FileTypeHelper.systemIcon(for: item.fileName))
                                        .resizable()
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.fileName)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                        Text(item.bytesTotal > 0
                                            ? ByteFormatter.format(item.bytesTotal)
                                            : L10n.t(de: "Größe unbekannt", en: "Size unknown"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                        .padding(.vertical, 6)

                        if item.id != items.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 220)

            HStack {
                Button(L10n.t(de: "Alle", en: "All")) { selectedIDs = Set(items.map(\.id)) }
                Button(L10n.t(de: "Keine", en: "None")) { selectedIDs.removeAll() }
                Spacer()
                Text(L10n.t(de: "\(selectedIDs.count) ausgewählt", en: "\(selectedIDs.count) selected"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(L10n.cancel, role: .cancel, action: onCancel)
                Spacer()
                Button(L10n.t(de: "In Warteschlange", en: "Queue")) {
                    onConfirm(Array(selectedIDs), false)
                }
                .disabled(selectedIDs.isEmpty)
                Button(L10n.t(de: "Starten", en: "Start")) {
                    onConfirm(Array(selectedIDs), true)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIDs.isEmpty)
            }
        }
        .padding(AppTheme.dialogPadding)
        .frame(width: 520, height: 400)
        .interactiveDismissDisabled()
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.contains(id) },
            set: { isOn in
                if isOn {
                    selectedIDs.insert(id)
                } else {
                    selectedIDs.remove(id)
                }
            }
        )
    }
}
