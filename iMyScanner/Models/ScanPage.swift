import Foundation
import CoreGraphics

enum PageFilter: String, Codable, CaseIterable {
    case original
    case blackAndWhite
    case grayscale
    case enhance

    var titleKey: String {
        switch self {
        case .original: return "filter.original"
        case .blackAndWhite: return "filter.blackAndWhite"
        case .grayscale: return "filter.grayscale"
        case .enhance: return "filter.enhance"
        }
    }
}

/// A single scanned page. `originalFileName` always holds the untouched
/// capture so filters and crops remain non-destructive; `editedFileName`
/// holds the current rendered result shown in lists and exports.
struct ScanPage: Identifiable, Codable, Equatable {
    let id: UUID
    var originalFileName: String
    var editedFileName: String
    var filter: PageFilter
    var rotationDegrees: Double
    var cropRect: CropRect?
    var createdAt: Date
    var recognizedText: String?

    init(
        id: UUID = UUID(),
        originalFileName: String,
        editedFileName: String,
        filter: PageFilter = .original,
        rotationDegrees: Double = 0,
        cropRect: CropRect? = nil,
        createdAt: Date = Date(),
        recognizedText: String? = nil
    ) {
        self.id = id
        self.originalFileName = originalFileName
        self.editedFileName = editedFileName
        self.filter = filter
        self.rotationDegrees = rotationDegrees
        self.cropRect = cropRect
        self.createdAt = createdAt
        self.recognizedText = recognizedText
    }
}

/// Normalized (0...1) crop corners, stored so a crop can be re-applied to
/// the original image at any resolution and re-edited later.
struct CropRect: Codable, Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint

    static var fullFrame: CropRect {
        CropRect(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: 1, y: 0),
            bottomLeft: CGPoint(x: 0, y: 1),
            bottomRight: CGPoint(x: 1, y: 1)
        )
    }
}
