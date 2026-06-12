import SwiftUI
import UniformTypeIdentifiers

struct DownloadConfirmationView: View {
    @Bindable var item: DownloadItem
    @Bindable var viewModel: DownloadConfirmationViewModel
    let onConfirm: (DownloadConfirmationOptions) -> Void
    let onQueueLater: (DownloadConfirmationOptions) -> Void
    let onCancel: () -> Void
    let onShowDuplicate: (UUID) -> Void

    @FocusState private var focusedField: Field?
    @State private var isShowingFolderPicker = false

    private enum Field: Hashable {
        case fileName, url
    }

    init(
        item: DownloadItem,
        duplicateItem: DownloadItem?,
        folders: [DownloadFolder],
        onConfirm: @escaping (DownloadConfirmationOptions) -> Void,
        onQueueLater: @escaping (DownloadConfirmationOptions) -> Void,
        onCancel: @escaping () -> Void,
        onShowDuplicate: @escaping (UUID) -> Void
    ) {
        self.item = item
        self.viewModel = DownloadConfirmationViewModel(
            item: item,
            duplicateItem: duplicateItem,
            folders: folders
        )
        self.onConfirm = onConfirm
        self.onQueueLater = onQueueLater
        self.onCancel = onCancel
        self.onShowDuplicate = onShowDuplicate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            duplicateBanner
            contentDuplicateBanner
            conflictChoiceBanner
            compactFields
            metadataRow
            statusMessages
            destinationRow
            advancedSection
            actionButtons
        }
        .padding(AppTheme.dialogPadding)
        .frame(minWidth: 480, idealWidth: AppTheme.dialogWidth, maxWidth: 680)
        .interactiveDismissDisabled()
        .onAppear { focusedField = .fileName }
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.setDestination(url)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: FileTypeHelper.systemIcon(for: viewModel.editedFileName))
                .resizable()
                .frame(width: 32, height: 32)

            Text(L10n.t(de: "Download bestätigen", en: "Confirm Download"))
                .font(.headline)

            Spacer()

            Label(viewModel.sourceText, systemImage: viewModel.sourceIcon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(viewModel.sourceText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
    }

    // MARK: - Duplicate

    @ViewBuilder
    private var contentDuplicateBanner: some View {
        if let duplicate = viewModel.contentDuplicateItem {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)

                Text(L10n.t(
                    de: "Bereits vorhanden: \(duplicate.fileName) (\(ByteFormatter.format(duplicate.bytesTotal)))",
                    en: "Already exists: \(duplicate.fileName) (\(ByteFormatter.format(duplicate.bytesTotal)))"
                ))
                .font(.caption)
                .lineLimit(2)

                Spacer(minLength: 4)
            }
            .padding(8)
            .appGlassBanner(tint: .orange)
        }
    }

    @ViewBuilder
    private var duplicateBanner: some View {
        if let duplicate = viewModel.duplicateItem {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)

                Text(L10n.t(
                    de: "Bereits aktiv: \(duplicate.fileName)",
                    en: "Already active: \(duplicate.fileName)"
                ))
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(duplicate.fileName)

                Spacer(minLength: 4)

                Button(L10n.t(de: "Anzeigen", en: "Show")) { onShowDuplicate(duplicate.id) }
                    .controlSize(.small)
                Button(L10n.t(de: "Trotzdem", en: "Download Anyway")) { onConfirm(viewModel.buildOptions) }
                    .controlSize(.small)
            }
            .padding(8)
            .appGlassBanner(tint: .orange)
        }
    }

    // MARK: - Conflict choice

    @ViewBuilder
    private var conflictChoiceBanner: some View {
        if viewModel.needsConflictChoice {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)

                Text(L10n.t(
                    de: "„\(viewModel.editedFileName)“ existiert bereits.",
                    en: "\"\(viewModel.editedFileName)\" already exists."
                ))
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(viewModel.editedFileName)

                Spacer(minLength: 4)

                Button(L10n.t(de: "Überschreiben", en: "Overwrite")) {
                    viewModel.selectedConflictPolicy = .overwrite
                }
                .controlSize(.small)
                Button(L10n.t(de: "Umbenennen", en: "Rename")) {
                    viewModel.selectedConflictPolicy = .rename
                }
                .controlSize(.small)
            }
            .padding(8)
            .appGlassBanner(tint: .orange)
        }
    }

    // MARK: - Fields

    private var compactFields: some View {
        VStack(spacing: 8) {
            labeledRow(L10n.t(de: "Name", en: "Name")) {
                TextField(L10n.t(de: "Dateiname", en: "File name"), text: $viewModel.editedFileName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .fileName)
            }

            labeledRow("URL") {
                HStack(spacing: 6) {
                    TextField("https://…", text: $viewModel.editedURL)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .url)

                    Button { viewModel.reprobe() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isProbing)
                    .help(L10n.t(de: "Erneut prüfen", en: "Re-probe"))

                    Button { viewModel.copyURL() } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .help(L10n.t(de: "URL kopieren", en: "Copy URL"))
                }
            }
        }
    }

    private func labeledRow(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            content()
        }
    }

    // MARK: - Metadata

    private var metadataRow: some View {
        HStack(spacing: 6) {
            if viewModel.isProbing {
                ProgressView().controlSize(.small)
            }
            Text(viewModel.metadataSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var statusMessages: some View {
        if let error = viewModel.probeErrorText {
            Label(error, systemImage: "wifi.exclamationmark")
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(error)
        } else if let conflict = viewModel.conflictMessage {
            Label(conflict, systemImage: "doc.badge.plus")
                .font(.caption2)
                .foregroundStyle(.orange)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(conflict)
        }
    }

    // MARK: - Destination

    private var destinationRow: some View {
        HStack(spacing: 8) {
            Text(L10n.t(de: "Ziel", en: "Destination"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            Text(viewModel.destinationPath)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)

            Button(L10n.t(de: "Ändern…", en: "Change…")) { isShowingFolderPicker = true }
                .controlSize(.small)

            ForEach(viewModel.quickDestinations.prefix(3), id: \.path) { url in
                let name = url.lastPathComponent.isEmpty
                    ? L10n.t(de: "Downloads", en: "Downloads")
                    : url.lastPathComponent
                Button(name) { viewModel.setDestination(url) }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
    }

    // MARK: - Advanced (collapsed by default)

    private var advancedSection: some View {
        DisclosureGroup(L10n.t(de: "Erweitert", en: "Advanced"), isExpanded: $viewModel.showAdvanced) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.t(de: "Verbindungen", en: "Connections"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Picker("", selection: $viewModel.segmentsCount) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                    }
                    .labelsHidden()
                    .frame(width: 72)
                }

                compactPicker(L10n.t(de: "Kategorie", en: "Category"), selection: $viewModel.selectedCategory) {
                    Text(L10n.t(de: "Automatisch", en: "Automatic")).tag(Optional<LibraryCategory>.none)
                    ForEach(LibraryCategory.allCases) { cat in
                        Text(cat.displayName).tag(Optional(cat))
                    }
                }

                if !viewModel.folders.isEmpty {
                    compactPicker(L10n.t(de: "Ordner", en: "Folder"), selection: $viewModel.selectedFolder) {
                        Text(L10n.t(de: "Keiner", en: "None")).tag(Optional<DownloadFolder>.none)
                        ForEach(viewModel.folders) { folder in
                            Text(folder.name).tag(Optional(folder))
                        }
                    }
                }

                compactPicker(L10n.t(de: "Nach Download", en: "After Download"), selection: $viewModel.postDownloadAction) {
                    ForEach(PostDownloadAction.allCases, id: \.self) { action in
                        Text(action.displayName).tag(action)
                    }
                }

                if let domain = viewModel.domain {
                    compactPicker("Domain \(domain)", selection: $viewModel.domainPolicy) {
                        ForEach(DomainPolicy.allCases, id: \.self) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                }

                if viewModel.hasBrowserHeaders {
                    Toggle(L10n.t(de: "Browser-Session (Cookies)", en: "Browser Session (Cookies)"), isOn: $viewModel.useBrowserHeaders)
                        .font(.caption)
                }

                Toggle(L10n.t(de: "Zeitplan", en: "Schedule"), isOn: $viewModel.useSchedule)
                    .font(.caption)

                if viewModel.useSchedule {
                    DatePicker(
                        L10n.t(de: "Start", en: "Start"),
                        selection: Binding(
                            get: { viewModel.scheduleDate ?? Date().addingTimeInterval(3600) },
                            set: { viewModel.scheduleDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(.caption)
                }

                Toggle(L10n.t(de: "Nur bei WLAN/Ethernet", en: "Wi‑Fi/Ethernet only"), isOn: $viewModel.startWhenOnWiFi)
                    .font(.caption)
            }
            .padding(.top, 6)
        }
        .font(.caption)
    }

    private func compactPicker<S: Hashable, Content: View>(
        _ label: String,
        selection: Binding<S>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Picker("", selection: selection, content: content)
                .labelsHidden()
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(L10n.cancel, role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)

            Button(L10n.t(de: "Später", en: "Later")) {
                onQueueLater(viewModel.buildQueueOnlyOptions())
            }
            .keyboardShortcut("l", modifiers: [.command])

            Spacer(minLength: 0)

            Button(L10n.t(de: "Download starten", en: "Start Download")) {
                let options = viewModel.useSchedule
                    ? viewModel.buildScheduledOptions()
                    : viewModel.buildOptions
                onConfirm(options)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canSubmit)
        }
    }
}
