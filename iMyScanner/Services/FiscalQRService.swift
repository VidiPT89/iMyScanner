import UIKit
import Vision
import CoreImage

/// Finds the AT invoice QR code on scanned pages with the on-device Vision
/// barcode detector. Nothing leaves the device.
final class FiscalQRService: Sendable {
    static let shared = FiscalQRService()

    /// UserDefaults key for the user's own NIF, used to check whether an invoice
    /// counts towards their IRS deductions.
    static let userNIFKey = "fiscal.nif"

    static var userNIF: String? {
        UserDefaults.standard.string(forKey: userNIFKey).flatMap { NIF.isValid($0) ? NIF.normalized($0) : nil }
    }

    /// Synchronous; call it off the main thread. Returns the first page's invoice.
    func detectInvoice(in images: [CGImage]) -> FiscalInvoice? {
        for image in images {
            if let invoice = payloads(in: image).lazy.compactMap(FiscalInvoice.parse).first { return invoice }
        }
        return nil
    }

    /// Loads page images from storage. Synchronous; call it off the main thread.
    /// Long documents only have their first two and last pages checked: the code is
    /// printed on the first page, or on the last one of a multi-page invoice.
    func detectInvoice(in pages: [ScanPage], storage: DocumentStorageService) -> FiscalInvoice? {
        let candidates = pages.count <= 3 ? pages : Array(pages.prefix(2)) + [pages[pages.count - 1]]
        for page in candidates {
            guard let image = storage.loadImage(fileName: page.editedFileName)?.cgImage else { continue }
            if let invoice = detectInvoice(in: [image]) { return invoice }
        }
        return nil
    }

    /// Vision first; Core Image's QR detector as a fallback when Vision finds nothing
    /// or can't run at all (it fails with "Could not create inference context" in the Simulator).
    private func payloads(in image: CGImage) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let found = ((try? handler.perform([request])) != nil ? request.results ?? [] : []).compactMap(\.payloadStringValue)
        if !found.isEmpty { return found }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return (detector?.features(in: CIImage(cgImage: image)) ?? []).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }
}

/// Formatting shared by the invoice card, the Expenses screen and default titles.
enum InvoiceFormat {
    /// Follows the in-app language rather than the device region.
    static var locale: Locale { Locale(identifier: L("format.locale")) }

    static func euros(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = locale
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value) €"
    }

    static func date(_ invoice: FiscalInvoice) -> String {
        guard let date = invoice.date else { return invoice.issueDate }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// "123 456 789", the way NIFs are usually printed.
    static func nif(_ value: String) -> String {
        let digits = NIF.normalized(value)
        guard digits.count == 9 else { return digits }
        return [digits.prefix(3), digits.dropFirst(3).prefix(3), digits.suffix(3)].joined(separator: " ")
    }

    static func defaultTitle(for invoice: FiscalInvoice) -> String {
        String(format: L("invoice.defaultTitle"), euros(invoice.grossTotal), date(invoice))
    }
}
