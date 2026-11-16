import Foundation

struct LyricsOption: Identifiable, Equatable {
    let id: Int
    let artist: String
    let track: String
    let album: String
    let duration: Double?
    let synced: Bool
    let native: Bool
    let lines: [Line]

    static func from(json j: [String: Any]) -> LyricsOption? {
        guard (j["instrumental"] as? Bool) != true else { return nil }
        let id = (j["id"] as? NSNumber)?.intValue ?? -1
        var lines: [Line] = []
        var synced = false
        if let s = j["syncedLyrics"] as? String, !s.isEmpty {
            lines = Lyrics.parse(s)
            synced = !lines.isEmpty
        }
        if lines.isEmpty, let p = j["plainLyrics"] as? String, !p.isEmpty {
            lines = Lyrics.plainLines(p)
        }
        guard lines.contains(where: { !$0.text.isEmpty }) else { return nil }
        return LyricsOption(id: id,
                            artist: (j["artistName"] as? String) ?? "",
                            track: (j["trackName"] as? String) ?? "",
                            album: (j["albumName"] as? String) ?? "",
                            duration: (j["duration"] as? NSNumber)?.doubleValue,
                            synced: synced,
                            native: Lyrics.hasNative(lines),
                            lines: lines)
    }

    func durationDiff(from target: Int) -> Double? {
        guard let d = duration, target > 0 else { return nil }
        return d - Double(target)
    }

    var preview: String {
        lines.map { $0.text }.filter { !$0.isEmpty }.prefix(6).joined(separator: "\n")
    }

    func matches(current: [Line]) -> Bool {
        !current.isEmpty && lines.count == current.count && lines.first?.text == current.first?.text
            && lines.last?.text == current.last?.text
    }

    static func ranked(_ options: [LyricsOption], target: Int) -> [LyricsOption] {
        var seen = Set<Int>()
        let unique = options.filter { o in
            if o.id < 0 { return true }
            return seen.insert(o.id).inserted
        }
        return unique.sorted { a, b in
            if a.synced != b.synced { return a.synced }
            let da = a.durationDiff(from: target).map { abs($0) }
            let db = b.durationDiff(from: target).map { abs($0) }
            if da != db {
                switch (da, db) {
                case (nil, _): return false
                case (_, nil): return true
                case let (x?, y?): return x < y
                }
            }
            if a.native != b.native { return a.native }
            return a.id < b.id
        }
    }
}
