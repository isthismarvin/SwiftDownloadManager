import SwiftUI
import UniformTypeIdentifiers

enum AddDownloadMode: String, CaseIterable, Identifiable {
    case single
    case batch

    var id: String { rawValue }
    var title: String {
        switch self {
        case .single: return L10n.t(de: "Einzelner Download", en: "Single Download")
        case .batch: return L10n.t(de: "Stapel / Muster [01-20]", en: "Batch / Pattern [01-20]")
        }
    }
}

struct AddDownloadView: View {
    @Bindable var viewModel: DownloadListViewModel
    let folders: [DownloadFolder]

    @State private var mode: AddDownloadMode = .single

    // Single mode state
    @State private var urlString = ""
    @State private var fileNameOverride = ""

    // Batch mode state
    @State private var batchText = ""
    @State private var batchItems: [BatchURLItem] = []

    // Shared state
    @State private var segmentsCount = 4
    @State private var selectedCategory: LibraryCategory?
    @State private var selectedFolder: DownloadFolder?
    @State private var saveDirectory: URL?
    @State private var showAdvanced = false
    @State private var isShowingFolderPicker = false
    @State private var isSubmitting = false

    private var saveDirectoryDisplay: String {
        if let saveDirectory {
            return saveDirectory.path
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"
    }

    private var selectedBatchCount: Int {
        batchItems.filter(\.isSelected).count
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.t(de: "Download hinzufügen", en: "Add Download"))
                    .font(.headline)
                Spacer()
                Picker("", selection: $mode) {
                    ForEach(AddDownloadMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }

            if mode == .single {
                singleDownloadContent
            } else {
                batchDownloadContent
            }

            // Shared Destination and Folder
            VStack(spacing: 10) {
                HStack {
                    Text(L10n.t(de: "Speichern unter:", en: "Save to:"))
                        .foregroundStyle(.secondary)
                    Text(saveDirectoryDisplay)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(L10n.t(de: "Wählen…", en: "Choose…")) {
                        isShowingFolderPicker = true
                    }
                }

                HStack {
                    Picker(L10n.t(de: "Kategorie:", en: "Category:"), selection: $selectedCategory) {
                        Text(L10n.t(de: "Automatisch", en: "Automatic")).tag(Optional<LibraryCategory>.none)
                        ForEach(LibraryCategory.allCases) { category in
                            Text(category.displayName).tag(Optional(category))
                        }
                    }

                    if !folders.isEmpty {
                        Picker(L10n.t(de: "Ordner:", en: "Folder:"), selection: $selectedFolder) {
                            Text(L10n.t(de: "Keiner", en: "None")).tag(Optional<DownloadFolder>.none)
                            ForEach(folders) { folder in
                                Text(folder.name).tag(Optional(folder))
                            }
                        }
                    }
                }
            }

            DisclosureGroup(L10n.t(de: "Erweitert", en: "Advanced"), isExpanded: $showAdvanced) {
                HStack {
                    Text(L10n.t(de: "Parallele Verbindungen:", en: "Parallel connections:"))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $segmentsCount) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("4").tag(4)
                        Text("8").tag(8)
                    }
                    .frame(width: 80)
                    Spacer()
                }
                .padding(.top, 4)
            }

            if let error = viewModel.addError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Footer action buttons
            footerButtons
        }
        .padding(20)
        .frame(minWidth: 460, idealWidth: 540, maxWidth: 640)
        .onAppear {
            segmentsCount = AppSettings.shared.defaultSegmentsCount
        }
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                saveDirectory = url
            }
        }
    }

    // MARK: - Single Mode Content

    private var singleDownloadContent: some View {
        VStack(spacing: 12) {
            TextField(L10n.t(de: "Download-URL (https://…)", en: "Download URL (https://…)"), text: $urlString)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            TextField(L10n.t(de: "Dateiname (optional)", en: "File name (optional)"), text: $fileNameOverride)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Batch Mode Content

    private var batchDownloadContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t(
                de: "Muster (z.B. https://site.com/file_[01-10].zip) oder mehrere URLs einfügen:",
                en: "Enter a pattern (e.g. https://site.com/file_[01-10].zip) or paste URLs:"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            TextEditor(text: $batchText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 70)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                .onChange(of: batchText) { _, newText in
                    batchItems = BatchURLParser.parse(text: newText)
                }

            if !batchItems.isEmpty {
                HStack {
                    Text("\(selectedBatchCount) / \(batchItems.count) " + L10n.t(de: "ausgewählt", en: "selected"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L10n.t(de: "Alle", en: "All")) {
                        for i in batchItems.indices { batchItems[i].isSelected = true }
                    }
                    .buttonStyle(.link)
                    .font(.caption)

                    Button(L10n.t(de: "Keine", en: "None")) {
                        for i in batchItems.indices { batchItems[i].isSelected = false }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach($batchItems) { $item in
                            HStack(spacing: 8) {
                                Toggle("", isOn: $item.isSelected)
                                    .labelsHidden()
                                    .controlSize(.small)
                                Text(item.fileName)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.url.host ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 120)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack {
            if isSubmitting {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            Button(L10n.t(de: "Abbrechen", en: "Cancel")) {
                viewModel.isShowingAddSheet = false
                viewModel.addError = nil
            }
            .keyboardShortcut(.cancelAction)
            .disabled(isSubmitting)

            if mode == .single {
                Button(L10n.t(de: "Download hinzufügen", en: "Add Download")) {
                    isSubmitting = true
                    viewModel.addDownload(
                        urlString: urlString,
                        preferredSegmentsCount: segmentsCount,
                        saveDirectory: saveDirectory,
                        fileNameOverride: fileNameOverride.isEmpty ? nil : fileNameOverride,
                        category: selectedCategory,
                        folder: selectedFolder
                    )
                    isSubmitting = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(
                    isSubmitting ||
                    urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            } else {
                Button(L10n.t(de: "Pausiert anlegen", en: "Queue Paused")) {
                    submitBatch(startImmediately: false)
                }
                .disabled(isSubmitting || selectedBatchCount == 0)

                Button(L10n.t(de: "Alle starten (\(selectedBatchCount))", en: "Start All (\(selectedBatchCount))")) {
                    submitBatch(startImmediately: true)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isSubmitting || selectedBatchCount == 0)
            }
        }
    }

    private func submitBatch(startImmediately: Bool) {
        let urls = batchItems.filter(\.isSelected).map(\.url)
        guard !urls.isEmpty else { return }
        isSubmitting = true
        viewModel.addBatchDownloads(
            urls: urls,
            preferredSegmentsCount: segmentsCount,
            saveDirectory: saveDirectory,
            category: selectedCategory,
            folder: selectedFolder,
            startImmediately: startImmediately
        )
        isSubmitting = false
    }
}
