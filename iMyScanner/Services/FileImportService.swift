import UIKit
import PDFKit

/// Classifies files picked from the Files app (`UIDocumentPickerViewController`)
/// and prepares them for import: images are rendered like camera/photo pages,
/// PDFs are rasterized page-by-page through PDFKit so they flow through the
/// same `ScanPage` pipeline, and anything else is copied into storage as a
/// distinct "imported file" entry with no rendering pipeline of its own.
final class FileImportService {
    static let shared = FileImportService()

    private let storage = DocumentStorageService.shared
    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp", "gif"]

    /// The result of processing one batch of picked file URLs.
    struct ImportOutcome {
        /// Images from picked image files, combined into a single new
        /// document (mirrors the photo-library picker's behavior).
        var combinedImages: [UIImage] = []
        var hadFailures = false
        /// One entry per picked PDF: its display title and rendered pages.
        var pdfDocuments: [(title: String, images: [UIImage])] = []
        /// One entry per picked non-image, non-PDF file, already copied
        /// into storage: the stored file name and its original name.
        var importedFiles: [(storageName: String, originalName: String)] = []
    }

    func process(urls: [URL]) -> ImportOutcome {
        var outcome = ImportOutcome()

        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            let ext = url.pathExtension.lowercased()

            if ext == "pdf" {
                if let images = renderPDFPages(at: url), !images.isEmpty {
                    let title = url.deletingPathExtension().lastPathComponent
                    outcome.pdfDocuments.append((title: title, images: images))
                } else { outcome.hadFailures = true }
            } else if imageExtensions.contains(ext) {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    outcome.combinedImages.append(image)
                } else { outcome.hadFailures = true }
            } else if let storageName = storage.copyImportedFile(from: url) {
                outcome.importedFiles.append((storageName: storageName, originalName: url.lastPathComponent))
            } else { outcome.hadFailures = true }
        }

        return outcome
    }

    private func renderPDFPages(at url: URL) -> [UIImage]? {
        guard let document = PDFDocument(url: url), !document.isLocked else { return nil }
        var images: [UIImage] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { return nil }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else { return nil }

            let scale = min(2, 2400 / max(bounds.width, bounds.height))
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                context.cgContext.scaleBy(x: scale, y: scale)
                context.cgContext.translateBy(x: 0, y: bounds.size.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: context.cgContext)
            }
            images.append(image)
        }

        return images
    }
}
