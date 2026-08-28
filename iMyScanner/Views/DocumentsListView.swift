import SwiftUI

struct DocumentsListView: View {
    @StateObject private var viewModel = DocumentsListViewModel()
    @State private var isGridLayout = true
    @State private var showSettings = false
    @State private var navigateToDocument: ScanDocument?
    @State private var isDetailPresented = false
    @State private var showFolders = false
    @State private var quickLookDocument: ScanDocument?
    @State private var isSharingImportedFile = false
    @State private var importedFileShareURL: URL?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: AppMetrics.cardSpacing)]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColor.backgroundBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    folderChips

                    if viewModel.filteredDocuments.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            if isGridLayout {
                                LazyVGrid(columns: columns, spacing: AppMetrics.cardSpacing) {
                                    ForEach(viewModel.filteredDocuments) { document in
                                        documentCard(document)
                                    }
                                }
                                .padding(AppMetrics.standardPadding)
                            } else {
                                LazyVStack(spacing: AppMetrics.cardSpacing) {
                                    ForEach(viewModel.filteredDocuments) { document in
                                        documentRow(document)
                                    }
                                }
                                .padding(AppMetrics.standardPadding)
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.filteredDocuments)
                    }
                }

                scanButton
            }
            .navigationTitle(L("documents.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation { isGridLayout.toggle() }
                    } label: {
                        Image(systemName: isGridLayout ? "list.bullet" : "square.grid.2x2")
                    }
                    .accessibilityLabel(L("documents.toggleLayout"))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFolders = true
                    } label: {
                        Image(systemName: "folder")
                    }
                    .accessibilityLabel(L("folders.title"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(L("settings.title"))
                }
            }
            .sheet(isPresented: $viewModel.isScannerPresented) {
                DocumentScannerView(
                    onFinish: { images in
                        viewModel.isScannerPresented = false
                        viewModel.createDocument(from: images)
                    },
                    onCancel: { viewModel.isScannerPresented = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $viewModel.isPhotoPickerPresented) {
                PhotoLibraryPickerView(
                    onFinish: { images in
                        viewModel.isPhotoPickerPresented = false
                        viewModel.createDocument(from: images)
                    },
                    onCancel: { viewModel.isPhotoPickerPresented = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $viewModel.isFilePickerPresented) {
                DocumentImportPickerView(
                    onFinish: { urls in
                        viewModel.isFilePickerPresented = false
                        viewModel.importPickedFiles(urls)
                    },
                    onCancel: { viewModel.isFilePickerPresented = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showFolders) {
                FolderListView(viewModel: viewModel)
            }
            .sheet(item: $quickLookDocument) { document in
                if let fileName = document.importedFileName {
                    QuickLookPreviewView(url: DocumentStorageService.shared.importedFileURL(fileName: fileName))
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $isSharingImportedFile) {
                if let url = importedFileShareURL {
                    ActivityShareSheet(items: [url])
                }
            }
            .navigationDestination(isPresented: $isDetailPresented) {
                if let document = navigateToDocument {
                    DocumentDetailView(
                        document: document,
                        onUpdate: { viewModel.updateDocument($0) }
                    )
                }
            }
            .onChange(of: viewModel.lastImportedDocument) { newValue in
                if let newValue {
                    navigateToDocument = newValue
                    isDetailPresented = true
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L("documents.search.placeholder"), text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(L("action.clear"))
            }
        }
        .padding(10)
        .background(AppColor.surfaceDark.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius))
        .padding(.horizontal, AppMetrics.standardPadding)
        .padding(.top, 8)
    }

    private var folderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                folderChip(name: L("folders.all"), count: viewModel.documents.count, isSelected: viewModel.selectedFolderId == nil) {
                    viewModel.selectedFolderId = nil
                }
                ForEach(viewModel.folders) { folder in
                    folderChip(
                        name: folder.name,
                        count: viewModel.documentCount(in: folder.id),
                        isSelected: viewModel.selectedFolderId == folder.id
                    ) {
                        viewModel.selectedFolderId = folder.id
                    }
                }
            }
            .padding(.horizontal, AppMetrics.standardPadding)
            .padding(.vertical, 10)
        }
    }

    private func folderChip(name: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(name) (\(count))")
                .font(AppTypography.caption())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppColor.accentOrange : AppColor.surfaceDark.opacity(0.6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(AppColor.accentOrange)
            Text(L("documents.empty.title"))
                .font(AppTypography.headline())
            Text(L("documents.empty.subtitle"))
                .font(AppTypography.body())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var scanButton: some View {
        VStack {
            Spacer()
            Menu {
                if isDocumentScanningAvailable() {
                    Button {
                        viewModel.isScannerPresented = true
                    } label: {
                        Label(L("documents.source.camera"), systemImage: "camera.fill")
                    }
                }
                Button {
                    viewModel.isPhotoPickerPresented = true
                } label: {
                    Label(L("documents.source.photos"), systemImage: "photo.on.rectangle")
                }
                Button {
                    viewModel.isFilePickerPresented = true
                } label: {
                    Label(L("documents.source.files"), systemImage: "folder")
                }
            } label: {
                Label(L("documents.scan"), systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppMetrics.standardPadding)
            .padding(.bottom, 24)
        }
    }

    private func documentCard(_ document: ScanDocument) -> some View {
        Button {
            openDocument(document)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius)
                        .fill(AppColor.surfaceDark)
                    if let first = document.pages.first,
                       let image = DocumentStorageService.shared.loadImage(fileName: first.editedFileName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius))
                    } else {
                        Image(systemName: "doc")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                    if document.isImportedFile {
                        importedFileBadgeIcon
                    }
                }
                .frame(height: 150)
                .clipped()

                Text(document.title)
                    .font(AppTypography.headline())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(document.subtitleDescription)
                    .font(AppTypography.caption())
                    .foregroundStyle(document.isImportedFile ? AppColor.accentOrange : .secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu { documentMenu(document) }
        .transition(.scale.combined(with: .opacity))
    }

    private func documentRow(_ document: ScanDocument) -> some View {
        Button {
            openDocument(document)
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius)
                        .fill(AppColor.surfaceDark)
                    if let first = document.pages.first,
                       let image = DocumentStorageService.shared.loadImage(fileName: first.editedFileName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius))
                    } else if document.isImportedFile {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 56, height: 56)
                .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(AppTypography.headline())
                        .foregroundStyle(.primary)
                    Text(document.subtitleDescription)
                        .font(AppTypography.caption())
                        .foregroundStyle(document.isImportedFile ? AppColor.accentOrange : .secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(AppColor.surfaceDark.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius))
        }
        .buttonStyle(.plain)
        .contextMenu { documentMenu(document) }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var importedFileBadgeIcon: some View {
        Image(systemName: "doc.badge.ellipsis")
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(6)
            .background(AppColor.accentOrange)
            .clipShape(Circle())
            .padding(6)
    }

    private func openDocument(_ document: ScanDocument) {
        if document.isImportedFile {
            quickLookDocument = document
        } else {
            navigateToDocument = document
            isDetailPresented = true
        }
    }

    @ViewBuilder
    private func documentMenu(_ document: ScanDocument) -> some View {
        Menu(L("folders.moveTo")) {
            Button(L("folders.all")) { viewModel.moveDocument(document, toFolder: nil) }
            ForEach(viewModel.folders) { folder in
                Button(folder.name) { viewModel.moveDocument(document, toFolder: folder.id) }
            }
        }
        if document.isImportedFile, let fileName = document.importedFileName {
            Button {
                importedFileShareURL = DocumentStorageService.shared.importedFileURL(fileName: fileName)
                isSharingImportedFile = true
            } label: {
                Label(L("action.share"), systemImage: "square.and.arrow.up")
            }
        }
        Button(role: .destructive) {
            withAnimation { viewModel.deleteDocument(document) }
        } label: {
            Label(L("action.delete"), systemImage: "trash")
        }
    }
}
