import Foundation
import UIKit

/// Reads and writes documents and their page images to the app's
/// Documents directory. All storage is local; nothing ever leaves the device.
final class DocumentStorageService {
    static let shared = DocumentStorageService()

    private let fileManager = FileManager.default
    private let indexFileName = "documents_index.json"
    private let foldersFileName = "folders_index.json"

    private lazy var documentsDirectory: URL = {
        let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return url
    }()

    private lazy var imagesDirectory: URL = {
        let url = documentsDirectory.appendingPathComponent("PageImages", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }()

    private lazy var importedFilesDirectory: URL = {
        let url = documentsDirectory.appendingPathComponent("ImportedFiles", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }()

    private var indexURL: URL {
        documentsDirectory.appendingPathComponent(indexFileName)
    }

    private var foldersURL: URL {
        documentsDirectory.appendingPathComponent(foldersFileName)
    }

    func loadFolders() -> [DocumentFolder] {
        guard let data = try? Data(contentsOf: foldersURL) else { return [] }
        return (try? JSONDecoder().decode([DocumentFolder].self, from: data)) ?? []
    }

    func saveFolders(_ folders: [DocumentFolder]) {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        try? data.write(to: foldersURL, options: .atomic)
    }

    func loadDocuments() -> [ScanDocument] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([ScanDocument].self, from: data)) ?? []
    }

    func saveDocuments(_ documents: [ScanDocument]) {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    @discardableResult
    func saveImage(_ image: UIImage, fileName: String? = nil) -> String {
        let name = fileName ?? "\(UUID().uuidString).jpg"
        let url = imagesDirectory.appendingPathComponent(name)
        if let data = image.jpegData(compressionQuality: 0.92) {
            try? data.write(to: url, options: .atomic)
        }
        return name
    }

    func loadImage(fileName: String) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteImage(fileName: String) {
        let url = imagesDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }

    func deleteImages(for document: ScanDocument) {
        for page in document.pages {
            deleteImage(fileName: page.originalFileName)
            if page.editedFileName != page.originalFileName {
                deleteImage(fileName: page.editedFileName)
            }
        }
    }

    // MARK: - Imported files (Browse Files: non-image, non-PDF documents)

    /// Copies a picked file into the app's own storage, avoiding name
    /// collisions, and returns the name it was stored under.
    @discardableResult
    func copyImportedFile(from sourceURL: URL) -> String? {
        let originalName = sourceURL.lastPathComponent
        let ext = sourceURL.pathExtension
        let base = sourceURL.deletingPathExtension().lastPathComponent
        var candidateName = originalName
        var counter = 1
        while fileManager.fileExists(atPath: importedFilesDirectory.appendingPathComponent(candidateName).path) {
            candidateName = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            counter += 1
        }
        let destination = importedFilesDirectory.appendingPathComponent(candidateName)
        do {
            try fileManager.copyItem(at: sourceURL, to: destination)
            return candidateName
        } catch {
            return nil
        }
    }

    func importedFileURL(fileName: String) -> URL {
        importedFilesDirectory.appendingPathComponent(fileName)
    }

    func deleteImportedFile(fileName: String) {
        try? fileManager.removeItem(at: importedFileURL(fileName: fileName))
    }
}
