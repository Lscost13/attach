import Foundation
import NodeMobile
import SwiftUI

/// Держит Node-ядро: запускает его один раз и следит, пока оно не ответит на /health.
@MainActor
final class CoreRuntime: ObservableObject {
    enum Phase: Equatable {
        case idle
        case starting
        case ready
        case failed(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }

        var title: String {
            switch self {
            case .idle: return "Ядро не запущено"
            case .starting: return "Ядро запускается…"
            case .ready: return "Ядро на связи"
            case .failed: return "Ядро не поднялось"
            }
        }

        var subtitle: String {
            switch self {
            case .idle: return "DeepSeek Harness внутри приложения"
            case .starting: return "поднимаем DSH в песочнице"
            case .ready: return "127.0.0.1:3080 · локально, без сервера"
            case .failed(let reason): return reason
            }
        }
    }

    static let shared = CoreRuntime()

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var info: EngineInfo?

    private let port: Int = 3080
    private var booted = false
    private var attempts = 0

    func bootIfNeeded() {
        guard !booted else { return }
        booted = true
        phase = .starting
        startNode()
        poll()
    }

    // MARK: - Node

    private func startNode() {
        let engine = EngineInstaller.shared.engineDirectory
        // Распаковкой занимается сам Node, поэтому запускаем его и тогда,
        // когда движок ещё лежит одним архивом.
        guard EngineInstaller.shared.isReady || EngineInstaller.shared.hasArchive else {
            phase = .failed("движок не скачан")
            return
        }

        // Скрипт запуска лежит в приложении — его можно обновить, не трогая движок.
        // Если в бандле его почему-то нет, берём копию из скачанного движка.
        let legacy = engine.appendingPathComponent("main.js")
        let bundled = Bundle.main.url(forResource: "engine-main", withExtension: "js")
        let fallback = FileManager.default.fileExists(atPath: legacy.path) ? legacy : nil
        guard let script = bundled ?? fallback else {
            phase = .failed("в сборке нет скрипта запуска")
            Diag.log("engine: нет engine-main.js в бандле")
            return
        }

        let home = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // DSH считает рабочим каталогом текущую папку: пусть это будет пустая
        // папка, а не Documents, где лежит весь движок из 70 тысяч файлов.
        let work = home.appendingPathComponent("work", isDirectory: true)
        try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        setenv("HOME", home.path, 1)
        setenv("ATTACH_ENGINE", engine.path, 1)
        setenv("ATTACH_WORKDIR", work.path, 1)
        setenv("ATTACH_PORT", String(port), 1)
        // Файл от прошлого запуска: токен у нового ядра будет другой,
        // и со старым приложение стучалось бы в пустоту.
        try? FileManager.default.removeItem(at: stateFile)

        Diag.log("engine: boot \(script.path) → \(engine.path)")

        // Node можно запустить только один раз, и ему нужен свой поток:
        // у очереди GCD стек 512 КБ, а V8 берёт предел стека от потока
        // и падает на глубоком графе модулей DSH.
        let thread = Thread {
            let code = NodeLauncher.run(["node", "--expose-internals", script.path])
            Diag.log("engine: node_start вернул \(code)")
            Task { @MainActor in
                CoreRuntime.shared.nodeExited(code)
            }
        }
        thread.name = "attach-node"
        thread.stackSize = 16 * 1024 * 1024
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    fileprivate func nodeExited(_ code: Int32) {
        if case .failed = phase { return }
        phase = .failed("движок остановился (код \(code)). Перезапусти приложение — подробности в журнале.")
        Diag.log("engine: Node завершился с кодом \(code)")
    }

    /// Живо ли ядро после возврата из фона: iOS могла усыпить процесс.
    func checkAlive() {
        guard booted, phase.isReady else { return }
        Task {
            do {
                _ = try await EngineBridge.client()
                Diag.log("engine: на связи после возврата")
            } catch {
                Diag.log("engine: нет ответа — \(error.localizedDescription)")
                phase = .failed("ядро не отвечает. Закрой и открой приложение.")
            }
        }
    }

    // MARK: - Готовность

    private var stateFile: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(".attach/engine.json")
    }

    private func poll() {
        attempts += 1
        guard attempts <= 1200 else {
            phase = .failed("DSH не поднялся за 10 минут. Подробности — в журнале.")
            Diag.log("engine: таймаут ожидания engine.json")
            return
        }

        if let data = try? Data(contentsOf: stateFile),
           let info = try? JSONDecoder().decode(EngineInfo.self, from: data) {
            self.info = info
            phase = .ready
            Diag.log("engine: готов на \(info.url) за \(Double(attempts) * 0.5) с")
            // Ключ мог остаться с прошлого запуска — сразу отдаём его ядру,
            // иначе первый же запрос в чате упрётся в «нет ключа».
            Task { await ModelStore.shared.syncKeyToEngine() }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.poll()
        }
    }
}

/// Запуск Node так, как его ждёт libuv: argv должен лежать одним куском памяти
/// (libuv перезаписывает его ради заголовка процесса), а стек потока должен
/// быть большим — V8 берёт от него свой предел.
enum NodeLauncher {
    static func run(_ arguments: [String]) -> Int32 {
        let total = arguments.reduce(0) { $0 + $1.utf8.count + 1 }
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: total)
        defer { buffer.deallocate() }

        var argv: [UnsafeMutablePointer<CChar>?] = []
        var cursor = buffer
        for argument in arguments {
            argument.withCString { source in
                let length = strlen(source) + 1
                cursor.update(from: source, count: length)
                argv.append(cursor)
                cursor += length
            }
        }

        return argv.withUnsafeMutableBufferPointer { pointer in
            node_start(Int32(arguments.count), pointer.baseAddress)
        }
    }
}

struct EngineInfo: Codable, Equatable {
    let url: String
    let token: String?
    let node: String?
}

/// Строка состояния ядра — пока единственное, что видно на экране.
struct CoreStatusRow: View {
    let phase: CoreRuntime.Phase

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(phase.isReady ? Color.white : Color.white.opacity(0.35))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(phase.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(phase.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1), lineWidth: 1))
        .padding(.bottom, 10)
    }
}
