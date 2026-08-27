import UIKit
import PDFKit

/// Builds exportable PDF files from a document's rendered page images.
final class PDFExportService {
    static let shared = PDFExportService()

    func generatePDF(for document: ScanDocument) -> URL? {
        let pdfDocument = PDFDocument()
        let storage = DocumentStorageService.shared

        for (index, page) in document.pages.enumerated() {
            guard let image = storage.loadImage(fileName: page.editedFileName),
                  let pdfPage = PDFPage(image: image) else { continue }
            pdfDocument.insert(pdfPage, at: index)
        }

        guard pdfDocument.pageCount > 0 else { return nil }

        let fileName = "\(sanitizedFileName(document.title)).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        guard pdfDocument.write(to: tempURL) else { return nil }
        return tempURL
    }

    func exportImages(for document: ScanDocument) -> [URL] {
        let storage = DocumentStorageService.shared
        var urls: [URL] = []

        for (index, page) in document.pages.enumerated() {
            guard let image = storage.loadImage(fileName: page.editedFileName),
                  let data = image.jpegData(compressionQuality: 0.95) else { continue }
            let name = "\(sanitizedFileName(document.title))_\(index + 1).jpg"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? data.write(to: url)
            urls.append(url)
        }
        return urls
    }

    private func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "Scan" : cleaned
    }
}
