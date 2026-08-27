import SwiftUI
import Combine

@MainActor
final class DocumentsListViewModel: ObservableObject {
    @Published var documents: [ScanDocument] = []
    @Published var isScannerPresented = false
    @Published var lastImportedDocument: ScanDocument?

    private let storage = DocumentStorageService.shared

    init() {
        loadDocuments()
    }

    func loadDocuments() {
        documents = storage.loadDocuments().sorted { $0.updatedAt > $1.updatedAt }
    }

    func createDocument(from images: [UIImage]) {
        guard !images.isEmpty else { return }
        var pages: [ScanPage] = []
        for image in images {
            let fileName = storage.saveImage(image)
            pages.append(ScanPage(originalFileName: fileName, editedFileName: fileName))
        }

        let title = defaultTitle()
        let document = ScanDocument(title: title, pages: pages)
        documents.insert(document, at: 0)
        persist()
        lastImportedDocument = document
    }

    func deleteDocument(_ document: ScanDocument) {
        storage.deleteImages(for: document)
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

    func updateDocument(_ document: ScanDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index] = document
        documents[index].updatedAt = Date()
        persist()
    }

    private func persist() {
        storage.saveDocuments(documents)
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(L("document.defaultName")) \(formatter.string(from: Date()))"
    }
}
