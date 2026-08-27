import Foundation

/// A saved multi-page document, the top-level unit shown in the documents list.
struct ScanDocument: Identifiable, Codable {
    let id: UUID
    var title: String
    var pages: [ScanPage]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        pages: [ScanPage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.pages = pages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var pageCountDescription: String {
        pages.count == 1 ? L("document.page.singular") : String(format: L("document.page.plural"), pages.count)
    }
}

extension ScanDocument: Hashable {
    static func == (lhs: ScanDocument, rhs: ScanDocument) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
