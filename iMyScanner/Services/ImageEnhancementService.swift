import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Applies non-destructive, entirely on-device CoreImage filters used to
/// simulate "AI enhancement" without any network or ML model dependency.
final class ImageEnhancementService {
    static let shared = ImageEnhancementService()

    private let context = CIContext()

    func applyFilter(_ filter: PageFilter, to image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let output: CIImage

        switch filter {
        case .original:
            output = ciImage
        case .grayscale:
            let mono = CIFilter.colorControls()
            mono.inputImage = ciImage
            mono.saturation = 0
            mono.contrast = 1.05
            output = mono.outputImage ?? ciImage
        case .blackAndWhite:
            let bw = CIFilter.colorMonochrome()
            bw.inputImage = ciImage
            bw.color = CIColor(red: 1, green: 1, blue: 1)
            bw.intensity = 1
            let contrast = CIFilter.colorControls()
            contrast.inputImage = bw.outputImage
            contrast.contrast = 1.4
            contrast.brightness = 0.05
            output = contrast.outputImage ?? ciImage
        case .enhance:
            let auto = ciImage.autoAdjustmentFilters(options: [.enhance: true])
            var result = ciImage
            for f in auto {
                f.setValue(result, forKey: kCIInputImageKey)
                if let out = f.value(forKey: kCIOutputImageKey) as? CIImage {
                    result = out
                }
            }
            let boost = CIFilter.colorControls()
            boost.inputImage = result
            boost.contrast = 1.12
            boost.brightness = 0.03
            boost.saturation = 1.05
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = boost.outputImage
            sharpen.sharpness = 0.4
            output = sharpen.outputImage ?? result
        }

        guard let cgImage = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    func rotate(_ image: UIImage, degrees: Double) -> UIImage {
        guard degrees.truncatingRemainder(dividingBy: 360) != 0 else { return image }
        let radians = CGFloat(degrees * .pi / 180)
        let rotatedSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        let renderer = UIGraphicsImageRenderer(size: rotatedSize)
        return renderer.image { _ in
            guard let ctx = UIGraphicsGetCurrentContext() else { return }
            ctx.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            ctx.rotate(by: radians)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }

    func crop(_ image: UIImage, to cropRect: CropRect) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let minX = min(cropRect.topLeft.x, cropRect.bottomLeft.x) * width
        let maxX = max(cropRect.topRight.x, cropRect.bottomRight.x) * width
        let minY = min(cropRect.topLeft.y, cropRect.topRight.y) * height
        let maxY = max(cropRect.bottomLeft.y, cropRect.bottomRight.y) * height

        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard let cropped = cgImage.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
