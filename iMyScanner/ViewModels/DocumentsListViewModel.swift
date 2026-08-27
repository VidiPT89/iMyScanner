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
    /// `nil` means "All Documents" (no folder filtering applied).
    @Published var selectedFolderId: UUID?
    @Published var searchText: String = ""

    private let storage = DocumentStorageService.shared

    init() {
        loadDocuments()
        loadFolders()
    }

    /// Documents matching the current folder selection and search text.
    var filteredDocuments: [ScanDocument] {
        var result = documents
        if let selection = selectedFolderId {
            result = result.filter { $0.folderId == selection }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return result }
        return result.filter { document in
            document.title.lowercased().contains(query) ||
            document.tags.contains { $0.lowercased().contains(query) }
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
        var pages: [ScanPage] = []
        for image in images {
            let fileName = storage.saveImage(image)
            pages.append(ScanPage(originalFileName: fileName, editedFileName: fileName))
        }

        let title = defaultTitle()
        let document = ScanDocument(title: title, pages: pages, folderId: selectedFolderId)
        documents.insert(document, at: 0)
        persist()
        lastImportedDocument = document
    }

    /// Imports files picked via "Browse Files": images are combined into one
    /// new scanned document, each PDF becomes its own rendered document, and
    /// any other file type is stored as a distinct "imported file" entry.
    func importPickedFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let outcome = FileImportService.shared.process(urls: urls)
        var createdDocuments: [ScanDocument] = []

        if !outcome.combinedImages.isEmpty {
            var pages: [ScanPage] = []
            for image in outcome.combinedImages {
                let fileName = storage.saveImage(image)
                pages.append(ScanPage(originalFileName: fileName, editedFileName: fileName))
            }
            createdDocuments.append(ScanDocument(title: defaultTitle(), pages: pages, folderId: selectedFolderId))
        }

        for pdf in outcome.pdfDocuments {
            var pages: [ScanPage] = []
            for image in pdf.images {
                let fileName = storage.saveImage(image)
                pages.append(ScanPage(originalFileName: fileName, editedFileName: fileName))
            }
            createdDocuments.append(ScanDocument(title: pdf.title, pages: pages, folderId: selectedFolderId))
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

        guard !createdDocuments.isEmpty else { return }
        documents.insert(contentsOf: createdDocuments, at: 0)
        persist()
        lastImportedDocument = createdDocuments.first
    }

    func deleteDocument(_ document: ScanDocument) {
        storage.deleteImages(for: document)
        if let importedFileName = document.importedFileName {
            storage.deleteImportedFile(fileName: importedFileName)
        }
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
        folders.removeAll { $0.id == folder.id }
        for index in documents.indices where documents[index].folderId == folder.id {
            documents[index].folderId = nil
        }
        if selectedFolderId == folder.id {
            selectedFolderId = nil
        }
        persistFolders()
        persist()
    }

    private func persist() {
        storage.saveDocuments(documents)
    }

    private func persistFolders() {
        storage.saveFolders(folders)
    }

    private func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(L("document.defaultName")) \(formatter.string(from: Date()))"
    }
}
