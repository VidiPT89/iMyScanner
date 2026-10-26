import SwiftUI
import Combine

@MainActor
final class DocumentsListViewModel: ObservableObject {
    @Published var documents: [ScanDocument] = []
    @Published var folders: [DocumentFolder] = []
    @Published var isScannerPresented = false
    @Published var isPhotoPickerPresented = false
    @Published var isFilePickerPresented = false
    @Published var lastImportedDocument: ScanDocument?
    @Published var isImportingFiles = false
    /// `nil` means "All Documents" (no folder filtering applied).
    @Published var selectedFolderId: UUID?
    @Published var searchText: String = ""

    private let storage = DocumentStorageService.shared

    init() {
        #if DEBUG
        if SampleDocuments.isRequested {
            SampleDocuments.install(into: storage, portuguese: LocalizationManager.shared.language == .portuguese)
        }
        #endif
        loadDocuments()
        loadFolders()
        storage.removeOrphanedFiles()
    }

    /// Documents matching the current folder selection and search text.
    var filteredDocuments: [ScanDocument] {
        var result = documents
        if let selection = selectedFolderId {
            result = result.filter { $0.folderId == selection }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return result }
        let digits = query.filter(\.isNumber)
        return result.filter { document in
            document.title.lowercased().contains(query) ||
            document.tags.contains { $0.lowercased().contains(query) } ||
            // Invoices are also found by the seller's NIF or the ATCUD.
            document.fiscalInvoice.map { invoice in
                (digits.count >= 3 && invoice.issuerNIF.contains(digits)) || invoice.atcud.lowercased().contains(query)
            } ?? false
        }
    }

    func documentCount(in folderId: UUID?) -> Int {
        documents.filter { $0.folderId == folderId }.count
    }

    func loadDocuments() {
        documents = storage.loadDocuments().sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadFolders() {
        folders = storage.loadFolders().sorted { $0.createdAt < $1.createdAt }
    }

    func createDocument(from images: [UIImage]) {
        guard !images.isEmpty else { return }
        guard let pages = storage.savePages(images), !pages.isEmpty else { return }

        let title = defaultTitle()
        let folderId = selectedFolderId
        // Barcode detection on full-size scans takes a moment, so it runs off the main
        // thread; the document opens once it's known whether a page is an invoice.
        DispatchQueue.global(qos: .userInitiated).async { [storage, weak self] in
            let invoice = FiscalQRService.shared.detectInvoice(in: pages, storage: storage)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let document = ScanDocument(title: invoice.map(InvoiceFormat.defaultTitle) ?? title, pages: pages,
                                            folderId: folderId, fiscalInvoice: invoice)
                self.documents.insert(document, at: 0)
                self.persist()
                self.lastImportedDocument = self.documents.first { $0.id == document.id }
            }
        }
    }

    /// Documents whose pages include a Portuguese invoice, for the Expenses screen.
    var invoiceDocuments: [(title: String, invoice: FiscalInvoice)] {
        documents.compactMap { document in document.fiscalInvoice.map { (document.title, $0) } }
    }

    /// Imports files picked via "Browse Files": images are combined into one
    /// new scanned document, each PDF becomes its own rendered document, and
    /// any other file type is stored as a distinct "imported file" entry.
    func importPickedFiles(_ urls: [URL]) {
        guard !urls.isEmpty, !isImportingFiles else { return }
        // Rendering PDF pages and decoding image files can take a real
        // amount of time for large or multi-file imports; doing that
        // synchronously here would freeze the UI thread while the picker
        // sheet dismisses. Run the whole outcome off the main thread and
        // only touch published state once it's ready.
        isImportingFiles = true
        let selectedFolderId = self.selectedFolderId
        let defaultTitle = self.defaultTitle()
        DispatchQueue.global(qos: .userInitiated).async { [storage, weak self] in
            let outcome = FileImportService.shared.process(urls: urls)
            var createdDocuments: [ScanDocument] = []

            if !outcome.combinedPages.isEmpty {
                let invoice = FiscalQRService.shared.detectInvoice(in: outcome.combinedPages, storage: storage)
                createdDocuments.append(ScanDocument(title: invoice.map(InvoiceFormat.defaultTitle) ?? defaultTitle,
                                                     pages: outcome.combinedPages, folderId: selectedFolderId,
                                                     fiscalInvoice: invoice))
            }

            for pdf in outcome.pdfDocuments {
                let invoice = FiscalQRService.shared.detectInvoice(in: pdf.pages, storage: storage)
                createdDocuments.append(ScanDocument(title: pdf.title, pages: pdf.pages, folderId: selectedFolderId,
                                                     fiscalInvoice: invoice))
            }

            for imported in outcome.importedFiles {
                let title = (imported.originalName as NSString).deletingPathExtension
                createdDocuments.append(
                    ScanDocument(
                        title: title.isEmpty ? imported.originalName : title,
                        folderId: selectedFolderId,
                        documentKind: .importedFile(originalFilename: imported.originalName),
                        importedFileName: imported.storageName
                    )
                )
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isImportingFiles = false
                if outcome.hadFailures { storage.operationFailed = true }
                guard !createdDocuments.isEmpty else { return }
                self.documents.insert(contentsOf: createdDocuments, at: 0)
                self.persist()
                self.lastImportedDocument = createdDocuments.first.flatMap { created in self.documents.first { $0.id == created.id } }
            }
        }
    }

    func deleteDocument(_ document: ScanDocument) {
        documents.removeAll { $0.id == document.id }
        persist()
    }

    func rename(_ document: ScanDocument, to newTitle: String) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        documents[index].title = trimmed
        documents[index].updatedAt = Date()
        persist()
    }

    func updateDocument(_ document: ScanDocument) -> Bool {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return false }
        documents[index] = document
        documents[index].updatedAt = Date()
        return persist()
    }

    func moveDocument(_ document: ScanDocument, toFolder folderId: UUID?) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index].folderId = folderId
        documents[index].updatedAt = Date()
        persist()
    }

    // MARK: - Folders

    func createFolder(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders.append(DocumentFolder(name: trimmed))
        persistFolders()
    }

    func renameFolder(_ folder: DocumentFolder, to newName: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders[index].name = trimmed
        persistFolders()
    }

    func deleteFolder(_ folder: DocumentFolder) {
        for index in documents.indices where documents[index].folderId == folder.id {
            documents[index].folderId = nil
        }
        guard persist() else { return }
        folders.removeAll { $0.id == folder.id }
        if selectedFolderId == folder.id {
            selectedFolderId = nil
        }
        persistFolders()
    }

    @discardableResult
    private func persist() -> Bool {
        documents.sort { $0.updatedAt > $1.updatedAt }
        if !storage.saveDocuments(documents) { loadDocuments(); return false }
        return true
    }

    private func persistFolders() {
        if !storage.saveFolders(folders) { loadFolders() }
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(L("document.defaultName")) \(formatter.string(from: Date()))"
    }
}
