import Foundation

// The host tests exercise the real models/exporter without loading UIKit or SwiftUI.
func L(_ key: String) -> String { key == "docx.pageHeading" ? "Page %d" : key }
func check(_ value: @autoclosure () -> Bool, _ message: String) {
    precondition(value(), message)
    print("PASS: \(message)")
}
let page = ScanPage(originalFileName: "original.jpg", editedFileName: "edited.jpg", recognizedText: "A & B < C\nPortuguês: ação")
let document = ScanDocument(title: "test/document", pages: [page], tags: ["test"])
let encoded = try JSONEncoder().encode(document)
let decoded = try JSONDecoder().decode(ScanDocument.self, from: encoded)
check(decoded.pages == document.pages && decoded.tags == document.tags, "Document round trip preserves pages and tags")
var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
for key in ["documentKind", "importedFileName", "tags", "folderId"] { legacy.removeValue(forKey: key) }
let oldDocument = try JSONDecoder().decode(ScanDocument.self, from: JSONSerialization.data(withJSONObject: legacy))
check(!oldDocument.isImportedFile && oldDocument.tags.isEmpty && oldDocument.folderId == nil, "Legacy index remains readable")
let imported = ScanDocument(title: "contract", documentKind: .importedFile(originalFilename: "contract.docx"), importedFileName: "stored.docx")
let importedCopy = try JSONDecoder().decode(ScanDocument.self, from: JSONEncoder().encode(imported))
check(importedCopy.isImportedFile && importedCopy.importedFileName == "stored.docx", "Imported file metadata survives reload")
let emptyZip = ZipArchiveBuilder.build(entries: [])!
check(emptyZip.count == 22, "Empty ZIP has a valid end record")
check(ZipArchiveBuilder.build(entries: [(String(repeating: "a", count: 65536), Data())]) == nil, "Oversized ZIP filename is rejected without trapping")
let first = DocxExportService.shared.generateDocx(for: document)!
let second = DocxExportService.shared.generateDocx(for: document)!
check(first != second, "Equal document names do not overwrite previous shares")
check(FileManager.default.fileExists(atPath: first.path), "Previous export remains available")
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.copyItem(at: first, to: output.appendingPathComponent("document.docx"))
let unicodeZip = ZipArchiveBuilder.build(entries: [("ação.txt", Data("ação".utf8))])!
try unicodeZip.write(to: output.appendingPathComponent("unicode.zip"))
for url in [first, second] { try FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
check(ScanDocument(title: "Fatura março: 2/3").exportBaseName == "Fatura março- 2-3", "Export names keep accents and replace unsafe characters")
check(ScanDocument(title: "  ").exportBaseName == "Scan", "Blank titles export as Scan")
