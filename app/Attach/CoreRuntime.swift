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
        let entry = engine.appendingPathComponent("main.js")
        guard FileManager.default.fileExists(atPath: entry.path) else {
            phase = .failed("движок не скачан")
            return
        }

        let home = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        setenv("HOME", home.path, 1)
        setenv("ATTACH_ENGINE", engine.path, 1)
        setenv("ATTACH_WORKDIR", home.path, 1)
        setenv("ATTACH_PORT", String(port), 1)

        let argv0 = "node"
        let argv1 = "--expose-internals"
        let argv2 = entry.path
        DispatchQueue.global(qos: .userInitiated).async {
            var argv: [UnsafeMutablePointer<CChar>?] = [
                strdup(argv0),
                strdup(argv1),
                strdup(argv2),
                nil,
            ]
            _ = node_start(3, &argv)
        }
    }

    // MARK: - Готовность

    private var stateFile: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(".attach/engine.json")
    }

    private func poll() {
        attempts += 1
        guard attempts <= 240 else {
            phase = .failed("DSH не поднялся за 2 минуты")
            return
        }

        if let data = try? Data(contentsOf: stateFile),
           let info = try? JSONDecoder().decode(EngineInfo.self, from: data) {
            self.info = info
            phase = .ready
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.poll()
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
