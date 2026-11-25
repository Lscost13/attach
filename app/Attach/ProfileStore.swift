import Foundation

// MARK: - Сколько занимает ядро

enum CoreStorage {
    struct Report: Equatable {
        var engine: Int64 = 0
        var data: Int64 = 0

        var total: Int64 { engine + data }

        var totalText: String { Self.mb(total) }
        var engineText: String { Self.mb(engine) }
        var dataText: String { Self.mb(data) }

        private static func mb(_ bytes: Int64) -> String {
            let value = Double(bytes) / 1_048_576
            if value >= 1024 {
                return String(format: "%.1f ГБ", value / 1024)
            }
            if value < 1 {
                return String(format: "%.0f КБ", Double(bytes) / 1024)
            }
            return String(format: "%.0f МБ", value)
        }
    }

    static func measure() async -> Report {
        await Task.detached(priority: .utility) {
            let engineURL = Bundle.main.resourceURL?.appendingPathComponent("Engine", isDirectory: true)
            let dataURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(".dsh", isDirectory: true)
            return Report(engine: size(of: engineURL), data: size(of: dataURL))
        }.value
    }

    private static func size(of url: URL?) -> Int64 {
        guard let url else { return 0 }
        var total: Int64 = 0
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let file as URL in enumerator {
            let values = try? file.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}

// MARK: - Обновления

/// Какая сборка сейчас установлена.
enum BuildInfo {
    static var number: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    static var numeric: Int {
        Int(number) ?? 0
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var installPage: URL? {
        URL(string: "https://lscost13.github.io/attach/")
    }
}

enum UpdateChecker {
    struct Release {
        let tag: String
        let number: Int
    }

    /// Последний релиз в репозитории: по номеру видно, свежая ли сборка.
    static func latestRelease() async -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/Lscost13/attach/releases/latest") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Attach/\(BuildInfo.version)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = root["tag_name"] as? String
        else { return nil }

        let number = Int(tag.replacingOccurrences(of: "build-", with: "")) ?? 0
        return Release(tag: tag, number: number)
    }

    /// Последний коммит в публичном репозитории — по нему видно, свежая ли сборка.
    static func latestCommit() async -> String? {
        guard let url = URL(string: "https://api.github.com/repos/Lscost13/attach/commits/main") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Attach/0.1", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commit = root["commit"] as? [String: Any],
              let committer = commit["committer"] as? [String: Any],
              let date = committer["date"] as? String
        else { return nil }

        let parser = ISO8601DateFormatter()
        guard let parsed = parser.date(from: date) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: parsed)
    }
}
