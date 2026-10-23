import UIKit
import Vision

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
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["pt-PT", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let text: String
            do {
                try handler.perform([request])
                text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            } catch { text = "" }
            DispatchQueue.main.async { completion(text) }
        }
    }
}
