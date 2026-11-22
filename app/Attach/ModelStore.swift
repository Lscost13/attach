import Foundation

@MainActor
final class ModelStore: ObservableObject {
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
    }

    func removeKey() {
        Keychain.delete(account: provider.rawValue)
        hasKey = false
        check = .idle
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
