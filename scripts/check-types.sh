#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/imyscanner-types.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -typecheck -swift-version 6 -target arm64-apple-ios16.0-simulator -sdk "$sdk" -module-cache-path "$check_dir/cache" \
  iMyScanner/Models/*.swift \
  iMyScanner/Services/DocumentStorageService.swift iMyScanner/Services/DocxExportService.swift \
  iMyScanner/Services/ZipArchiveBuilder.swift iMyScanner/Services/LocalizationManager.swift \
  iMyScanner/Services/PDFExportService.swift iMyScanner/Services/ImageEnhancementService.swift \
  iMyScanner/Services/OCRService.swift iMyScanner/Services/DocumentEdgeDetectionService.swift \
  iMyScanner/Services/FileImportService.swift iMyScanner/Services/FiscalQRService.swift iMyScanner/ViewModels/*.swift iMyScanner/Theme/ThemeManager.swift
for source in iMyScanner/App/*.swift iMyScanner/Views/*.swift iMyScanner/Services/ScannerCoordinator.swift; do
  xcrun swiftc -frontend -parse "$source"
done
