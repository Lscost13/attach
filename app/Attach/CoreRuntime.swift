import Foundation
import NodeMobile
import SwiftUI

/// Держит Node-ядро: запускает его один раз и следит, пока оно не ответит на /health.
@MainActor
final class CoreRuntime: ObservableObject {
    enum Phase: Equatable {
        case idle
        case starting
        case ready(node: String)
        case failed(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }

        var title: String {
            switch self {
            case .idle: return "Ядро не запущено"
            case .starting: return "Ядро запускается…"
            case .ready(let node): return "Ядро на связи · Node \(node)"
            case .failed(let reason): return "Ядро не поднялось"
            }
        }

        var subtitle: String {
            switch self {
            case .idle: return "Node 24 внутри приложения"
            case .starting: return "поднимаем Node в песочнице"
            case .ready: return "127.0.0.1:8787 · локально, без сервера"
            case .failed(let reason): return reason
            }
        }
    }

    static let shared = CoreRuntime()

    @Published private(set) var phase: Phase = .idle

    private let port: Int = 8787
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
        guard let resources = Bundle.main.resourceURL else {
            phase = .failed("нет ресурсов бандла")
            return
        }
        let engine = resources.appendingPathComponent("Engine", isDirectory: true)
        let entry = engine.appendingPathComponent("main.js")
        guard FileManager.default.fileExists(atPath: entry.path) else {
            phase = .failed("в бандле нет Engine/main.js")
            return
        }

        let home = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        setenv("HOME", home.path, 1)
        setenv("ATTACH_ENGINE", engine.path, 1)
        setenv("ATTACH_WORKDIR", home.path, 1)
        setenv("ATTACH_PORT", String(port), 1)

        let argv0 = "node"
        let argv1 = entry.path
        DispatchQueue.global(qos: .userInitiated).async {
            var argv: [UnsafeMutablePointer<CChar>?] = [strdup(argv0), strdup(argv1), nil]
            _ = node_start(2, &argv)
        }
    }

    // MARK: - Health

    private func poll() {
        attempts += 1
        guard attempts <= 60 else {
            phase = .failed("ядро не ответило за 30 секунд")
            return
        }
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/health")!)
        request.timeoutInterval = 1.5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, _, _ in
            var node: String?
            if let data,
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                node = object["node"] as? String
            }
            Task { @MainActor in
                if let node {
                    self.phase = .ready(node: node)
                } else {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.poll()
                }
            }
        }.resume()
    }
}

/// Строка состояния ядра — пока единственное, что видно на экране.
struct CoreStatusRow: View {
    let phase: CoreRuntime.Phase

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(phase.isReady ? Color.white : Color.white.opacity(0.35))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(phase.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                Text(phase.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.44))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
        .padding(.bottom, 8)
    }
}
