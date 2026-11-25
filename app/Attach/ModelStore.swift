import Foundation

@MainActor
final class ModelStore: ObservableObject {
    /// Один на всё приложение: ядру тоже нужен доступ к ключу.
    static let shared = ModelStore()

    enum CheckState: Equatable {
        case idle
        case checking
        case ok(String)
        case failed(String)
    }

    @Published var provider: ProviderKind
    @Published var model: String
    @Published var baseURL: String
    @Published private(set) var hasKey: Bool
    @Published private(set) var check: CheckState = .idle

    private let defaults = UserDefaults.standard

    init() {
        let stored = ProviderKind(rawValue: defaults.string(forKey: "provider") ?? "") ?? .deepseek
        provider = stored
        model = defaults.string(forKey: "model") ?? (stored.models.first ?? "deepseek-chat")
        baseURL = defaults.string(forKey: "baseURL") ?? stored.defaultBaseURL
        hasKey = Keychain.read(account: stored.rawValue)?.isEmpty == false
    }

    var currentKey: String? {
        guard let key = Keychain.read(account: provider.rawValue), !key.isEmpty else { return nil }
        return key
    }

    func select(_ kind: ProviderKind) {
        provider = kind
        if !kind.defaultBaseURL.isEmpty {
            baseURL = kind.defaultBaseURL
        }
        if let first = kind.models.first {
            model = first
        }
        hasKey = currentKey != nil
        check = .idle
    }

    func save(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Keychain.save(trimmed, account: provider.rawValue)
        }
        defaults.set(provider.rawValue, forKey: "provider")
        defaults.set(model, forKey: "model")
        defaults.set(baseURL, forKey: "baseURL")
        hasKey = currentKey != nil

        // Ключ нужен не только приложению: без него движок не может ходить в DeepSeek.
        Task { await syncKeyToEngine() }
    }

    /// Отдаёт ключ ядру через его хранилище секретов.
    func syncKeyToEngine() async {
        guard let key = currentKey else {
            Diag.log("key: ключа нет, передавать нечего")
            return
        }
        guard let ref = provider.credentialRef else {
            Diag.log("key: для \(provider.rawValue) передача в ядро пока не сделана")
            return
        }

        do {
            try await EngineBridge.store(key: key, ref: ref)
            Diag.log("key: \(ref) передан ядру")
            check = .ok("ключ передан ядру")
        } catch {
            if CoreRuntime.shared.info == nil {
                // Ядро ещё поднимается — отдадим ключ, когда оно ответит.
                Diag.log("key: ядро не готово, передадим при старте")
            } else {
                Diag.log("key: не удалось передать — \(error.localizedDescription)")
                check = .failed("ядро не приняло ключ: \(error.localizedDescription)")
            }
        }
    }

    func removeKey() {
        Keychain.delete(account: provider.rawValue)
        hasKey = false
        check = .idle
    }

    /// Баланс есть только у платформенного ключа DeepSeek.
    func fetchBalance() async -> String? {
        guard provider == .deepseek, let key = currentKey,
              let url = URL(string: "https://api.deepseek.com/user/balance")
        else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let infos = root["balance_infos"] as? [[String: Any]],
              let first = infos.first
        else { return nil }

        let amount = first["total_balance"] as? String ?? "0"
        let currency = first["currency"] as? String ?? ""
        let symbol = currency == "CNY" ? "¥" : (currency == "USD" ? "$" : currency + " ")
        return symbol + amount
    }

    func runCheck() async {
        guard let key = currentKey else {
            check = .failed("Сначала сохрани ключ")
            return
        }
        check = .checking
        do {
            let result = try await ProviderClient.check(
                kind: provider,
                baseURL: baseURL,
                model: model,
                key: key
            )
            check = .ok(result)
        } catch {
            check = .failed(error.localizedDescription)
        }
    }
}
