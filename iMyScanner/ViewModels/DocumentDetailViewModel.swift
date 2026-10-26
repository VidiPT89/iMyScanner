import SwiftUI
import Combine

@MainActor
final class DocumentDetailViewModel: ObservableObject {
    @Published var document: ScanDocument
    @Published var isSharePresented = false
    @Published var shareItems: [Any] = []
    @Published var exportFailed = false
    /// True while a PDF/Word/image export is being generated off the main
    /// thread. Multi-page documents can take a noticeable amount of time to
    /// render and zip, so the UI surfaces this instead of appearing to hang.
    @Published var isExporting = false
    @Published var isReadingInvoice = false
    /// Set after a manual "Read Invoice QR" that found no AT code.
    @Published var invoiceNotFound = false

    private var savedDocument: ScanDocument
    private let storage = DocumentStorageService.shared
    private let onUpdate: (ScanDocument) -> Bool

    init(document: ScanDocument, onUpdate: @escaping (ScanDocument) -> Bool) {
        self.document = document
        self.savedDocument = document
        self.onUpdate = onUpdate
    }

    func addPages(_ images: [UIImage]) {
        guard let pages = storage.savePages(images) else { return }
        document.pages.append(contentsOf: pages)
        commit()
        if document.fiscalInvoice == nil { readInvoice(from: pages, reportMissing: false) }
    }

    /// Looks for the AT QR code again, e.g. after recropping a page where it was cut off.
    func rescanInvoice() {
        readInvoice(from: document.pages, reportMissing: true)
    }

    private func readInvoice(from pages: [ScanPage], reportMissing: Bool) {
        guard !isReadingInvoice else { return }
        isReadingInvoice = true
        let storage = storage
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let invoice = FiscalQRService.shared.detectInvoice(in: pages, storage: storage)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isReadingInvoice = false
                guard var invoice else {
                    if reportMissing { self.invoiceNotFound = true }
                    return
                }
                // A rescan of the same invoice keeps the category the user chose.
                if let previous = self.document.fiscalInvoice, previous.atcud == invoice.atcud {
                    invoice.category = previous.category
                }
                self.document.fiscalInvoice = invoice
                self.commit()
            }
        }
    }

    func setExpenseCategory(_ category: ExpenseCategory) {
        guard document.fiscalInvoice?.category != category else { return }
        document.fiscalInvoice?.category = category
        commit()
    }

    func removeInvoice() {
        document.fiscalInvoice = nil
        commit()
    }

    func movePage(_ page: ScanPage, by offset: Int) {
        guard document.movePage(id: page.id, by: offset) else { return }
        commit()
    }

    func canMovePage(_ page: ScanPage, by offset: Int) -> Bool {
        guard let index = document.pages.firstIndex(where: { $0.id == page.id }) else { return false }
        return document.pages.indices.contains(index + offset)
    }

    func deletePage(_ page: ScanPage) {
        document.pages.removeAll { $0.id == page.id }
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

    /// Pages the user never ran "Extract Text" on are recognized now, so the
    /// Word file is not just a list of empty pages.
    func prepareWordShare() {
        let snapshot = document
        let storage = storage
        export {
            let texts: [String?] = snapshot.pages.map { page in
                if let text = page.recognizedText { return text }
                guard let cgImage = storage.loadImage(fileName: page.editedFileName)?.cgImage else { return nil }
                return OCRService.shared.recognizeLines(in: cgImage).map(\.text).joined(separator: "\n")
            }
            return DocxExportService.shared.generateDocx(for: snapshot, pageTexts: texts).map { [$0] }
        }
    }

    /// Renders an export off the main thread: reading and re-encoding every
    /// page's full-resolution image and, for PDFs, running PDFKit's layout
    /// pass can take a real amount of time for multi-page documents, and
    /// doing that synchronously on the main thread would freeze the UI while
    /// the share sheet is about to appear. `makeURLs` must not touch
    /// `self` — callers pass it a snapshot of whatever document state it needs.
    private func export(_ makeURLs: @escaping @Sendable () -> [URL]?) {
        guard !isExporting else { return }
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let urls = makeURLs()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isExporting = false
                guard let urls, !urls.isEmpty else {
                    self.exportFailed = true
                    return
                }
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
        if onUpdate(document) { savedDocument = document }
        else { document = savedDocument }
    }
}
