import Foundation

/// Distinguishes a normal scanned/imported-image document (with page-editor
/// support) from a raw imported file that has no rendering pipeline and is
/// instead previewed and shared as-is.
enum DocumentKind: Codable, Equatable {
    case scanned
    case importedFile(originalFilename: String)

    private enum Kind: String, Codable {
        case scanned, importedFile
    }

    private enum CodingKeys: String, CodingKey {
        case kind, originalFilename
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .scanned:
            self = .scanned
        case .importedFile:
            let name = try container.decode(String.self, forKey: .originalFilename)
            self = .importedFile(originalFilename: name)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .scanned:
            try container.encode(Kind.scanned, forKey: .kind)
        case .importedFile(let originalFilename):
            try container.encode(Kind.importedFile, forKey: .kind)
            try container.encode(originalFilename, forKey: .originalFilename)
        }
    }
}

/// A saved multi-page document, the top-level unit shown in the documents list.
struct ScanDocument: Identifiable, Codable {
    let id: UUID
    var title: String
    var pages: [ScanPage]
    var createdAt: Date
    var updatedAt: Date
    var folderId: UUID?
    var tags: [String]
    var documentKind: DocumentKind
    /// File name inside the storage service's imported-files directory.
    /// Only set when `documentKind` is `.importedFile`.
    var importedFileName: String?

    init(
        id: UUID = UUID(),
        title: String,
        pages: [ScanPage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        folderId: UUID? = nil,
        tags: [String] = [],
        documentKind: DocumentKind = .scanned,
        importedFileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.pages = pages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folderId = folderId
        self.tags = tags
        self.documentKind = documentKind
        self.importedFileName = importedFileName
    }

    enum CodingKeys: String, CodingKey {
        case id, title, pages, createdAt, updatedAt, folderId, tags, documentKind, importedFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        pages = try container.decode([ScanPage].self, forKey: .pages)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        folderId = try container.decodeIfPresent(UUID.self, forKey: .folderId)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        // Documents saved before `documentKind` existed decode as `.scanned`.
        documentKind = try container.decodeIfPresent(DocumentKind.self, forKey: .documentKind) ?? .scanned
        importedFileName = try container.decodeIfPresent(String.self, forKey: .importedFileName)
    }

    var isImportedFile: Bool {
        if case .importedFile = documentKind { return true }
        return false
    }

    var pageCountDescription: String {
        pages.count == 1 ? L("document.page.singular") : String(format: L("document.page.plural"), pages.count)
    }

    /// What to show as the card/row subtitle: page count for scanned
    /// documents, or the "Imported File" badge for raw imported files.
    var subtitleDescription: String {
        isImportedFile ? L("document.importedFile") : pageCountDescription
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
