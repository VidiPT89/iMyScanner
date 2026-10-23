import UIKit
import PDFKit

/// Builds exportable PDF files from a document's rendered page images.
final class PDFExportService {
    static let shared = PDFExportService()

    func generatePDF(for document: ScanDocument) -> URL? {
        let pdfDocument = PDFDocument()
        let storage = DocumentStorageService.shared

        for page in document.pages {
            guard let image = storage.loadImage(fileName: page.editedFileName),
                  let pdfPage = PDFPage(image: image) else { return nil }
            pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
        }

        guard pdfDocument.pageCount > 0 else { return nil }

        let exportDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do { try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true) }
        catch { return nil }

        let fileName = "\(sanitizedFileName(document.title)).pdf"
        let tempURL = exportDirectory.appendingPathComponent(fileName)
        guard pdfDocument.write(to: tempURL) else { return nil }
        return tempURL
    }

    func exportImages(for document: ScanDocument) -> [URL] {
        let storage = DocumentStorageService.shared
        var urls: [URL] = []
        let exportDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do { try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true) }
        catch { return [] }

        for (index, page) in document.pages.enumerated() {
            guard let image = storage.loadImage(fileName: page.editedFileName),
                  let data = image.jpegData(compressionQuality: 0.95) else { return [] }
            let name = "\(sanitizedFileName(document.title))_\(index + 1).jpg"
            let url = exportDirectory.appendingPathComponent(name)
            do {
                try data.write(to: url, options: .atomic)
                urls.append(url)
            } catch {
                return []
            }
        }
        return urls
    }

    private func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "Scan" : cleaned
    }
}
