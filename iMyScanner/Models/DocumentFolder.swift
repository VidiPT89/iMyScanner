import Foundation

/// A user-created folder used to organize documents. A document belongs to
/// at most one folder (or none, meaning it shows under "All Documents").
/// Deleting a folder never deletes its documents — they simply lose their
/// folder assignment and fall back to "All Documents".
struct DocumentFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
