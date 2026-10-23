import UIKit

// Runs inside the iOS Simulator (`xcrun simctl spawn`) against the real export and
// import services, since PDF rendering, Vision OCR and PDFKit need the iOS SDK.
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
    print("PASS: \(message)")
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let storage = DocumentStorageService.shared

// A 1240x1754 page (A4 at 150 dpi) with one line of large text.
let format = UIGraphicsImageRendererFormat()
format.scale = 1
let pageImage = UIGraphicsImageRenderer(size: CGSize(width: 1240, height: 1754), format: format).image { context in
    UIColor.white.setFill()
    context.fill(CGRect(x: 0, y: 0, width: 1240, height: 1754))
    ("INVOICE 2026" as NSString).draw(at: CGPoint(x: 120, y: 200), withAttributes: [.font: UIFont.systemFont(ofSize: 96)])
}
let name = storage.saveImage(pageImage)!
let blank = storage.saveImage(UIGraphicsImageRenderer(size: CGSize(width: 1240, height: 1754), format: format).image { context in
    UIColor.white.setFill()
    context.fill(CGRect(x: 0, y: 0, width: 1240, height: 1754))
})!
var document = ScanDocument(title: "Fatura março", pages: [
    ScanPage(originalFileName: name, editedFileName: name),
    ScanPage(originalFileName: blank, editedFileName: blank)
])

let pdf = PDFExportService.shared.generatePDF(for: document)!
check(pdf.lastPathComponent == "Fatura março.pdf", "PDF keeps accented document name")
try FileManager.default.copyItem(at: pdf, to: output.appendingPathComponent("export.pdf"))

let texts: [String?] = document.pages.map { page in
    storage.loadImage(fileName: page.editedFileName)?.cgImage.map {
        OCRService.shared.recognizeLines(in: $0).map(\.text).joined(separator: "\n")
    }
}
check(texts[0]?.contains("INVOICE") == true, "OCR recognizes page text for Word export")
let docx = DocxExportService.shared.generateDocx(for: document, pageTexts: texts)!
try FileManager.default.copyItem(at: docx, to: output.appendingPathComponent("export.docx"))

check(document.movePage(id: document.pages[1].id, by: -1) && document.pages[0].editedFileName == blank, "Page moves earlier")
check(!document.movePage(id: document.pages[0].id, by: -1), "First page cannot move earlier")

// Import the exported two-page PDF back: pages are written to storage as they render.
let outcome = FileImportService.shared.process(urls: [output.appendingPathComponent("export.pdf")])
check(!outcome.hadFailures && outcome.pdfDocuments.first?.pages.count == 2, "Imported PDF yields two saved pages")
check(outcome.pdfDocuments[0].pages.allSatisfy { storage.loadThumbnail(fileName: $0.editedFileName) != nil }, "Imported pages are readable from storage")
