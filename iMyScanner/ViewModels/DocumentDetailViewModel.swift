import SwiftUI
import Combine

@MainActor
final class DocumentDetailViewModel: ObservableObject {
    @Published var document: ScanDocument
    @Published var isSharePresented = false
    @Published var shareItems: [Any] = []
    @Published var isAddingPages = false
    /// True while a PDF/Word/image export is being generated off the main
    /// thread. Multi-page documents can take a noticeable amount of time to
    /// render and zip, so the UI surfaces this instead of appearing to hang.
    @Published var isExporting = false

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
        let snapshot = document
        export { PDFExportService.shared.generatePDF(for: snapshot).map { [$0] } }
    }

    func prepareImagesShare() {
        let snapshot = document
        export {
            let urls = PDFExportService.shared.exportImages(for: snapshot)
            return urls.isEmpty ? nil : urls
        }
    }

    func prepareWordShare() {
        let snapshot = document
        export { DocxExportService.shared.generateDocx(for: snapshot).map { [$0] } }
    }

    /// Renders an export off the main thread: reading and re-encoding every
    /// page's full-resolution image and, for PDFs, running PDFKit's layout
    /// pass can take a real amount of time for multi-page documents, and
    /// doing that synchronously on the main thread would freeze the UI while
    /// the share sheet is about to appear. `makeURLs` must not touch
    /// `self` — callers pass it a snapshot of whatever document state it needs.
    private func export(_ makeURLs: @escaping () -> [URL]?) {
        guard !isExporting else { return }
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let urls = makeURLs()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isExporting = false
                guard let urls, !urls.isEmpty else { return }
                self.shareItems = urls
                self.isSharePresented = true
            }
        }
    }

    func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !document.tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        document.tags.append(trimmed)
        commit()
    }

    func removeTag(_ tag: String) {
        document.tags.removeAll { $0 == tag }
        commit()
    }

    private func commit() {
        document.updatedAt = Date()
        onUpdate(document)
    }
}
