import Foundation

/// Мост к ядру: то, что приложение отдаёт движку.
enum EngineBridge {
    /// Клиент к работающему ядру с уже пройденным рукопожатием.
    @MainActor
    static func client() async throws -> DSHClient {
        guard let info = CoreRuntime.shared.info, let base = URL(string: info.url) else {
            throw DSHError.engine("ядро не запущено")
        }
        let client = DSHClient(base: base)
        try await client.handshake(token: info.token ?? "")
        return client
    }

    /// Кладёт секрет в хранилище ядра — так движок получает доступ к модели.
    @MainActor
    static func store(key: String, ref: String) async throws {
        let client = try await client()
        try await client.setCredential(ref: ref, value: key)
    }
}
