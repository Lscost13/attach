import Foundation

// MARK: - Провайдеры

enum ProviderKind: String, CaseIterable, Codable, Identifiable {
    case deepseek, openai, anthropic, gemini, openrouter, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Gemini"
        case .openrouter: return "OpenRouter"
        case .custom: return "Свой"
        }
    }

    var glyph: String {
        switch self {
        case .deepseek: return "sparkle"
        case .openai: return "circle.hexagongrid"
        case .anthropic: return "a.circle"
        case .gemini: return "diamond"
        case .openrouter: return "arrow.triangle.branch"
        case .custom: return "slider.horizontal.3"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/v1"
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .custom: return ""
        }
    }

    var models: [String] {
        switch self {
        case .deepseek: return ["deepseek-chat", "deepseek-reasoner"]
        case .openai: return ["gpt-4.1-mini", "gpt-4.1", "o4-mini"]
        case .anthropic: return ["claude-sonnet-4-5", "claude-haiku-4-5"]
        case .gemini: return ["gemini-2.5-flash", "gemini-2.5-pro"]
        case .openrouter: return ["deepseek/deepseek-chat", "anthropic/claude-sonnet-4.5"]
        case .custom: return []
        }
    }

    var hint: String {
        switch self {
        case .deepseek: return "Ключ с platform.deepseek.com"
        case .openai: return "Ключ с platform.openai.com"
        case .anthropic: return "Ключ с console.anthropic.com"
        case .gemini: return "Ключ из Google AI Studio"
        case .openrouter: return "Один ключ на все модели"
        case .custom: return "Любой OpenAI-совместимый endpoint"
        }
    }
}

// MARK: - Проверка ключа

enum ProviderError: LocalizedError {
    case badURL
    case noKey
    case status(Int, String)
    case empty

    var errorDescription: String? {
        switch self {
        case .badURL: return "Некорректный адрес"
        case .noKey: return "Нет ключа"
        case .status(let code, let body):
            if code == 401 || code == 403 { return "Ключ не принят (\(code))" }
            return "HTTP \(code): \(body)"
        case .empty: return "Пустой ответ"
        }
    }
}

enum ProviderClient {
    /// Проверяет ключ: сначала пробует список моделей, потом короткий запрос в чат.
    static func check(kind: ProviderKind, baseURL: String, model: String, key: String) async throws -> String {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw ProviderError.noKey }

        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty, URL(string: base) != nil else { throw ProviderError.badURL }

        if kind == .anthropic {
            let result = try await get(
                "\(base)/models",
                headers: ["x-api-key": trimmedKey, "anthropic-version": "2023-06-01"]
            )
            return result
        }

        if let result = try? await get("\(base)/models", headers: ["Authorization": "Bearer \(trimmedKey)"]) {
            return result
        }
        return try await chat(base: base, model: model, key: trimmedKey)
    }

    private static func get(_ url: String, headers: [String: String]) async throws -> String {
        guard let url = URL(string: url) else { throw ProviderError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.empty }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderError.status(http.statusCode, String(body.prefix(200)))
        }
        return "ключ рабочий"
    }

    private static func chat(base: String, model: String, key: String) async throws -> String {
        guard let url = URL(string: "\(base)/chat/completions") else { throw ProviderError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "ping"]],
            "max_tokens": 1,
            "stream": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.empty }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProviderError.status(http.statusCode, String(body.prefix(200)))
        }
        return "\(model) ответил"
    }
}
