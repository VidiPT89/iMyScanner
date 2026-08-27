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

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async { completion("") }
                return
            }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            DispatchQueue.main.async { completion(lines.joined(separator: "\n")) }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["pt-PT", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}
