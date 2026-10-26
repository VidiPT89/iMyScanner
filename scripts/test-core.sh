#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/imyscanner-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -swift-version 6 -module-cache-path "$test_dir/cache" \
  iMyScanner/Models/ScanPage.swift iMyScanner/Models/ScanDocument.swift iMyScanner/Models/FiscalInvoice.swift \
  iMyScanner/Services/ZipArchiveBuilder.swift iMyScanner/Services/DocxExportService.swift \
  tests/main.swift -o "$test_dir/tests"
"$test_dir/tests" "$test_dir"
python3 - "$test_dir" <<'PY'
import sys, zipfile, xml.etree.ElementTree as ET
from pathlib import Path
root = Path(sys.argv[1])
with zipfile.ZipFile(root/'document.docx') as z:
    assert z.testzip() is None
    for name in z.namelist(): ET.fromstring(z.read(name))
    text = ''.join(ET.fromstring(z.read('word/document.xml')).itertext())
    assert 'A & B < C' in text and 'Português: ação' in text
print('PASS: DOCX ZIP checksums, XML parts, escaping and Unicode')
with zipfile.ZipFile(root/'unicode.zip') as z:
    assert z.read('ação.txt').decode() == 'ação'
print('PASS: Unicode ZIP entry names round trip')
PY
