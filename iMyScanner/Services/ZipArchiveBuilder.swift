import Foundation

/// A minimal, dependency-free ZIP writer producing "stored" (uncompressed)
/// entries. This is enough to build the Office Open XML container used by
/// `.docx` files without pulling in a third-party archiving library.
enum ZipArchiveBuilder {
    static func build(entries: [(name: String, data: Data)]) -> Data? {
        var fileData = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for entry in entries {
            guard let nameData = entry.name.data(using: .utf8) else { return nil }
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)

            var localHeader = Data()
            localHeader.appendUInt32(0x04034b50)
            localHeader.appendUInt16(20)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt16(0)
            localHeader.appendUInt32(crc)
            localHeader.appendUInt32(size)
            localHeader.appendUInt32(size)
            localHeader.appendUInt16(UInt16(nameData.count))
            localHeader.appendUInt16(0)
            localHeader.append(nameData)

            fileData.append(localHeader)
            fileData.append(entry.data)

            var centralEntry = Data()
            centralEntry.appendUInt32(0x02014b50)
            centralEntry.appendUInt16(20)
            centralEntry.appendUInt16(20)
            centralEntry.appendUInt16(0)
            centralEntry.appendUInt16(0)
            centralEntry.appendUInt16(0)
            centralEntry.appendUInt16(0)
            centralEntry.appendUInt32(crc)
            centralEntry.appendUInt32(size)
            centralEntry.appendUInt32(size)
            centralEntry.appendUInt16(UInt16(nameData.count))
            centralEntry.appendUInt16(0)
            centralEntry.appendUInt16(0)
            centralEntry.appendUInt16(0)
            centralEntry.appendUInt16(0)
            centralEntry.appendUInt32(0)
            centralEntry.appendUInt32(offset)
            centralEntry.append(nameData)

            centralDirectory.append(centralEntry)
            offset += UInt32(localHeader.count + entry.data.count)
        }

        var end = Data()
        end.appendUInt32(0x06054b50)
        end.appendUInt16(0)
        end.appendUInt16(0)
        end.appendUInt16(UInt16(entries.count))
        end.appendUInt16(UInt16(entries.count))
        end.appendUInt32(UInt32(centralDirectory.count))
        end.appendUInt32(offset)
        end.appendUInt16(0)

        var result = Data()
        result.append(fileData)
        result.append(centralDirectory)
        result.append(end)
        return result
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
