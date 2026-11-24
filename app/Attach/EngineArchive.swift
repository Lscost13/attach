import Compression
import Foundation

/// Распаковка движка из нашего формата: заголовок + записи
/// [длина имени][имя][исходный размер][сжатый размер][байты zlib].
/// Системный Compression умеет zlib, поэтому зависимостей нет.
enum EngineArchive {
    enum ArchiveError: LocalizedError {
        case badMagic
        case truncated
        case inflateFailed(String)

        var errorDescription: String? {
            switch self {
            case .badMagic: return "Файл движка повреждён"
            case .truncated: return "Файл движка обрезан"
            case .inflateFailed(let name): return "Не удалось распаковать \(name)"
            }
        }
    }

    static func unpack(archive: URL, to destination: URL) throws {
        let data = try Data(contentsOf: archive, options: .mappedIfSafe)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Void in
            guard raw.count >= 10 else { throw ArchiveError.truncated }
            guard let magic = String(bytes: raw[0..<4], encoding: .ascii), magic == "ATGE" else {
                throw ArchiveError.badMagic
            }

            let count = Int(readU32(raw, 6))
            var offset = 10
            let base = raw.baseAddress!

            for _ in 0..<count {
                guard offset + 2 <= raw.count else { throw ArchiveError.truncated }
                let nameLength = Int(readU16(raw, offset))
                offset += 2

                guard offset + nameLength + 8 <= raw.count else { throw ArchiveError.truncated }
                let name = String(decoding: raw[offset..<offset + nameLength], as: UTF8.self)
                offset += nameLength

                let originalSize = Int(readU32(raw, offset))
                offset += 4
                let compressedSize = Int(readU32(raw, offset))
                offset += 4

                guard offset + compressedSize <= raw.count else { throw ArchiveError.truncated }

                let fileURL = destination.appendingPathComponent(name)
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                if originalSize == 0 {
                    FileManager.default.createFile(atPath: fileURL.path, contents: Data())
                    offset += compressedSize
                    continue
                }

                let source = (base + offset).assumingMemoryBound(to: UInt8.self)
                var output = Data(count: originalSize)
                let written = output.withUnsafeMutableBytes { buffer -> Int in
                    guard let destinationPointer = buffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    return compression_decode_buffer(
                        destinationPointer, originalSize,
                        source, compressedSize,
                        nil, COMPRESSION_ZLIB
                    )
                }
                guard written == originalSize else { throw ArchiveError.inflateFailed(name) }

                try output.write(to: fileURL)
                offset += compressedSize
            }
        }
    }

    private static func readU16(_ raw: UnsafeRawBufferPointer, _ index: Int) -> UInt16 {
        UInt16(raw[index]) | (UInt16(raw[index + 1]) << 8)
    }

    private static func readU32(_ raw: UnsafeRawBufferPointer, _ index: Int) -> UInt32 {
        UInt32(raw[index])
            | (UInt32(raw[index + 1]) << 8)
            | (UInt32(raw[index + 2]) << 16)
            | (UInt32(raw[index + 3]) << 24)
    }
}
