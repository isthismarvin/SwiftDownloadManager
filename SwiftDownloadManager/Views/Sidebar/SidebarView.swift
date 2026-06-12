import SwiftUI
import SwiftData

struct SidebarView: View {
    @Bindable var viewModel: DownloadListViewModel
    let badgeCounts: SidebarBadgeCounts
    @Bindable private var appSettings = AppSettings.shared

    @Query(sort: \DownloadFolder.createdAt) private var customFolders: [DownloadFolder]
    @State private var folderToRename: DownloadFolder?
    @State private var renameFolderName = ""

    var body: some View {
        List(selection: $viewModel.selectedSidebarItem) {
            Section {
                ForEach(SidebarSelection.downloadFilters) { item in
                    sidebarRow(item)
                }
            }

            if appSettings.showSmartSidebarFilters {
                Section(L10n.t(de: "Smart Filter", en: "Smart Filters")) {
                    ForEach(SidebarSelection.smartFilters) { item in
                        sidebarRow(item)
                    }
                }
            }

            Section(L10n.t(de: "Ordner", en: "Folders")) {
                ForEach(SidebarSelection.folderFilters) { item in
                    sidebarRow(item)
                }

                ForEach(customFolders) { folder in
                    customFolderRow(folder)
                }

                Button {
                    viewModel.isShowingNewFolderAlert = true
                } label: {
                    Label {
                        Text(L10n.t(de: "Neuer Ordner", en: "New Folder"))
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        .safeAreaInset(edge: .bottom) {
            SidebarBottomBar(viewModel: viewModel)
        }
        .alert(L10n.t(de: "Neuer Ordner", en: "New Folder"), isPresented: $viewModel.isShowingNewFolderAlert) {
            TextField(L10n.t(de: "Ordnername", en: "Folder name"), text: $viewModel.newFolderName)
            Button(L10n.t(de: "Abbrechen", en: "Cancel"), role: .cancel) {
                viewModel.newFolderName = ""
            }
            Button(L10n.t(de: "Erstellen", en: "Create")) {
                viewModel.createFolder()
            }
        } message: {
            Text(L10n.t(de: "Gib einen Namen für den neuen Ordner ein.", en: "Enter a name for the new folder."))
        }
        .alert(L10n.t(de: "Ordner umbenennen", en: "Rename Folder"), isPresented: Binding(
            get: { folderToRename != nil },
            set: { if !$0 { folderToRename = nil } }
        )) {
            TextField(L10n.t(de: "Ordnername", en: "Folder name"), text: $renameFolderName)
            Button(L10n.t(de: "Abbrechen", en: "Cancel"), role: .cancel) {
                folderToRename = nil
            }
            Button(L10n.t(de: "Umbenennen", en: "Rename")) {
                if let folder = folderToRename {
                    viewModel.renameFolder(folder, to: renameFolderName)
                }
                folderToRename = nil
            }
        }
    }

    @ViewBuilder
    private func sidebarRow(_ item: SidebarSelection) -> some View {
        HStack(spacing: 0) {
            Label {
                Text(item.displayName)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } icon: {
                Image(systemName: item.icon)
                    .foregroundStyle(item.iconColor)
            }

            Spacer()

            if let count = badgeCounts.count(for: item) {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
        }
        .tag(item)
        .help(item.displayName)
    }

    @ViewBuilder
    private func customFolderRow(_ folder: DownloadFolder) -> some View {
        HStack(spacing: 0) {
            Label {
                Text(folder.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } icon: {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
            }

            Spacer()

            if let count = badgeCounts.count(for: .customFolder(folder.id)) {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
        }
        .tag(SidebarSelection.customFolder(folder.id))
        .help(folder.name)
        .contextMenu {
            Button(L10n.t(de: "Umbenennen…", en: "Rename…")) {
                folderToRename = folder
                renameFolderName = folder.name
            }
            Button(L10n.t(de: "Ordner löschen", en: "Delete Folder"), role: .destructive) {
                viewModel.deleteFolder(folder)
            }
        }
    }
}
