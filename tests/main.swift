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

// Portuguese invoice QR codes (Portaria 195/2020)
check(NIF.isValid("503742007") && NIF.isValid("PT 234 567 899") && NIF.isValid(NIF.finalConsumer), "Valid NIFs pass the mod-11 check")
check(!NIF.isValid("503742008") && !NIF.isValid("12345678") && !NIF.isValid("0123456789") && !NIF.isValid("50374200a"), "Wrong check digit, length or characters are rejected")
let qr = "A:503742007*B:234567899*C:PT*D:FT*E:N*F:20261023*G:FT 2026/10482*H:JJ3RBV7M-10482*I1:PT*I7:64.18*I8:14.75*N:14.75*O:78.93*Q:Ab1c*R:1234"
let invoice = FiscalInvoice.parse(qr)!
check(invoice.issuerNIF == "503742007" && invoice.documentNumber == "FT 2026/10482" && invoice.atcud == "JJ3RBV7M-10482", "QR identifiers are parsed")
check(invoice.taxableBase == Decimal(string: "64.18")! && invoice.vat == Decimal(string: "14.75")! && invoice.grossTotal == Decimal(string: "78.93")!, "QR amounts are parsed as exact decimals")
check(invoice.year == 2026 && invoice.amountsAreConsistent, "Issue year is read and amounts add up")
check(invoice.deductionStatus(userNIF: "234567899") == .counts, "Invoice to the user's NIF counts")
check(invoice.deductionStatus(userNIF: "503742007") == .otherNIF("234567899"), "Invoice to another NIF is flagged")
check(invoice.deductionStatus(userNIF: nil) == .unknown, "Without the user's NIF the status is unknown")
let simplified = FiscalInvoice.parse("A:509123457*B:999999990*C:PT*D:FS*E:N*F:20261023*G:FS A/88*H:0-88*I1:PT*I3:22.57*I4:1.35*N:1.35*O:23.92*Q:x*R:1")!
check(simplified.deductionStatus(userNIF: "234567899") == .noBuyerNIF && simplified.amountsAreConsistent, "Final-consumer receipts never count")
let mixed = FiscalInvoice.parse("A:501001239*B:234567899*C:PT*D:FR*E:N*F:20260310*G:FR 1/5*H:AB-5*I1:PT*I2:10.00*I3:20.00*I4:1.20*J1:PT-AC*J7:5.00*J8:0.80*N:2.00*O:37.00*Q:x*R:1")!
check(mixed.taxableBase == 25 && mixed.vat == 2 && mixed.exemptAmount == 10 && mixed.amountsAreConsistent, "Exempt, reduced-rate and Azores amounts are summed")
check(FiscalInvoice.parse(qr.replacingOccurrences(of: "O:78.93", with: "O:88.93"))?.amountsAreConsistent == false, "A misread total is detected")
check(FiscalInvoice.parse("https://example.com") == nil && FiscalInvoice.parse(qr.replacingOccurrences(of: "A:503742007", with: "A:503742008")) == nil, "Non-AT codes and invalid seller NIFs are ignored")
var credit = FiscalInvoice.parse(qr.replacingOccurrences(of: "D:FT", with: "D:NC"))!
credit.category = .health
var health = mixed
health.category = .health
let summary = ExpenseSummary(year: 2026, invoices: [invoice, simplified, health, credit], userNIF: "234567899")
check(summary.total == Decimal(string: "78.93")! + Decimal(string: "23.92")! + 37 - Decimal(string: "78.93")!, "Credit notes subtract from the year's total")
check(summary.lines.map(\.category) == [.generalFamily, .health] && summary.lines[1].count == 2 && summary.notCounting == 1, "Totals are grouped by category and non-counting invoices counted")
let csv = ExpenseSummary.csv(for: [("Luz; outubro", invoice), ("Old", FiscalInvoice.parse(qr.replacingOccurrences(of: "F:20261023", with: "F:20251023"))!)],
                             year: 2026, decimalComma: true, header: ["Data", "Título"], categoryName: { $0.rawValue })
check(csv == "Data;Título\n2026-10-23;\"Luz; outubro\";503742007;234567899;FT;FT 2026/10482;JJ3RBV7M-10482;generalFamily;64,18;14,75;78,93\n", "CSV keeps one year, quotes separators and uses decimal commas")
let withInvoice = ScanDocument(title: "fatura", fiscalInvoice: invoice)
let reloaded = try JSONDecoder().decode(ScanDocument.self, from: JSONEncoder().encode(withInvoice))
check(reloaded.fiscalInvoice == invoice, "Invoice data survives reload")
