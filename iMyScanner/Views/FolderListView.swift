import SwiftUI

/// Sidebar-style management screen for folders: create, rename, delete.
/// Deleting a folder never deletes its documents, they move back to
/// "All Documents".
struct FolderListView: View {
    @ObservedObject var viewModel: DocumentsListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingFolder = false
    @State private var newFolderName = ""
    @State private var renamingFolder: DocumentFolder?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundBlack.ignoresSafeArea()
                List {
                    Section {
                        HStack {
                            Text(L("folders.all"))
                            Spacer()
                            Text("\(viewModel.documents.count)")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedFolderId = nil
                            dismiss()
                        }
                    }

                    Section(L("folders.title")) {
                        ForEach(viewModel.folders) { folder in
                            HStack {
                                Text(folder.name)
                                Spacer()
                                Text("\(viewModel.documentCount(in: folder.id))")
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedFolderId = folder.id
                                dismiss()
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteFolder(folder)
                                } label: {
                                    Label(L("action.delete"), systemImage: "trash")
                                }
                                Button {
                                    renameText = folder.name
                                    renamingFolder = folder
                                } label: {
                                    Label(L("action.rename"), systemImage: "pencil")
                                }
                                .tint(AppColor.accentOrange)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L("folders.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newFolderName = ""
                        isAddingFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("action.close")) { dismiss() }
                }
            }
            .alert(L("folders.new"), isPresented: $isAddingFolder) {
                TextField(L("folders.name.placeholder"), text: $newFolderName)
                Button(L("action.cancel"), role: .cancel) {}
                Button(L("action.save")) { viewModel.createFolder(named: newFolderName) }
            }
            .alert(L("action.rename"), isPresented: Binding(
                get: { renamingFolder != nil },
                set: { if !$0 { renamingFolder = nil } }
            )) {
                TextField(L("folders.name.placeholder"), text: $renameText)
                Button(L("action.cancel"), role: .cancel) {}
                Button(L("action.save")) {
                    if let folder = renamingFolder {
                        viewModel.renameFolder(folder, to: renameText)
                    }
                }
            }
        }
    }
}
