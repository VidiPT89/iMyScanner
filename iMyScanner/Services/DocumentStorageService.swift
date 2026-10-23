import Foundation
import UIKit
import Combine
import ImageIO

/// Reads and writes documents and their page images to the app's
/// Documents directory. All storage is local; nothing ever leaves the device.
final class DocumentStorageService: ObservableObject {
    @Published var operationFailed = false

    private func reportFailure() {
        DispatchQueue.main.async { self.operationFailed = true }
    }
    static let shared = DocumentStorageService()

    private let fileManager = FileManager.default
    private let indexFileName = "documents_index.json"
    private let foldersFileName = "folders_index.json"

    private let documentsDirectory: URL
    private let imagesDirectory: URL
    private let importedFilesDirectory: URL

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        documentsDirectory = documents
        imagesDirectory = documents.appendingPathComponent("PageImages", isDirectory: true)
        importedFilesDirectory = documents.appendingPathComponent("ImportedFiles", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: importedFilesDirectory, withIntermediateDirectories: true)
        } catch { reportFailure() }
    }

    private var indexURL: URL {
        documentsDirectory.appendingPathComponent(indexFileName)
    }

    private var foldersURL: URL {
        documentsDirectory.appendingPathComponent(foldersFileName)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL, fallback: T) -> T {
        guard fileManager.fileExists(atPath: url.path) else { return fallback }
        do { return try JSONDecoder().decode(type, from: Data(contentsOf: url)) }
        catch { reportFailure(); return fallback }
    }

    func loadFolders() -> [DocumentFolder] {
        load([DocumentFolder].self, from: foldersURL, fallback: [])
    }

    @discardableResult
    func saveFolders(_ folders: [DocumentFolder]) -> Bool {
        save(folders, to: foldersURL)
    }

    func loadDocuments() -> [ScanDocument] {
        load([ScanDocument].self, from: indexURL, fallback: [])
    }

    @discardableResult
    func saveDocuments(_ documents: [ScanDocument]) -> Bool {
        // Decode the previous index first. Corruption must not be overwritten by an empty library.
        let previous: [ScanDocument]
        do {
            previous = fileManager.fileExists(atPath: indexURL.path)
                ? try JSONDecoder().decode([ScanDocument].self, from: Data(contentsOf: indexURL)) : []
        } catch { reportFailure(); return false }
        guard save(documents, to: indexURL) else { return false }
        let imageNames = Set(documents.flatMap { $0.pages.flatMap { [$0.originalFileName, $0.editedFileName] } })
        let importedNames = Set(documents.compactMap(\.importedFileName))
        for document in previous {
            for page in document.pages {
                for name in Set([page.originalFileName, page.editedFileName]) where !imageNames.contains(name) {
                    deleteImage(fileName: name)
                }
            }
            if let name = document.importedFileName, !importedNames.contains(name) { deleteImportedFile(fileName: name) }
        }
        return true
    }

    private func save<T: Codable>(_ value: T, to url: URL) -> Bool {
        do {
            if fileManager.fileExists(atPath: url.path) {
                _ = try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
            }
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
            return true
        } catch { reportFailure(); return false }
    }

    func saveImage(_ image: UIImage) -> String? {
        let name = "\(UUID().uuidString).jpg"
        let url = imagesDirectory.appendingPathComponent(name)
        let normalized = normalizedImage(image)
        guard let data = normalized.jpegData(compressionQuality: 0.92) else { reportFailure(); return nil }
        do { try data.write(to: url, options: .atomic); return name }
        catch { reportFailure(); return nil }
    }

    func savePages(_ images: [UIImage]) -> [ScanPage]? {
        var pages: [ScanPage] = []
        for image in images {
            guard let name = saveImage(image) else {
                pages.forEach { deleteImage(fileName: $0.originalFileName) }
                return nil
            }
            pages.append(ScanPage(originalFileName: name, editedFileName: name))
        }
        return pages
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        let normalized: UIImage
        if image.imageOrientation == .up { normalized = image }
        else {
            let format = UIGraphicsImageRendererFormat()
            format.scale = image.scale
            normalized = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }
        return normalized
    }

    func loadImage(fileName: String) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data).map(normalizedImage)
    }

    func loadThumbnail(fileName: String, maxDimension: Int = 600) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(fileName)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    func deleteImage(fileName: String) {
        let url = imagesDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
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
            reportFailure()
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
