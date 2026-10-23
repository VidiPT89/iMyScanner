import UIKit
import Vision

/// One recognized line. `boundingBox` is normalized with Vision's
/// bottom-left origin (Y grows upward).
struct RecognizedLine {
    let text: String
    let boundingBox: CGRect
}

/// Extracts text from a scanned page image using the on-device Vision
/// framework text recognizer. No data leaves the device.
final class OCRService {
    static let shared = OCRService()

    func recognizeText(in image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let text = self.recognizeLines(in: cgImage).map(\.text).joined(separator: "\n")
            DispatchQueue.main.async { completion(text) }
        }
    }

    /// Synchronous recognition with line positions, for exports that already
    /// run off the main thread. Returns no lines when Vision fails.
    func recognizeLines(in cgImage: CGImage) -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["pt-PT", "en-US"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([request]) } catch { return [] }
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { RecognizedLine(text: $0.string, boundingBox: observation.boundingBox) }
        }
    }
}
