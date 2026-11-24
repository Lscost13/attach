import Foundation

/// Журнал приложения. Без него на телефоне видно только «вылетело»,
/// а понять почему — нельзя.
enum Diag {
    static let directory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(".attach", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var appURL: URL { directory.appendingPathComponent("app.log") }
    static var crashURL: URL { directory.appendingPathComponent("crash.log") }
    static var engineURL: URL { directory.appendingPathComponent("engine.log") }

    private static let queue = DispatchQueue(label: "com.manul.attach.diag")
    private static let limit: UInt64 = 512 * 1024
    private static var started = false
    private(set) static var signalFD: Int32 = -1
    private static var sampler: DispatchSourceTimer?

    // MARK: - Установка

    static func install() {
        guard !started else { return }
        started = true

        trim(appURL)
        trim(engineURL)
        signalFD = open(crashURL.path, O_CREAT | O_WRONLY | O_APPEND, 0o644)
        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP] {
            signal(sig, attachCrashSignal)
        }

        NSSetUncaughtExceptionHandler { exception in
            let text = """
            \(clock()) UNCAUGHT \(exception.name.rawValue): \(exception.reason ?? "-")
            \(exception.callStackSymbols.prefix(40).joined(separator: "\n"))
            """
            append(text, to: crashURL)
        }

        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        log("launch build \(version), ios \(ProcessInfo.processInfo.operatingSystemVersionString)")
        startMemorySampler()
    }

    // MARK: - Запись

    static func log(_ message: String) {
        queue.async { append("\(clock()) \(message)", to: appURL) }
    }

    static func logSync(_ message: String) {
        append("\(clock()) \(message)", to: appURL)
    }

    private static func append(_ text: String, to url: URL) {
        guard let data = (text + "\n").data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }

        if let size = fileSize(url), size > limit {
            trim(url)
        }
    }

    private static func fileSize(_ url: URL) -> UInt64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let number = attributes[.size] as? NSNumber
        else { return nil }
        return number.uint64Value
    }

    /// Оставляем хвост файла, чтобы он не рос бесконечно.
    private static func trim(_ url: URL) {
        guard let size = fileSize(url), size > limit / 2,
              let data = try? Data(contentsOf: url)
        else { return }
        try? Data(data.suffix(Int(limit / 2))).write(to: url, options: .atomic)
    }

    private static func clock() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    // MARK: - Память

    private static func startMemorySampler() {
        var ticks = 0
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 3)
        timer.setEventHandler {
            ticks += 1
            append("\(clock()) mem \(residentMegabytes()) MB", to: appURL)
            if ticks > 300 {
                timer.cancel()
            }
        }
        timer.resume()
        sampler = timer
    }

    /// Сколько памяти занимает процесс — по ней видно, не убил ли нас jetsam.
    private static func residentMegabytes() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return "?" }
        return String(info.resident_size / 1_048_576)
    }

    // MARK: - Чтение

    static func tail(of url: URL, bytes: Int = 6_000) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        let slice = data.count > bytes ? data.suffix(bytes) : data
        return String(decoding: slice, as: UTF8.self)
    }

    static var hasCrash: Bool {
        (fileSize(crashURL) ?? 0) > 0
    }

    /// Всё, что нужно, чтобы понять падение и проблему с ядром.
    static func report() -> String {
        var parts: [String] = []
        parts.append("Attach · журнал")
        parts.append("время: \(Date())")

        let crash = tail(of: crashURL)
        if crash.isEmpty {
            parts.append("\n— падений не записано —")
        } else {
            parts.append("\n— падение —\n\(crash)")
        }

        let engine = tail(of: engineURL, bytes: 8_000)
        if !engine.isEmpty {
            parts.append("\n— ядро —\n\(engine)")
        }

        parts.append("\n— приложение —\n\(tail(of: appURL, bytes: 5_000))")
        return parts.joined(separator: "\n")
    }

    static func clear() {
        try? Data().write(to: crashURL)
        log("journal cleared")
    }
}

/// Обработчик сигнала: успевает только дописать метку в файл.
private func attachCrashSignal(_ signo: Int32) {
    let fd = Diag.signalFD
    if fd >= 0 {
        let line = "\n=== падение: signal \(signo) ===\n"
        line.withCString { pointer in
            _ = write(fd, pointer, strlen(pointer))
        }
    }
    signal(signo, SIG_DFL)
    _ = raise(signo)
}
