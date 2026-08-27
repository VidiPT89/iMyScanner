import SwiftUI

struct DocumentDetailView: View {
    @StateObject private var viewModel: DocumentDetailViewModel
    @State private var editingPage: ScanPage?
    @State private var isRenaming = false
    @State private var newTitle = ""
    @State private var isScannerPresented = false
    @Environment(\.editMode) private var editMode

    init(document: ScanDocument, onUpdate: @escaping (ScanDocument) -> Void) {
        _viewModel = StateObject(wrappedValue: DocumentDetailViewModel(document: document, onUpdate: onUpdate))
    }

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: AppMetrics.cardSpacing)]

    var body: some View {
        ZStack {
            AppColor.backgroundBlack.ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: columns, spacing: AppMetrics.cardSpacing) {
                    ForEach(viewModel.document.pages) { page in
                        pageThumbnail(page)
                    }
                }
                .padding(AppMetrics.standardPadding)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.document.pages)
        }
        .navigationTitle(viewModel.document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newTitle = viewModel.document.title
                        isRenaming = true
                    } label: {
                        Label(L("action.rename"), systemImage: "pencil")
                    }
                    Button {
                        isScannerPresented = true
                    } label: {
                        Label(L("document.addPages"), systemImage: "plus.rectangle.on.rectangle")
                    }
                    Button {
                        viewModel.preparePDFShare()
                    } label: {
                        Label(L("document.exportPDF"), systemImage: "doc.richtext")
                    }
                    Button {
                        viewModel.prepareImagesShare()
                    } label: {
                        Label(L("document.exportImages"), systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fullScreenCover(item: $editingPage) { page in
            PageEditorView(page: page) { updatedPage in
                viewModel.replacePage(updatedPage)
            }
        }
        .sheet(isPresented: $isScannerPresented) {
            DocumentScannerView(
                onFinish: { images in
                    isScannerPresented = false
                    viewModel.addPages(images)
                },
                onCancel: { isScannerPresented = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $viewModel.isSharePresented) {
            ActivityShareSheet(items: viewModel.shareItems)
        }
        .alert(L("action.rename"), isPresented: $isRenaming) {
            TextField(L("document.name.placeholder"), text: $newTitle)
            Button(L("action.cancel"), role: .cancel) {}
            Button(L("action.save")) { viewModel.rename(to: newTitle) }
        }
    }

    private func pageThumbnail(_ page: ScanPage) -> some View {
        Button {
            editingPage = page
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius)
                        .fill(AppColor.surfaceDark)
                    if let image = viewModel.image(for: page) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCornerRadius))
                    }
                }
                .frame(height: 180)
                .clipped()
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

                Text(L(page.filter.titleKey))
                    .font(AppTypography.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { viewModel.deletePage(page) }
            } label: {
                Label(L("action.delete"), systemImage: "trash")
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
