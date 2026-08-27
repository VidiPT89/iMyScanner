import Foundation

/// Builds a minimal, valid Word (.docx) file from a document's OCR'd text,
/// one page of text per scanned page, in reading order.
///
/// A `.docx` is simply a ZIP archive containing a handful of Office Open XML
/// parts. Since no external archiving dependency is available, this writes
/// the required ZIP structure by hand (uncompressed "stored" entries, which
/// is a fully valid ZIP variant that Word and Pages open without issue).
///
/// This first version is text-only: it embeds the recognized text per page
/// but not the page images themselves. Embedding the scanned images as
/// inline `w:drawing` elements referencing `word/media/*` parts would be a
/// reasonable follow-up if a richer export is needed later.
final class DocxExportService {
    static let shared = DocxExportService()

    func generateDocx(for document: ScanDocument) -> URL? {
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
        """

        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
        """

        let documentXML = buildDocumentXML(for: document)

        let entries: [(name: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rootRels.utf8)),
            ("word/document.xml", Data(documentXML.utf8))
        ]

        guard let zipData = ZipArchiveBuilder.build(entries: entries) else { return nil }

        let fileName = "\(sanitizedFileName(document.title)).docx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try zipData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func buildDocumentXML(for document: ScanDocument) -> String {
        var body = ""
        for (index, page) in document.pages.enumerated() {
            let text = page.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let heading = String(format: L("docx.pageHeading"), index + 1)
            body += paragraph(text: heading, bold: true)
            if text.isEmpty {
                body += paragraph(text: L("docx.noText"), bold: false)
            } else {
                for line in text.components(separatedBy: .newlines) {
                    body += paragraph(text: line, bold: false)
                }
            }
            if index < document.pages.count - 1 {
                body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>\(body)</w:body></w:document>
        """
    }

    private func paragraph(text: String, bold: Bool) -> String {
        let escaped = escapeXML(text)
        let runProps = bold ? "<w:rPr><w:b/></w:rPr>" : ""
        return "<w:p><w:r>\(runProps)<w:t xml:space=\"preserve\">\(escaped)</w:t></w:r></w:p>"
    }

    private func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "Scan" : cleaned
    }
}
