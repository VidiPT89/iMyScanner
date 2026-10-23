#!/bin/sh
# Builds tests/exports/main.swift with the real export/import services for the iOS Simulator and
# runs it on a booted simulator, then checks the PDF's text layer with poppler's pdftotext.
set -eu
cd "$(dirname "$0")/.."
command -v pdftotext >/dev/null || { echo "pdftotext not found (brew install poppler)"; exit 1; }
device=$(xcrun simctl list devices booted | grep -m1 -oE '[0-9A-F-]{36}') || { echo "Boot a simulator first"; exit 1; }
work=$(mktemp -d /tmp/imyscanner-exports.XXXXXX)
trap 'rm -rf "$work"' EXIT
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator swiftc -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$sdk" -module-cache-path "$work/cache" \
  iMyScanner/Models/*.swift iMyScanner/Services/DocumentStorageService.swift iMyScanner/Services/OCRService.swift \
  iMyScanner/Services/PDFExportService.swift iMyScanner/Services/DocxExportService.swift \
  iMyScanner/Services/ZipArchiveBuilder.swift iMyScanner/Services/LocalizationManager.swift \
  iMyScanner/Services/FileImportService.swift tests/exports/main.swift -o "$work/exports"
xcrun simctl spawn "$device" "$work/exports" "$work"
pdfinfo "$work/export.pdf" | grep -q "595 x 842" && echo "PASS: PDF pages use A4 width"
pdftotext "$work/export.pdf" - | grep -q "INVOICE 2026" && echo "PASS: PDF text layer is searchable"
unzip -p "$work/export.docx" word/document.xml | grep -q "INVOICE 2026" && echo "PASS: Word export contains OCR text"
