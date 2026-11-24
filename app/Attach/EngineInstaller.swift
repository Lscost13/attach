import Foundation
import SwiftUI

/// Движок не лежит в бандле: при первом запуске скачиваем один файл
/// и распаковываем в Documents. Так IPA остаётся маленьким и его
/// берут сторонние подписчики (Feather и подобные).
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

        phase = .downloading
        do {
            let (temp, _) = try await URLSession.shared.download(from: remote)
            phase = .unpacking

            try? FileManager.default.removeItem(at: engineDirectory)
            try EngineArchive.unpack(archive: temp, to: engineDirectory)

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

    private static func message(for error: Error) -> String {
        if let engine = error as? EngineError {
            return engine.text
        }
        return "Не удалось скачать движок: \(error.localizedDescription)"
    }

    enum EngineError: Error {
        case noEntry

        var text: String {
            switch self {
            case .noEntry: return "В архиве нет main.js — движок скачался неправильно."
            }
        }
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
        case .downloading: return "Скачиваем движок, ~150 МБ. Дальше он уже останется на телефоне."
        case .unpacking: return "Распаковываем — это самый долгий шаг"
        case .ready: return "Готово"
        case .failed: return "Что-то пошло не так"
        }
    }
}
