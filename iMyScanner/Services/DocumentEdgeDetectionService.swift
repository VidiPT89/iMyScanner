import UIKit
import Vision

/// Detects the most likely document quadrilateral in a page image using
/// Vision's built-in rectangle detector. Fully on-device, no network access
/// and no bundled ML model download. Used to seed the crop tool with a
/// sensible initial crop for pages that never went through VisionKit's own
/// scan-time edge detection (photo-library imports, "Browse Files" imports).
final class DocumentEdgeDetectionService {
    static let shared = DocumentEdgeDetectionService()

    /// Runs detection off the main thread and returns the result on the
    /// main thread. `image` should be a reasonably small preview-sized
    /// image; Vision's cost scales with pixel count and this is only ever
    /// used to seed an initial crop, not to produce final geometry.
    func detectDocumentQuad(in image: UIImage, completion: @escaping (CropRect?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNDetectRectanglesRequest()
            request.minimumConfidence = 0.7
            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 1.0
            request.quadratureTolerance = 25
            request.minimumSize = 0.2
            request.maximumObservations = 4

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let results = request.results as? [VNRectangleObservation],
                  let best = results.max(by: { $0.confidence < $1.confidence }) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Vision reports normalized points with a bottom-left origin
            // (Y grows upward). The app's CropRect uses a top-left origin
            // (Y grows downward, matching UIKit), so Y must be flipped.
            let cropRect = CropRect(
                topLeft: CGPoint(x: best.topLeft.x, y: 1 - best.topLeft.y),
                topRight: CGPoint(x: best.topRight.x, y: 1 - best.topRight.y),
                bottomLeft: CGPoint(x: best.bottomLeft.x, y: 1 - best.bottomLeft.y),
                bottomRight: CGPoint(x: best.bottomRight.x, y: 1 - best.bottomRight.y)
            )

            DispatchQueue.main.async { completion(cropRect) }
        }
    }
}
