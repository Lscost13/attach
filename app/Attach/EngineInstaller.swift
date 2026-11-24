import Foundation
import SwiftUI

/// Скачивание движка с прогрессом и внятными ошибками.
final class EngineDownloader: NSObject, URLSessionDownloadDelegate {
    private let destination: URL
    private var continuation: CheckedContinuation<Void, Error>?
    private var progressHandler: ((Double) -> Void)?
    private var session: URLSession?

    init(destination: URL) {
        self.destination = destination
    }

    func download(from url: URL, progress: @escaping (Double) -> Void) async throws {
        progressHandler = progress
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 900
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        defer { session.finishTasksAndInvalidate() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progressHandler?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            finish(.failure(EngineError.http(http.statusCode)))
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            finish(.success(()))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

enum EngineError: LocalizedError {
    case http(Int)
    case tooSmall(Int64)
    case noSpace(Int64)
    case noEntry
    case badArchive(String)

    var errorDescription: String? {
        switch self {
        case .http(let code):
            return "GitHub ответил \(code). Обычно это значит, что ссылка на движок устарела."
        case .tooSmall(let size):
            return "Скачалось \(size) байт вместо движка — похоже, пришла страница ошибки."
        case .noSpace(let free):
            return "Мало места: свободно \(free / 1_048_576) МБ, нужно около 900."
        case .noEntry:
            return "В архиве нет main.js — движок скачался неправильно."
        case .badArchive(let name):
            return "Не удалось распаковать \(name)."
        }
    }
}

/// Движок не лежит в бандле: при первом запуске скачиваем один файл
/// и распаковываем в Documents.
@MainActor
final class EngineInstaller: ObservableObject {
    enum Phase: Equatable {
        case checking
        case downloading
        case unpacking
        case ready
        case failed(String)
    }

    static let shared = EngineInstaller()

    @Published private(set) var phase: Phase = .checking
    @Published private(set) var progress: Double = 0
    @Published private(set) var receivedText: String = ""

    private let remote = URL(
        string: "https://github.com/Lscost13/attach/releases/download/engine-latest/engine.bin"
    )!

    var engineDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("engine", isDirectory: true)
    }

    var entryURL: URL {
        engineDirectory.appendingPathComponent("main.js")
    }

    var isReady: Bool {
        FileManager.default.fileExists(atPath: entryURL.path)
    }

    func prepareIfNeeded() async {
        if isReady {
            phase = .ready
            return
        }

        progress = 0
        receivedText = ""
        phase = .downloading

        do {
            try ensureFreeSpace()

            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("engine-download.bin")
            let downloader = EngineDownloader(destination: temp)
            try await downloader.download(from: remote) { [weak self] value in
                Task { @MainActor in
                    self?.progress = value
                    self?.receivedText = "\(Int(value * 100))%"
                }
            }

            let attributes = try? FileManager.default.attributesOfItem(atPath: temp.path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            guard size > 1_000_000 else { throw EngineError.tooSmall(size) }

            phase = .unpacking
            try? FileManager.default.removeItem(at: engineDirectory)

            do {
                try EngineArchive.unpack(archive: temp, to: engineDirectory)
            } catch {
                throw EngineError.badArchive(error.localizedDescription)
            }
            try? FileManager.default.removeItem(at: temp)

            guard isReady else { throw EngineError.noEntry }
            phase = .ready
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func retry() {
        phase = .checking
        Task { await prepareIfNeeded() }
    }

    private func ensureFreeSpace() throws {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = values?.volumeAvailableCapacityForImportantUsage, free < 900 * 1_048_576 {
            throw EngineError.noSpace(free)
        }
    }

    private static func message(for error: Error) -> String {
        if let engine = error as? EngineError {
            return engine.errorDescription ?? "неизвестная ошибка"
        }
        let ns = error as NSError
        return "\(ns.localizedDescription) (\(ns.domain) \(ns.code))"
    }
}

/// Экран подготовки при первом запуске.
struct EngineSetupView: View {
    @ObservedObject var installer: EngineInstaller

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "shippingbox")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white)

            Text("Готовим ядро")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            switch installer.phase {
            case .downloading:
                ProgressView(value: installer.progress)
                    .tint(.white)
                    .frame(width: 220)
                Text(installer.receivedText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
            case .failed(let message):
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)

                Button {
                    installer.retry()
                } label: {
                    Text("Повторить")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            default:
                ProgressView()
                    .tint(.white)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task { await installer.prepareIfNeeded() }
    }

    private var subtitle: String {
        switch installer.phase {
        case .checking: return "Проверяем, всё ли на месте"
        case .downloading: return "Скачиваем движок, 269 МБ. Дальше он останется на телефоне."
        case .unpacking: return "Распаковываем — это самый долгий шаг"
        case .ready: return "Готово"
        case .failed: return "Что-то пошло не так"
        }
    }
}
