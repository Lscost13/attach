import Foundation

// MARK: - Модель ответа

struct DSHReply: Equatable {
    var text: String = ""
    var error: String?
    var finished: Bool = false
}

// MARK: - Клиент локального DSH

/// Ходит в движок по HTTP: рукопожатие токеном, RPC, страница истории.
final class DSHClient {
    let base: URL
    private var cookieHeader: String = ""

    init(base: URL) {
        self.base = base
    }

    // MARK: Рукопожатие

    /// `GET /?token=…` отдаёт 303 и cookie `dsh-auth-…`. Дальше только cookie.
    func handshake(token: String) async throws {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw DSHError.badURL
        }
        components.path = "/"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else { throw DSHError.badURL }

        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DSHError.badResponse }
        guard http.statusCode == 303 || http.statusCode == 200 else {
            throw DSHError.status(http.statusCode)
        }

        let raw = http.value(forHTTPHeaderField: "Set-Cookie") ?? ""
        guard let cookie = Self.authCookie(from: raw) else { throw DSHError.noCookie }
        cookieHeader = cookie
    }

    private static func authCookie(from header: String) -> String? {
        // Может прийти несколько Set-Cookie через запятую.
        for chunk in header.split(separator: ",") {
            let pair = chunk.split(separator: ";").first.map(String.init) ?? ""
            if pair.hasPrefix("dsh-auth-") {
                return pair.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: RPC

    private func rpc(_ method: String, args: [String: Any]) async throws -> Any {
        guard !cookieHeader.isEmpty else { throw DSHError.notAuthorized }
        let url = base.appendingPathComponent("api").appendingPathComponent(method)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let envelope: [String: Any] = [
            "type": "client-request",
            "rpcId": UUID().uuidString,
            "method": method,
            "payload": ["args": args],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: envelope)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DSHError.badResponse }
        guard http.statusCode == 200 else { throw DSHError.status(http.statusCode) }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any]
        else { throw DSHError.badResponse }

        if let ok = result["ok"] as? Bool, ok {
            return result["value"] ?? NSNull()
        }
        let error = result["error"] as? [String: Any]
        let message = error?["message"] as? String ?? "неизвестная ошибка DSH"
        throw DSHError.engine(message)
    }

    // MARK: Методы

    func createSession() async throws -> String {
        let value = try await rpc("session/create", args: ["request": [:]])
        guard let object = value as? [String: Any],
              let id = object["sessionId"] as? String
        else { throw DSHError.badResponse }
        return id
    }

    func prompt(sessionId: String, text: String) async throws {
        let args: [String: Any] = [
            "request": [
                "requestId": UUID().uuidString,
                "sessionId": sessionId,
                "mode": "queue",
                "content": [["type": "text", "text": text]],
                "clientTimeZone": TimeZone.current.identifier,
            ],
        ]
        _ = try await rpc("session/prompt", args: args)
    }

    func page(sessionId: String) async throws -> [[String: Any]] {
        let args: [String: Any] = [
            "request": ["address": ["kind": "session", "sessionId": sessionId]],
        ]
        let value = try await rpc("session/page", args: args)
        guard let object = value as? [String: Any],
              let records = object["records"] as? [[String: Any]]
        else { throw DSHError.badResponse }
        return records
    }

    func providers() async throws -> [String] {
        let value = try await rpc("llm/listProviders", args: [:])
        let list = value as? [[String: Any]] ?? []
        return list.compactMap { $0["name"] as? String }
    }

    // MARK: Аккаунт DeepSeek

    private static var clientMetadata: [String: Any] {
        [
            "version": "0.1",
            "locale": Locale.current.language.languageCode?.identifier ?? "ru",
            "timezoneOffsetSeconds": TimeZone.current.secondsFromGMT(),
        ]
    }

    func accountState() async throws -> DSHAccount {
        let value = try await rpc("account/getState", args: [:])
        let object = value as? [String: Any] ?? [:]
        let attempt = object["attempt"] as? [String: Any]
        let links = object["links"] as? [String: Any]
        let status = object["status"] as? String ?? "signed-out"
        return DSHAccount(
            signedIn: status == "credential-stored",
            authorizeURL: attempt?["authorizeUrl"] as? String,
            phase: attempt?["phase"] as? String,
            usageURL: links?["usageUrl"] as? String,
            topUpURL: links?["topUpUrl"] as? String
        )
    }

    /// Начинает вход в аккаунт DeepSeek и возвращает состояние с ссылкой на браузер.
    func startSignIn() async throws -> DSHAccount {
        let args: [String: Any] = [
            "client": Self.clientMetadata,
            "callbackOrigin": base.absoluteString,
            "loginSource": "web",
        ]
        _ = try await rpc("account/startSignIn", args: args)
        return try await accountState()
    }

    /// Кладёт секрет в хранилище DSH — так движок начинает им пользоваться.
    func setCredential(ref: String, value: String) async throws {
        _ = try await rpc("credentials/set", args: ["ref": ref, "value": value])
    }
}

struct DSHAccount: Equatable {
    var signedIn: Bool = false
    var authorizeURL: String?
    var phase: String?
    var usageURL: String?
    var topUpURL: String?
}

// MARK: - Разбор истории

/// Один кусок хода: текст модели или вызов инструмента.
enum ChatSegment: Equatable {
    case text(String)
    case tool(name: String, detail: String, failed: Bool?)
}

enum DSHParse {
    /// Раскладывает журнал на то, что видно человеку: текст и действия инструментов.
    static func segments(from records: [[String: Any]]) -> [ChatSegment] {
        var result: [ChatSegment] = []
        var callIndex: [String: Int] = [:]
        var currentText: Int?

        func flush(_ text: String) {
            guard !text.isEmpty else { return }
            if let index = currentText, case .text(let existing) = result[index] {
                result[index] = .text(existing + text)
            } else {
                result.append(.text(text))
                currentText = result.count - 1
            }
        }

        for record in records {
            guard let event = record["event"] as? [String: Any],
                  let type = event["type"] as? String,
                  let data = event["data"] as? [String: Any]
            else { continue }

            if type.hasPrefix("assistant/") {
                var collected: [String] = []
                collectText(from: data, into: &collected)
                flush(collected.joined())
                continue
            }

            if type == "tool/call" {
                // После вызова инструмента текст пойдёт отдельным пузырём.
                currentText = nil
                let name = data["name"] as? String ?? "инструмент"
                result.append(.tool(name: name, detail: argumentSummary(data["arguments"]), failed: nil))
                if let callId = data["callId"] as? String {
                    callIndex[callId] = result.count - 1
                }
                continue
            }

            if type == "tool/result" {
                let message = data["message"] as? [String: Any]
                let callId = message?["toolCallId"] as? String ?? ""
                guard let index = callIndex[callId],
                      index < result.count,
                      case .tool(let name, let detail, _) = result[index]
                else { continue }
                result[index] = .tool(
                    name: name,
                    detail: detail,
                    failed: (message?["isError"] as? Bool) ?? false
                )
                continue
            }
        }

        return result
    }

    /// Короткое описание аргументов вызова для карточки в чате.
    private static func argumentSummary(_ value: Any?) -> String {
        guard let raw = value as? String, !raw.isEmpty else { return "" }
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return String(raw.prefix(80)) }

        for key in ["command", "path", "file_path", "pattern", "url", "query", "prompt"] {
            if let text = object[key] as? String, !text.isEmpty {
                return String(text.prefix(100))
            }
        }
        return String(raw.prefix(80))
    }

    /// Достаёт из журнала последний ход: текст ассистента и ошибку, если была.
    static func lastTurn(from records: [[String: Any]]) -> DSHReply {
        var reply = DSHReply()
        var texts: [String] = []

        for record in records {
            guard let event = record["event"] as? [String: Any],
                  let type = event["type"] as? String,
                  let data = event["data"] as? [String: Any]
            else { continue }

            if type.hasPrefix("assistant/") {
                collectText(from: data, into: &texts)
            }

            if type == "turn/end" {
                reply.finished = true
                if let reason = data["reason"] as? [String: Any] {
                    if let kind = reason["kind"] as? String, kind == "error",
                       let error = reason["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        reply.error = message
                    } else if let kind = reason["kind"] as? String, kind == "abort" {
                        reply.error = "остановлено"
                    }
                }
            }
        }

        reply.text = texts.joined()
        return reply
    }

    /// Рекурсивно вытаскиваем строки из ключа text, но не из служебных полей.
    private static func collectText(from value: Any, into texts: inout [String]) {
        if let dictionary = value as? [String: Any] {
            if let type = dictionary["type"] as? String,
               type == "text",
               let text = dictionary["text"] as? String {
                texts.append(text)
                return
            }
            for key in ["message", "stream", "chunk", "content", "delta"] {
                if let nested = dictionary[key] {
                    collectText(from: nested, into: &texts)
                }
            }
            return
        }
        if let array = value as? [Any] {
            for item in array {
                collectText(from: item, into: &texts)
            }
        }
    }
}

// MARK: - Ошибки и редирект

enum DSHError: LocalizedError {
    case badURL
    case badResponse
    case noCookie
    case notAuthorized
    case status(Int)
    case engine(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "неверный адрес движка"
        case .badResponse: return "движок ответил не по протоколу"
        case .noCookie: return "движок не выдал cookie"
        case .notAuthorized: return "нет доступа к движку"
        case .status(let code): return "движок вернул \(code)"
        case .engine(let message): return message
        }
    }
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
