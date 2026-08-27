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
    /// Auto-detected quad offered as the initial crop the first time the
    /// crop tool opens on a page with no crop applied yet. `nil` while
    /// detection hasn't run or found nothing usable.
    @Published var detectedCrop: CropRect?
    @Published var isDetectingEdges = false
    /// True once auto-detection has been attempted for this page, so it
    /// only ever runs once automatically (the user can still re-run it
    /// manually via the crop tool's "Auto" button).
    private var hasAttemptedAutoDetection = false

    private let originalImage: UIImage?
    /// Downscaled copy of `originalImage` used for the interactive preview only.
    /// Camera scans are commonly 12MP+; running crop/rotate/filter at full
    /// resolution on every button tap can spike memory enough to be jetsam-killed
    /// on a real device. Full resolution is only ever touched once, in
    /// `finalizedPage()`, when the user actually confirms the edit.
    private let previewSourceImage: UIImage?
    private let storage = DocumentStorageService.shared
    private let enhancement = ImageEnhancementService.shared

    private static let maxPreviewDimension: CGFloat = 1600

    init(page: ScanPage) {
        self.page = page
        let loaded = storage.loadImage(fileName: page.originalFileName)
        self.originalImage = loaded
        self.previewSourceImage = loaded.map { Self.downscaled($0, maxDimension: Self.maxPreviewDimension) }
        self.recognizedText = page.recognizedText ?? ""
        renderPreview()
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > maxDimension else { return image }
        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
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

    /// Kicks off automatic edge detection the first time the crop tool
    /// opens for this page, if no crop has been applied yet. Never
    /// overrides a crop the user already set (manually or from a prior
    /// detection run).
    func autoDetectEdgesIfNeeded() {
        guard !hasAttemptedAutoDetection, page.cropRect == nil else { return }
        hasAttemptedAutoDetection = true
        runEdgeDetection()
    }

    /// Re-runs detection on demand (the crop tool's "Auto" button), even
    /// if it already ran or a crop already exists.
    func runEdgeDetection() {
        guard let source = previewSourceImage else { return }
        isDetectingEdges = true
        DocumentEdgeDetectionService.shared.detectDocumentQuad(in: source) { [weak self] crop in
            guard let self else { return }
            self.isDetectingEdges = false
            self.detectedCrop = crop
        }
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
        guard let base = previewSourceImage else { return }
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
