import SwiftUI
import VisionKit
import PhotosUI
import UniformTypeIdentifiers

/// SwiftUI bridge around VNDocumentCameraViewController, giving automatic
/// edge detection and multi-page capture out of the box.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onFinish: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onFinish: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            onFinish(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onCancel()
        }
    }
}

func isDocumentScanningAvailable() -> Bool {
    VNDocumentCameraViewController.isSupported
}

/// Fallback capture path used whenever live document scanning is not
/// available (Simulator, or a device without a usable camera). Lets the
/// user pick one or more existing photos from their library, which are
/// then fed into the same page-import pipeline as a live scan.
struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    var onFinish: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 0
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onFinish: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                onCancel()
                return
            }

            let providers = results.map { $0.itemProvider }
            var images = [UIImage?](repeating: nil, count: providers.count)
            let group = DispatchGroup()

            for (index, provider) in providers.enumerated() where provider.canLoadObject(ofClass: UIImage.self) {
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    images[index] = object as? UIImage
                    group.leave()
                }
            }

            group.notify(queue: .main) { [onFinish, onCancel] in
                let loaded = images.compactMap { $0 }
                if loaded.isEmpty {
                    onCancel()
                } else {
                    onFinish(loaded)
                }
            }
        }
    }
}

/// "Browse Files" source: the system Files app, which already surfaces
/// iCloud Drive, "On My iPhone", and any other cloud providers the user has
/// installed (Google Drive, Dropbox, etc.) with no custom SDK integration.
struct DocumentImportPickerView: UIViewControllerRepresentable {
    var onFinish: ([URL]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var contentTypes: [UTType] = [.pdf, .image, .plainText]
        for identifier in ["com.microsoft.word.doc", "org.openxmlformats.wordprocessingml.document"] {
            if let type = UTType(identifier) {
                contentTypes.append(type)
            }
        }
        for ext in ["doc", "docx"] {
            if let type = UTType(filenameExtension: ext), !contentTypes.contains(type) {
                contentTypes.append(type)
            }
        }

        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        controller.allowsMultipleSelection = true
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFinish: ([URL]) -> Void
        let onCancel: () -> Void

        init(onFinish: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if urls.isEmpty {
                onCancel()
            } else {
                onFinish(urls)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
