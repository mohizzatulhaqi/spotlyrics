import Foundation

struct DayCount: Codable, Equatable {
    var reviews: Int
    var correct: Int
}

enum ReviewLog {
    static var file: URL { Store.dir.appendingPathComponent("reviewlog.json") }

    static func dayKey(_ d: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func load(from url: URL = ReviewLog.file) -> [String: DayCount] {
        guard let d = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: DayCount].self, from: d)) ?? [:]
    }

    static func save(_ log: [String: DayCount], to url: URL = ReviewLog.file) {
        if let d = try? JSONEncoder().encode(log) { try? d.write(to: url, options: .atomic) }
    }

    static func record(_ rating: Rating, at now: Date = Date(), to url: URL = ReviewLog.file, calendar: Calendar = .current) {
        var log = load(from: url)
        let k = dayKey(now, calendar: calendar)
        var c = log[k] ?? DayCount(reviews: 0, correct: 0)
        c.reviews += 1
        if rating != .again { c.correct += 1 }
        log[k] = c
        save(log, to: url)
    }

    static func merge(_ a: [String: DayCount], _ b: [String: DayCount]) -> [String: DayCount] {
        var out = a
        for (k, v) in b {
            if let cur = out[k] {
                out[k] = DayCount(reviews: max(cur.reviews, v.reviews), correct: max(cur.correct, v.correct))
            } else {
                out[k] = v
            }
        }
        return out
    }

    struct Summary: Equatable {
        var today: Int
        var week: Int
        var accuracy: Int?
        var streak: Int
        var known: Int
    }

    static func summary(log: [String: DayCount], entries: [VocabEntry], now: Date = Date(), calendar: Calendar = .current) -> Summary {
        let today = log[dayKey(now, calendar: calendar)]?.reviews ?? 0
        var week = 0, weekCorrect = 0
        for i in 0..<7 {
            guard let d = calendar.date(byAdding: .day, value: -i, to: now), let c = log[dayKey(d, calendar: calendar)] else { continue }
            week += c.reviews
            weekCorrect += c.correct
        }
        var streak = 0
        var offset = today > 0 ? 0 : 1
        while let d = calendar.date(byAdding: .day, value: -offset, to: now), (log[dayKey(d, calendar: calendar)]?.reviews ?? 0) > 0 {
            streak += 1
            offset += 1
        }
        let known = entries.filter { SRS.status(of: $0) == .known }.count
        return Summary(today: today, week: week, accuracy: week > 0 ? Int((Double(weekCorrect) / Double(week) * 100).rounded()) : nil,
                       streak: streak, known: known)
    }
}

enum Backup {
    struct Payload: Codable {
        var version: Int
        var exported: Date
        var vocab: [VocabEntry]
        var log: [String: DayCount]
    }

    struct Result: Equatable {
        var added: Int
        var updated: Int
        var total: Int
    }

    static func encode(vocab: [VocabEntry], log: [String: DayCount], now: Date = Date()) -> Data? {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? e.encode(Payload(version: 1, exported: now, vocab: vocab, log: log))
    }

    static func decode(_ data: Data) -> Payload? {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        if let p = try? d.decode(Payload.self, from: data), p.version == 1 { return p }
        if let arr = try? JSONDecoder().decode([VocabEntry].self, from: data) {
            return Payload(version: 1, exported: Date(), vocab: arr, log: [:])
        }
        return nil
    }

    static func newer(_ a: VocabEntry, _ b: VocabEntry) -> VocabEntry {
        let la = a.lastReview ?? .distantPast
        let lb = b.lastReview ?? .distantPast
        if la != lb { return la > lb ? a : b }
        return a.date >= b.date ? a : b
    }

    static func merge(_ current: [VocabEntry], with incoming: [VocabEntry]) -> (entries: [VocabEntry], result: Result) {
        var map = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var added = 0, updated = 0
        for e in incoming {
            if let cur = map[e.id] {
                let pick = newer(cur, e)
                if pick != cur { updated += 1 }
                map[e.id] = pick
            } else {
                map[e.id] = e
                added += 1
            }
        }
        let all = map.values.sorted { $0.date < $1.date }
        return (all, Result(added: added, updated: updated, total: all.count))
    }

    static func fileName(now: Date = Date()) -> String { "SpotLyrics-backup-\(ReviewLog.dayKey(now)).json" }
}
