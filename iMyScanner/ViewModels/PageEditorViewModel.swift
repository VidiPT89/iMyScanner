import SwiftUI
import Combine

@MainActor
final class PageEditorViewModel: ObservableObject {
    @Published var page: ScanPage
    @Published var previewImage: UIImage?
    @Published var isCropping = false
    @Published var recognizedText: String = ""
    @Published var isRecognizingText = false
    @Published var showTextSheet = false

    private let originalImage: UIImage?
    private let storage = DocumentStorageService.shared
    private let enhancement = ImageEnhancementService.shared

    init(page: ScanPage) {
        self.page = page
        self.originalImage = storage.loadImage(fileName: page.originalFileName)
        self.recognizedText = page.recognizedText ?? ""
        renderPreview()
    }

    func selectFilter(_ filter: PageFilter) {
        page.filter = filter
        renderPreview()
    }

    func rotate90() {
        page.rotationDegrees = (page.rotationDegrees + 90).truncatingRemainder(dividingBy: 360)
        renderPreview()
    }

    func applyFreeRotation(_ degrees: Double) {
        page.rotationDegrees = degrees.truncatingRemainder(dividingBy: 360)
        renderPreview()
    }

    func applyCrop(_ cropRect: CropRect) {
        page.cropRect = cropRect
        renderPreview()
    }

    func resetCrop() {
        page.cropRect = nil
        renderPreview()
    }

    func extractText(completion: @escaping () -> Void = {}) {
        guard let image = previewImage else { return }
        isRecognizingText = true
        OCRService.shared.recognizeText(in: image) { [weak self] text in
            guard let self else { return }
            self.recognizedText = text
            self.page.recognizedText = text
            self.isRecognizingText = false
            self.showTextSheet = true
            completion()
        }
    }

    func finalizedPage() -> ScanPage {
        guard let base = originalImage else { return page }
        var working = base
        if let crop = page.cropRect {
            working = enhancement.crop(working, to: crop)
        }
        if page.rotationDegrees != 0 {
            working = enhancement.rotate(working, degrees: page.rotationDegrees)
        }
        working = enhancement.applyFilter(page.filter, to: working)
        let fileName = storage.saveImage(working)
        page.editedFileName = fileName
        return page
    }

    private func renderPreview() {
        guard let base = originalImage else { return }
        var working = base
        if let crop = page.cropRect {
            working = enhancement.crop(working, to: crop)
        }
        if page.rotationDegrees != 0 {
            working = enhancement.rotate(working, degrees: page.rotationDegrees)
        }
        working = enhancement.applyFilter(page.filter, to: working)
        previewImage = working
    }
}
