import Foundation

// MARK: - LRCLIB

enum Lyrics {
    static let ua = "SpotLyrics/0.3 (https://github.com/mohizzatulhaqi/spotlyrics)"

    enum Reply: Equatable {
        case found, notFound, retry, failed
    }

    static func reply(for status: Int) -> Reply {
        switch status {
        case 200: return .found
        case 404: return .notFound
        case 429, 500...599: return .retry
        default: return .failed
        }
    }

    static func get(_ path: String, _ q: [String: String], reached: inout Bool) async -> Any? {
        var c = URLComponents(string: "https://lrclib.net/api/" + path)!
        c.queryItems = q.map { URLQueryItem(name: $0.key, value: $0.value) }
        var r = URLRequest(url: c.url!)
        r.setValue(ua, forHTTPHeaderField: "User-Agent")
        r.timeoutInterval = 15
        for attempt in 0..<2 {
            guard let (data, resp) = try? await URLSession.shared.data(for: r), let h = resp as? HTTPURLResponse else {
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    continue
                }
                return nil
            }
            switch reply(for: h.statusCode) {
            case .found:
                reached = true
                return try? JSONSerialization.jsonObject(with: data)
            case .notFound:
                reached = true
                return nil
            case .retry:
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }
                Diagnostics.log("lrclib: HTTP \(h.statusCode) (temporary, will retry later)")
                return nil
            case .failed:
                Diagnostics.log("lrclib: unexpected HTTP \(h.statusCode)")
                return nil
            }
        }
        return nil
    }

    static func hasNative(_ l: [Line]) -> Bool {
        let t = l.filter { !Detect.skippable($0.text) }
        guard !t.isEmpty else { return false }
        return Double(t.filter { Detect.script($0.text) != nil }.count) / Double(t.count) >= 0.3
    }

    static func cacheKey(artist: String, title: String, duration: Int) -> String { "\(artist)|\(title)|\(duration)" }

    static func pin(_ key: String, _ option: LyricsOption) {
        Store.writeLyrics(key, option.lines, synced: option.synced, pinned: true)
    }

    static func unpin(_ key: String) { Store.removeLyrics(key) }

    static func options(title: String, artist: String, duration: Int, reached: inout Bool) async -> [LyricsOption] {
        var found: [LyricsOption] = []
        var queries = ["\(artist) \(title)"]
        for v in TrackName.variants(title: title, artist: artist, limit: 2) { queries.append("\(v.artist) \(v.title)") }
        for q in queries {
            if let arr = await get("search", ["q": q], reached: &reached) as? [[String: Any]] {
                found += arr.compactMap { LyricsOption.from(json: $0) }
            }
        }
        return Array(LyricsOption.ranked(found, target: duration).prefix(20))
    }

    static let plainRecheck: TimeInterval = 7 * 86400
    static let negativeRecheck: TimeInterval = 86400

    struct Candidate: Equatable {
        var lines: [Line]
        var native: Bool
        var synced: Bool
    }

    static func plainLines(_ text: String) -> [Line] {
        var out: [Line] = []
        for raw in text.components(separatedBy: .newlines) {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.isEmpty && (out.last?.text.isEmpty ?? true) { continue }
            out.append(Line(time: 0, text: t))
        }
        while out.last?.text.isEmpty == true { out.removeLast() }
        return out
    }

    static func choose(strict: [Candidate], loose: [Candidate]) -> Candidate? {
        let pools = [strict.filter { $0.synced }, loose.filter { $0.synced },
                     strict.filter { !$0.synced }, loose.filter { !$0.synced }]
        for pool in pools {
            if let c = pool.first(where: { $0.native }) ?? pool.first { return c }
        }
        return nil
    }

    static func load(title: String, artist: String, album: String, duration: Int, refresh: Bool = false) async -> LyricsResult {
        let cacheKey = Lyrics.cacheKey(artist: artist, title: title, duration: duration)
        let cached = Store.readLyrics(cacheKey)
        if !refresh, let c = cached, c.isPinned, !c.lines.isEmpty {
            return LyricsResult(lines: c.lines, synced: c.isSynced)
        }
        if !refresh, let c = cached {
            let age = Date().timeIntervalSince(c.saved)
            if !c.lines.isEmpty && (c.isSynced || age < plainRecheck) { return LyricsResult(lines: c.lines, synced: c.isSynced) }
            if c.lines.isEmpty && age < negativeRecheck { return .empty }
        }
        var reached = false
        let found = await fetch(title: title, artist: artist, album: album, duration: duration, reached: &reached)
        if let f = found {
            Store.writeLyrics(cacheKey, f.lines, synced: f.synced)
            if !f.synced { Diagnostics.log("lyrics: only unsynced lyrics found") }
            return LyricsResult(lines: f.lines, synced: f.synced)
        }
        if let c = cached, !c.lines.isEmpty { return LyricsResult(lines: c.lines, synced: c.isSynced) }
        if reached {
            Store.writeLyrics(cacheKey, [])
            Diagnostics.log("lyrics: not found on LRCLIB")
        } else {
            Diagnostics.log("lyrics: LRCLIB unreachable")
        }
        return .empty
    }

    static func fetch(title: String, artist: String, album: String, duration: Int, reached: inout Bool,
                      useVariants: Bool = true) async -> Candidate? {
        var strict: [Candidate] = []
        var loose: [Candidate] = []
        let wanted = TrackName.cleanTitle(title)
        func add(_ j: [String: Any]) {
            var c: Candidate?
            if let s = j["syncedLyrics"] as? String, !s.isEmpty {
                let l = parse(s)
                if !l.isEmpty { c = Candidate(lines: l, native: hasNative(l), synced: true) }
            }
            if c == nil, let p = j["plainLyrics"] as? String, !p.isEmpty, (j["instrumental"] as? Bool) != true {
                let l = plainLines(p)
                if l.filter({ !$0.text.isEmpty }).count >= 4 { c = Candidate(lines: l, native: hasNative(l), synced: false) }
            }
            guard let cand = c else { return }
            let d = (j["duration"] as? NSNumber)?.doubleValue
            if duration <= 0 || d == nil || abs(d! - Double(duration)) <= 5 {
                strict.append(cand)
                loose.append(cand)
            } else if let name = j["trackName"] as? String, TrackName.similar(name, wanted) {
                loose.append(cand)
            }
        }
        if let j = await get("get", ["track_name": title, "artist_name": artist,
                                     "album_name": album, "duration": String(duration)], reached: &reached) as? [String: Any] {
            add(j)
            if let f = strict.first, f.native, f.synced { return f }
        }
        if let arr = await get("search", ["q": "\(artist) \(title)"], reached: &reached) as? [[String: Any]] {
            for j in arr { add(j) }
        }
        if let found = choose(strict: strict, loose: loose) { return found }
        guard useVariants else { return nil }
        for v in TrackName.variants(title: title, artist: artist) {
            if let arr = await get("search", ["q": "\(v.artist) \(v.title)"], reached: &reached) as? [[String: Any]] {
                for j in arr { add(j) }
            }
            if let found = choose(strict: strict, loose: loose) { return found }
        }
        return nil
    }

    static func parse(_ lrc: String) -> [Line] {
        let re = try! NSRegularExpression(pattern: #"\[(\d+):(\d+(?:\.\d+)?)\]"#)
        var out = [Line]()
        for raw in lrc.components(separatedBy: .newlines) {
            let ns = raw as NSString
            let ms = re.matches(in: raw, range: NSRange(location: 0, length: ns.length))
            guard let last = ms.last else { continue }
            let text = ns.substring(from: last.range.location + last.range.length)
                .trimmingCharacters(in: .whitespaces)
            for m in ms {
                let mm = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let ss = Double(ns.substring(with: m.range(at: 2))) ?? 0
                out.append(Line(time: mm * 60 + ss, text: text))
            }
        }
        return out.sorted { $0.time < $1.time }
    }
}
