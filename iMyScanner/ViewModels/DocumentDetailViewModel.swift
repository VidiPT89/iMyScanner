import SwiftUI
import Combine

@MainActor
final class DocumentDetailViewModel: ObservableObject {
    @Published var document: ScanDocument
    @Published var isSharePresented = false
    @Published var shareItems: [Any] = []
    @Published var isAddingPages = false

    private let storage = DocumentStorageService.shared
    private let onUpdate: (ScanDocument) -> Void

    init(document: ScanDocument, onUpdate: @escaping (ScanDocument) -> Void) {
        self.document = document
        self.onUpdate = onUpdate
    }

    func image(for page: ScanPage) -> UIImage? {
        storage.loadImage(fileName: page.editedFileName)
    }

    func addPages(_ images: [UIImage]) {
        for image in images {
            let fileName = storage.saveImage(image)
            document.pages.append(ScanPage(originalFileName: fileName, editedFileName: fileName))
        }
        commit()
    }

    func deletePage(_ page: ScanPage) {
        storage.deleteImage(fileName: page.originalFileName)
        if page.editedFileName != page.originalFileName {
            storage.deleteImage(fileName: page.editedFileName)
        }
        document.pages.removeAll { $0.id == page.id }
        commit()
    }

    func movePages(from source: IndexSet, to destination: Int) {
        document.pages.move(fromOffsets: source, toOffset: destination)
        commit()
    }

    func replacePage(_ page: ScanPage) {
        guard let index = document.pages.firstIndex(where: { $0.id == page.id }) else { return }
        document.pages[index] = page
        commit()
    }

    func rename(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        document.title = trimmed
        commit()
    }

    func preparePDFShare() {
        guard let url = PDFExportService.shared.generatePDF(for: document) else { return }
        shareItems = [url]
        isSharePresented = true
    }

    func prepareImagesShare() {
        let urls = PDFExportService.shared.exportImages(for: document)
        guard !urls.isEmpty else { return }
        shareItems = urls
        isSharePresented = true
    }

    private func commit() {
        document.updatedAt = Date()
        onUpdate(document)
    }
}
