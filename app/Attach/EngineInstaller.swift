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
    case unpackTimeout
    case badArchive(String)

    var errorDescription: String? {
        switch self {
        case .http(let code):
            return "GitHub ответил \(code). Обычно это значит, что ссылка на движок устарела."
        case .tooSmall(let size):
            return "Скачалось \(size) байт вместо движка — похоже, пришла страница ошибки."
        case .noSpace(let free):
            return "Мало места: свободно \(free / 1_048_576) МБ, нужно около 1200."
        case .unpackTimeout:
            return "Распаковка не закончилась за 15 минут. Нажми «Повторить»."
        case .badArchive(let reason):
            return "Не удалось распаковать движок: \(reason)"
        }
    }
}

/// Состояние распаковки, которое пишет ядро.
struct UnpackState: Codable {
    var phase: String = "unpack"
    var done: Int = 0
    var total: Int = 0
    var error: String?
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
    @Published private(set) var unpackProgress: Double = 0
    @Published private(set) var unpackText: String = ""

    private var running = false

    private let remote = URL(
        string: "https://github.com/Lscost13/attach/releases/download/engine-latest/engine.bin"
    )!

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var engineDirectory: URL {
        documents.appendingPathComponent("engine", isDirectory: true)
    }

    /// Скачанный архив движка. Node распаковывает его сам, когда стартует.
    var archiveURL: URL {
        documents.appendingPathComponent(".attach/engine.bin")
    }

    /// Отметка «распаковано» — её пишет ядро после успешной распаковки.
    var markerURL: URL {
        documents.appendingPathComponent(".attach/engine-ready")
    }

    var unpackStateURL: URL {
        documents.appendingPathComponent(".attach/unpack.json")
    }

    var isReady: Bool {
        FileManager.default.fileExists(atPath: markerURL.path)
    }

    /// Архив на месте — уже можно поднимать Node, он сам всё разложит.
    var hasArchive: Bool {
        FileManager.default.fileExists(atPath: archiveURL.path)
    }

    private var archiveSuspect = false

    func prepareIfNeeded() async {
        guard !running else { return }
        running = true
        defer { running = false }

        if isReady {
            phase = .ready
            // Ядро поднимаем сразу при запуске, не дожидаясь действий пользователя.
            CoreRuntime.shared.bootIfNeeded()
            return
        }

        // Движка нет — значит всё, что лежит в папке, мусор от прошлой попытки.
        // Освобождаем место: архив весит 282 МБ, а распакованный движок — около 700.
        try? FileManager.default.removeItem(at: engineDirectory)

        do {
            if !hasArchive {
                try await download()
            }

            phase = .unpacking
            unpackProgress = 0
            unpackText = "0%"
            Diag.log("engine: архив на месте, ждём распаковку")

            // Распаковывает ядро: у него тот же zlib, которым архив собран.
            CoreRuntime.shared.bootIfNeeded()
            try await waitForUnpack()

            phase = .ready
            Diag.log("engine: движок распакован")
        } catch {
            phase = .failed(Self.message(for: error))
            Diag.log("engine: ошибка — \(Self.message(for: error))")
        }
    }

    private func download() async throws {
        progress = 0
        receivedText = ""
        phase = .downloading
        Diag.log("engine: качаем \(remote.absoluteString)")
        try ensureFreeSpace()

        try? FileManager.default.createDirectory(
            at: archiveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let partial = archiveURL.appendingPathExtension("part")
        try? FileManager.default.removeItem(at: partial)

        let downloader = EngineDownloader(destination: partial)
        try await downloader.download(from: remote) { [weak self] value in
            Task { @MainActor in
                self?.progress = value
                self?.receivedText = "\(Int(value * 100))%"
            }
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: partial.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        Diag.log("engine: скачано \(size) байт")
        guard size > 100_000_000 else { throw EngineError.tooSmall(size) }

        try? FileManager.default.removeItem(at: archiveURL)
        try FileManager.default.moveItem(at: partial, to: archiveURL)
    }

    private func waitForUnpack() async throws {
        let deadline = Date().addingTimeInterval(900)

        while Date() < deadline {
            if isReady { return }

            if case .failed(let reason) = CoreRuntime.shared.phase {
                archiveSuspect = true
                throw EngineError.badArchive(reason)
            }

            if let data = try? Data(contentsOf: unpackStateURL),
               let state = try? JSONDecoder().decode(UnpackState.self, from: data) {
                if state.phase == "failed" {
                    archiveSuspect = true
                    throw EngineError.badArchive(state.error ?? "неизвестная ошибка")
                }
                if state.total > 0 {
                    let value = min(1, Double(state.done) / Double(state.total))
                    unpackProgress = value
                    unpackText = "\(Int(value * 100))% · \(state.done) из \(state.total)"
                }
            }

            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        throw EngineError.unpackTimeout
    }

    func retry() {
        // Если архив подвёл — качаем заново, иначе просто пробуем ещё раз.
        if archiveSuspect || !hasArchive {
            try? FileManager.default.removeItem(at: archiveURL)
        }
        archiveSuspect = false
        phase = .checking
        Task { await prepareIfNeeded() }
    }

    private func ensureFreeSpace() throws {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let free = values?.volumeAvailableCapacityForImportantUsage, free < 1_200 * 1_048_576 {
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
            case .unpacking:
                ProgressView(value: installer.unpackProgress)
                    .tint(.white)
                    .frame(width: 220)
                Text(installer.unpackText)
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
