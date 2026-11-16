import Foundation

enum Diagnostics {
    static let capacity = 30
    private static let lock = NSLock()
    nonisolated(unsafe) private static var entries: [String] = []

    static func log(_ message: String, now: Date = Date()) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        lock.lock()
        defer { lock.unlock() }
        entries.append("\(f.string(from: now))  \(message)")
        if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
    }

    static var recent: [String] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    static func reset() {
        lock.lock()
        entries = []
        lock.unlock()
    }

    static func redact(_ s: String, home: String = NSHomeDirectory()) -> String {
        guard !home.isEmpty, home != "/" else { return s }
        return s.replacingOccurrences(of: home, with: "~")
    }

    static func report(sections: [(title: String, rows: [(String, String)])], recent: [String], home: String = NSHomeDirectory()) -> String {
        var out = "SpotLyrics diagnostics\n======================\n"
        for sec in sections {
            out += "\n[\(sec.title)]\n"
            for (k, v) in sec.rows { out += "\(k): \(v)\n" }
        }
        out += "\n[Recent events]\n"
        out += recent.isEmpty ? "(none)\n" : recent.joined(separator: "\n") + "\n"
        return redact(out, home: home)
    }

    static func size(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
}
