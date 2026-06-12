import SwiftUI
import UniformTypeIdentifiers

struct AddDownloadView: View {
    @Bindable var viewModel: DownloadListViewModel
    let folders: [DownloadFolder]

    @State private var urlString = ""
    @State private var fileNameOverride = ""
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

    var body: some View {
        VStack(spacing: 16) {
            Text(L10n.t(de: "Download hinzufügen", en: "Add Download"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(L10n.t(de: "Download-URL (https://…)", en: "Download URL (https://…)"), text: $urlString)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

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

            TextField(L10n.t(de: "Dateiname (optional)", en: "File name (optional)"), text: $fileNameOverride)
                .textFieldStyle(.roundedBorder)

            Picker(L10n.t(de: "Kategorie (optional)", en: "Category (optional)"), selection: $selectedCategory) {
                Text(L10n.t(de: "Automatisch", en: "Automatic")).tag(Optional<LibraryCategory>.none)
                ForEach(LibraryCategory.allCases) { category in
                    Text(category.displayName).tag(Optional(category))
                }
            }

            if !folders.isEmpty {
                Picker(L10n.t(de: "Ordner (optional)", en: "Folder (optional)"), selection: $selectedFolder) {
                    Text(L10n.t(de: "Keiner", en: "None")).tag(Optional<DownloadFolder>.none)
                    ForEach(folders) { folder in
                        Text(folder.name).tag(Optional(folder))
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
                .padding(.top, 8)
            }

            if let error = viewModel.addError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
            }
        }
        .padding(24)
        .frame(minWidth: 420, idealWidth: 520, maxWidth: 640)
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
}
