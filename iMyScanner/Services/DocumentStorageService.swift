import Foundation
import UIKit
import Combine
import ImageIO

/// Reads and writes documents and their page images to the app's
/// Documents directory. All storage is local; nothing ever leaves the device.
///
/// `@unchecked Sendable`: background imports and exports call into this
/// service. Its stored properties are immutable after `init` apart from main-queue-only
/// state (`operationFailed`, `didRemoveOrphans`), and `NSCache` is thread-safe.
final class DocumentStorageService: ObservableObject, @unchecked Sendable {
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
    private let thumbnailCache = NSCache<NSString, UIImage>()
    /// Main-thread only (see `removeOrphanedFiles()`).
    private var didRemoveOrphans = false

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

    /// Deletes page images and imported files no document references, e.g. left
    /// behind by a crash between writing an image and saving the index. Reads
    /// the index strictly and does nothing if it is missing or unreadable, so a
    /// corrupt index can never wipe the library. Only files older than a day are
    /// touched; call it at launch, before any import can start.
    func removeOrphanedFiles() {
        // Once per launch: the root view is rebuilt on a language change, and an
        // import could be in flight by then.
        guard !didRemoveOrphans else { return }
        didRemoveOrphans = true
        guard let data = try? Data(contentsOf: indexURL),
              let documents = try? JSONDecoder().decode([ScanDocument].self, from: data) else { return }
        let referenced = Set(documents.flatMap { $0.pages.flatMap { [$0.originalFileName, $0.editedFileName] } })
            .union(documents.compactMap(\.importedFileName))
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for directory in [imagesDirectory, importedFilesDirectory] {
            let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for file in files where !referenced.contains(file.lastPathComponent) {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let modified, modified < cutoff { try? fileManager.removeItem(at: file) }
            }
        }
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

    /// Page files are never rewritten in place (edits save a new name), so a
    /// cached thumbnail can never go stale.
    func loadThumbnail(fileName: String, maxDimension: Int = 600) -> UIImage? {
        let key = "\(fileName)#\(maxDimension)" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        let url = imagesDirectory.appendingPathComponent(fileName)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
              ] as CFDictionary) else { return nil }
        let thumbnail = UIImage(cgImage: image)
        thumbnailCache.setObject(thumbnail, forKey: key)
        return thumbnail
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
