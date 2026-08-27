import SwiftUI

struct PageEditorView: View {
    @StateObject private var viewModel: PageEditorViewModel
    @Environment(\.dismiss) private var dismiss
    let onDone: (ScanPage) -> Void

    init(page: ScanPage, onDone: @escaping (ScanPage) -> Void) {
        _viewModel = StateObject(wrappedValue: PageEditorViewModel(page: page))
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    GeometryReader { geometry in
                        if let image = viewModel.previewImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.25), value: viewModel.page.filter)
                        }
                    }

                    filterBar
                    controlsBar
                }
            }
            .navigationTitle(L("editor.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("action.done")) {
                        onDone(viewModel.finalizedPage())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .fullScreenCover(isPresented: $viewModel.isCropping) {
                if let base = viewModel.previewImage {
                    CropView(
                        image: base,
                        initialCrop: viewModel.page.cropRect ?? .fullFrame,
                        onCancel: { viewModel.isCropping = false },
                        onApply: { crop in
                            viewModel.applyCrop(crop)
                            viewModel.isCropping = false
                        }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showTextSheet) {
                ExtractedTextView(text: viewModel.recognizedText)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PageFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation { viewModel.selectFilter(filter) }
                    } label: {
                        Text(L(filter.titleKey))
                            .font(AppTypography.caption())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                viewModel.page.filter == filter
                                    ? AnyView(LinearGradient(colors: [AppColor.accentOrange, AppColor.accentAmber], startPoint: .leading, endPoint: .trailing))
                                    : AnyView(AppColor.surfaceDark)
                            )
                            .foregroundStyle(viewModel.page.filter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, AppMetrics.standardPadding)
            .padding(.vertical, 12)
        }
    }

    private var controlsBar: some View {
        HStack(spacing: 24) {
            editorButton(icon: "crop", titleKey: "editor.crop") {
                viewModel.isCropping = true
            }
            editorButton(icon: "rotate.right", titleKey: "editor.rotate") {
                withAnimation { viewModel.rotate90() }
            }
            editorButton(icon: "text.viewfinder", titleKey: "editor.extractText") {
                viewModel.extractText()
            }
        }
        .padding(.vertical, 16)
        .padding(.bottom, 12)
    }

    private func editorButton(icon: String, titleKey: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(L(titleKey))
                    .font(AppTypography.caption())
            }
            .foregroundStyle(AppColor.accentOrange)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExtractedTextView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text.isEmpty ? L("editor.noText") : text)
                    .font(AppTypography.body())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(L("editor.extractedText"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("action.close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}
