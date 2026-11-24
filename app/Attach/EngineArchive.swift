import Compression
import Foundation

/// Распаковка движка из нашего формата: заголовок + записи
/// [длина имени][имя][исходный размер][сжатый размер][байты].
/// Apple-овский Compression понимает zlib по-разному в разных версиях,
/// поэтому пробуем и «сырой» deflate, и поток с zlib-заголовком.
enum EngineArchive {
    enum ArchiveError: LocalizedError {
        case badMagic
        case truncated
        case inflateFailed(String)

        var errorDescription: String? {
            switch self {
            case .badMagic: return "файл движка повреждён"
            case .truncated: return "файл движка обрезан"
            case .inflateFailed(let name): return "не удалось распаковать \(name)"
            }
        }
    }

    static func unpack(
        archive: URL,
        to destination: URL,
        progress: ((Int, Int) -> Void)? = nil
    ) throws {
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
            var index = 0

            for _ in 0..<count {
                index += 1
                if index % 200 == 0 {
                    progress?(index, count)
                }
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

                guard originalSize > 0, compressedSize > 0 else {
                    FileManager.default.createFile(atPath: fileURL.path, contents: Data())
                    offset += compressedSize
                    continue
                }

                let source = (base + offset).assumingMemoryBound(to: UInt8.self)
                var output = Data(count: originalSize)
                var written = decode(source: source, size: compressedSize, into: &output, expected: originalSize)

                // Если не сошлось — значит поток был с zlib-заголовком:
                // пропускаем 2 байта заголовка и 4 байта контрольной суммы.
                if written != originalSize, compressedSize > 6 {
                    output = Data(count: originalSize)
                    let wrapped = (base + offset + 2).assumingMemoryBound(to: UInt8.self)
                    written = decode(
                        source: wrapped,
                        size: compressedSize - 6,
                        into: &output,
                        expected: originalSize
                    )
                }

                guard written == originalSize else {
                    throw ArchiveError.inflateFailed("\(name) (\(written) из \(originalSize))")
                }

                try output.write(to: fileURL)
                offset += compressedSize
            }

            progress?(count, count)
        }
    }

    private static func decode(
        source: UnsafePointer<UInt8>,
        size: Int,
        into output: inout Data,
        expected: Int
    ) -> Int {
        output.withUnsafeMutableBytes { buffer -> Int in
            guard let destination = buffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                destination, expected,
                source, size,
                nil, COMPRESSION_ZLIB
            )
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
