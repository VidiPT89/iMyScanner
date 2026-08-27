# 📄 iMyScanner

> An elegant iOS document scanner with manual and on-device AI-powered editing.

[Report Bug](https://github.com/VidiPT89/iMyScanner/issues) · [Request Feature](https://github.com/VidiPT89/iMyScanner/issues)

## ✨ Features

- ✅ Multi-page document scanning with automatic edge detection (VisionKit)
- ✅ On-device text recognition (OCR) with copy-to-clipboard
- ✅ Manual crop with draggable corner handles, 90° and free rotation
- ✅ Non-destructive filters: Original, Black & White, Grayscale, Auto Enhance
- ✅ Page reordering and deletion within a document
- ✅ Export to PDF or images, with the native share sheet
- ✅ Document management: rename, delete, grid/list view
- ✅ Dark mode (default), Light mode, or follow system, with in-app toggle
- ✅ Full localization: Portuguese (Portugal) and English, switchable in-app
- ✅ Onboarding flow for first-time users

## 🛠️ Tech Stack

| Category | Technology |
|---|---|
| Language | Swift |
| UI | SwiftUI |
| Architecture | MVVM |
| Scanning | VisionKit (`VNDocumentCameraViewController`) |
| OCR | Vision (`VNRecognizeTextRequest`) |
| Image Processing | Core Image |
| PDF Export | PDFKit |
| Minimum Target | iOS 16 |

## 🚀 Quick Start

### Prerequisites

- macOS with Xcode 15 or later
- A physical iOS device is recommended for testing (VisionKit scanning requires a real camera)

### Installation

1. Clone the repository
   ```bash
   git clone https://github.com/VidiPT89/iMyScanner.git
   cd iMyScanner
   ```
2. Open the project in Xcode
   ```bash
   open iMyScanner.xcodeproj
   ```
3. Select your development Team under Signing & Capabilities
4. Build and run on a physical device (`⌘R`)

## 📖 Usage

1. Tap the scan button and capture your document — edges are detected automatically
2. Edit each page: crop, rotate, or apply a filter
3. Extract text from any page with the OCR action
4. Export the finished document as a PDF or images, or share it directly

## 🧪 Testing

```bash
xcodebuild -project iMyScanner.xcodeproj -scheme iMyScanner -destination "generic/platform=iOS Simulator" build
```

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## 👨‍💻 Author

**David Arsénio Martins**
🌐 Website: [ividi.dev](https://ividi.dev)
🐙 GitHub: [@VidiPT89](https://github.com/VidiPT89)

## 🤝 Contributing

Issues and feature requests are welcome. Feel free to check the [issues page](https://github.com/VidiPT89/iMyScanner/issues).

---

<p align="center">Developed by <a href="https://ividi.dev">David Arsénio Martins</a></p>
<p align="center">If you like this project, consider giving it a ⭐</p>
