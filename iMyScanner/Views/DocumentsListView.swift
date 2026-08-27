import SwiftUI

struct DocumentsListView: View {
    @StateObject private var viewModel = DocumentsListViewModel()
    @State private var isGridLayout = true
    @State private var showSettings = false
    @State private var navigateToDocument: ScanDocument?
    @State private var isDetailPresented = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: AppMetrics.cardSpacing)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundBlack.ignoresSafeArea()

                if viewModel.documents.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        if isGridLayout {
                            LazyVGrid(columns: columns, spacing: AppMetrics.cardSpacing) {
                                ForEach(viewModel.documents) { document in
                                    documentCard(document)
                                }
                            }
                            .padding(AppMetrics.standardPadding)
                        } else {
                            LazyVStack(spacing: AppMetrics.cardSpacing) {
                                ForEach(viewModel.documents) { document in
                                    documentRow(document)
                                }
                            }
                            .padding(AppMetrics.standardPadding)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.documents)
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
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
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

    private var emptyState: some View {
        VStack(spacing: 16) {
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
        }
    }

    private var scanButton: some View {
        VStack {
            Spacer()
            Button {
                viewModel.isScannerPresented = true
            } label: {
                Label(L("documents.scan"), systemImage: "camera.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppMetrics.standardPadding)
            .padding(.bottom, 24)
        }
    }

    private func documentCard(_ document: ScanDocument) -> some View {
        Button {
            navigateToDocument = document
            isDetailPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
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
                }
                .frame(height: 150)
                .clipped()

                Text(document.title)
                    .font(AppTypography.headline())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(document.pageCountDescription)
                    .font(AppTypography.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu { documentMenu(document) }
        .transition(.scale.combined(with: .opacity))
    }

    private func documentRow(_ document: ScanDocument) -> some View {
        Button {
            navigateToDocument = document
            isDetailPresented = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius)
                        .fill(AppColor.surfaceDark)
                    if let first = document.pages.first,
                       let image = DocumentStorageService.shared.loadImage(fileName: first.editedFileName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius))
                    }
                }
                .frame(width: 56, height: 56)
                .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(AppTypography.headline())
                        .foregroundStyle(.primary)
                    Text(document.pageCountDescription)
                        .font(AppTypography.caption())
                        .foregroundStyle(.secondary)
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

    @ViewBuilder
    private func documentMenu(_ document: ScanDocument) -> some View {
        Button(role: .destructive) {
            withAnimation { viewModel.deleteDocument(document) }
        } label: {
            Label(L("action.delete"), systemImage: "trash")
        }
    }
}
