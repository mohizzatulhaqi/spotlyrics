import Foundation

enum Diagnostics {
    static let capacity = 30
    static let maxFileLines = 400
    static let sessionHeader = "# session "
    static let cleanMarker = "# clean exit"

    struct Previous: Equatable {
        let clean: Bool?
        let lines: [String]
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var entries: [String] = []
    nonisolated(unsafe) private static var directory: URL?
    nonisolated(unsafe) private static var previousSession = Previous(clean: nil, lines: [])

    static func iso(_ d: Date) -> String { ISO8601DateFormatter().string(from: d) }

    static func log(_ message: String, now: Date = Date()) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        lock.lock()
        defer { lock.unlock() }
        entries.append("\(f.string(from: now))  \(message)")
        if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
        if let dir = directory { append("\(iso(now))  \(message)\n", to: dir.appendingPathComponent("diagnostics.log")) }
    }

    static var recent: [String] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    static var previous: Previous {
        lock.lock()
        defer { lock.unlock() }
        return previousSession
    }

    static func reset() {
        lock.lock()
        entries = []
        directory = nil
        previousSession = Previous(clean: nil, lines: [])
        lock.unlock()
    }

    static func lastSession(in text: String) -> [String] {
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard let i = lines.lastIndex(where: { $0.hasPrefix(sessionHeader) }) else { return [] }
        return lines[(i + 1)...].filter { !$0.hasPrefix("#") }
    }

    static func trim(_ text: String, maxLines: Int) -> String {
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > maxLines else { return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n" }
        var kept = Array(lines.suffix(maxLines))
        if let first = kept.firstIndex(where: { $0.hasPrefix(sessionHeader) }), first > 0 { kept.removeFirst(first) }
        return kept.joined(separator: "\n") + "\n"
    }

    private static func append(_ s: String, to url: URL) {
        guard let data = s.data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    private static func writeMarker(_ dir: URL, started: Date, clean: Bool) {
        let obj: [String: Any] = ["started": iso(started), "clean": clean]
        if let d = try? JSONSerialization.data(withJSONObject: obj) { try? d.write(to: dir.appendingPathComponent("session.json"), options: .atomic) }
    }

    static func begin(in dir: URL, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let logURL = dir.appendingPathComponent("diagnostics.log")
        let text = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        var clean: Bool?
        if let d = try? Data(contentsOf: dir.appendingPathComponent("session.json")),
           let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] {
            clean = o["clean"] as? Bool
        }
        previousSession = Previous(clean: clean, lines: Array(lastSession(in: text).suffix(30)))
        let trimmed = trim(text, maxLines: maxFileLines)
        try? (trimmed + "\(sessionHeader)\(iso(now))\n").write(to: logURL, atomically: true, encoding: .utf8)
        writeMarker(dir, started: now, clean: false)
        directory = dir
    }

    static func end(now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        guard let dir = directory else { return }
        append("\(cleanMarker)\n", to: dir.appendingPathComponent("diagnostics.log"))
        writeMarker(dir, started: now, clean: true)
    }

    static func redact(_ s: String, home: String = NSHomeDirectory()) -> String {
        guard !home.isEmpty, home != "/" else { return s }
        return s.replacingOccurrences(of: home, with: "~")
    }

    static func report(sections: [(title: String, rows: [(String, String)])], recent: [String],
                       previous: Previous? = nil, home: String = NSHomeDirectory()) -> String {
        var out = "SpotLyrics diagnostics\n======================\n"
        for sec in sections {
            out += "\n[\(sec.title)]\n"
            for (k, v) in sec.rows { out += "\(k): \(v)\n" }
        }
        out += "\n[Recent events]\n"
        out += recent.isEmpty ? "(none)\n" : recent.joined(separator: "\n") + "\n"
        if let p = previous {
            let ended = p.clean.map { $0 ? "yes" : "NO (possible crash)" } ?? "unknown (first run)"
            out += "\n[Previous session]\nEnded cleanly: \(ended)\n"
            if !p.lines.isEmpty { out += p.lines.suffix(20).joined(separator: "\n") + "\n" }
        }
        return redact(out, home: home)
    }

    static func size(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
}
