import UIKit
import CoreText

/// Builds exportable PDF files from a document's rendered page images.
final class PDFExportService {
    static let shared = PDFExportService()

    /// A4 width in points. Each page keeps its scan's aspect ratio and full
    /// image resolution; this only sets its physical size (a 12MP scan placed
    /// at one point per pixel used to make a page over a metre tall).
    static let pageWidth: CGFloat = 595

    /// Renders a searchable PDF: every page image with its OCR text drawn on
    /// top in invisible mode, so viewers can search and select the text while
    /// showing only the scan.
    func generatePDF(for document: ScanDocument) -> URL? {
        guard !document.pages.isEmpty,
              let exportDirectory = makeExportDirectory() else { return nil }
        let storage = DocumentStorageService.shared
        let url = exportDirectory.appendingPathComponent("\(document.exportBaseName).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: Self.pageWidth, height: Self.pageWidth * 1.414))
        var missingPage = false

        do {
            try renderer.writePDF(to: url) { context in
                for page in document.pages {
                    guard let image = storage.loadImage(fileName: page.editedFileName),
                          image.size.width > 0, image.size.height > 0 else {
                        missingPage = true
                        return
                    }
                    let bounds = CGRect(x: 0, y: 0, width: Self.pageWidth,
                                        height: (Self.pageWidth * image.size.height / image.size.width).rounded())
                    context.beginPage(withBounds: bounds, pageInfo: [:])
                    image.draw(in: bounds)
                    if let cgImage = image.cgImage {
                        drawInvisibleText(OCRService.shared.recognizeLines(in: cgImage), in: context.cgContext, pageSize: bounds.size)
                    }
                }
            }
        } catch { return nil }
        return missingPage ? nil : url
    }

    func exportImages(for document: ScanDocument) -> [URL] {
        let storage = DocumentStorageService.shared
        var urls: [URL] = []
        guard let exportDirectory = makeExportDirectory() else { return [] }

        for (index, page) in document.pages.enumerated() {
            guard let image = storage.loadImage(fileName: page.editedFileName),
                  let data = image.jpegData(compressionQuality: 0.95) else { return [] }
            let name = "\(document.exportBaseName)_\(index + 1).jpg"
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

    private func makeExportDirectory() -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { return nil }
        return directory
    }

    /// Draws each line stretched over its recognized box. `pageSize` is in the
    /// renderer's UIKit coordinates (top-left origin, Y down).
    private func drawInvisibleText(_ lines: [RecognizedLine], in cgContext: CGContext, pageSize: CGSize) {
        cgContext.saveGState()
        cgContext.setTextDrawingMode(.invisible)
        for line in lines where !line.text.isEmpty {
            let box = CGRect(x: line.boundingBox.minX * pageSize.width,
                             y: (1 - line.boundingBox.maxY) * pageSize.height,
                             width: line.boundingBox.width * pageSize.width,
                             height: line.boundingBox.height * pageSize.height)
            guard box.width > 0, box.height > 0 else { continue }
            let font = CTFontCreateWithName("Helvetica" as CFString, box.height * 0.85, nil)
            let attributed = NSAttributedString(string: line.text, attributes: [.font: font])
            let ctLine = CTLineCreateWithAttributedString(attributed)
            var descent: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(ctLine, nil, &descent, nil))
            guard width > 0 else { continue }

            cgContext.saveGState()
            cgContext.textMatrix = .identity
            // Flip to CoreText's Y-up space at the line's baseline, then stretch to the box width.
            cgContext.translateBy(x: box.minX, y: box.maxY - descent)
            cgContext.scaleBy(x: box.width / width, y: -1)
            cgContext.textPosition = .zero
            CTLineDraw(ctLine, cgContext)
            cgContext.restoreGState()
        }
        cgContext.restoreGState()
    }
}
