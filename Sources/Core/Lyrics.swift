import Foundation

// MARK: - LRCLIB

enum Lyrics {
    static let ua = "SpotLyrics/0.3 (https://github.com/mohizzatulhaqi/spotlyrics)"

    static func get(_ path: String, _ q: [String: String], reached: inout Bool) async -> Any? {
        var c = URLComponents(string: "https://lrclib.net/api/" + path)!
        c.queryItems = q.map { URLQueryItem(name: $0.key, value: $0.value) }
        var r = URLRequest(url: c.url!)
        r.setValue(ua, forHTTPHeaderField: "User-Agent")
        r.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: r),
              let h = resp as? HTTPURLResponse else { return nil }
        reached = true
        guard h.statusCode == 200 else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    static func hasNative(_ l: [Line]) -> Bool {
        let t = l.filter { !Detect.skippable($0.text) }
        guard !t.isEmpty else { return false }
        return Double(t.filter { Detect.script($0.text) != nil }.count) / Double(t.count) >= 0.3
    }

    static func load(title: String, artist: String, album: String, duration: Int, refresh: Bool = false) async -> [Line] {
        let cacheKey = "\(artist)|\(title)|\(duration)"
        let cached = Store.readLyrics(cacheKey)
        if !refresh, let c = cached {
            if !c.lines.isEmpty { return c.lines }
            if Date().timeIntervalSince(c.saved) < 86400 { return [] }
        }
        var reached = false
        let found = await fetch(title: title, artist: artist, album: album, duration: duration, reached: &reached)
        if !found.isEmpty {
            Store.writeLyrics(cacheKey, found)
            return found
        }
        if let c = cached, !c.lines.isEmpty { return c.lines }
        if reached {
            Store.writeLyrics(cacheKey, [])
            Diagnostics.log("lyrics: not found on LRCLIB")
        } else {
            Diagnostics.log("lyrics: LRCLIB unreachable")
        }
        return []
    }

    static func fetch(title: String, artist: String, album: String, duration: Int, reached: inout Bool) async -> [Line] {
        var strict: [(lines: [Line], native: Bool)] = []
        var loose: [(lines: [Line], native: Bool)] = []
        func add(_ j: [String: Any]) {
            guard let s = j["syncedLyrics"] as? String, !s.isEmpty else { return }
            let l = parse(s)
            if l.isEmpty { return }
            let c = (lines: l, native: hasNative(l))
            loose.append(c)
            let d = (j["duration"] as? NSNumber)?.doubleValue
            if duration <= 0 || d == nil || abs(d! - Double(duration)) <= 5 { strict.append(c) }
        }
        if let j = await get("get", ["track_name": title, "artist_name": artist,
                                     "album_name": album, "duration": String(duration)], reached: &reached) as? [String: Any] {
            add(j)
            if let f = strict.first, f.native { return f.lines }
        }
        if let arr = await get("search", ["q": "\(artist) \(title)"], reached: &reached) as? [[String: Any]] {
            for j in arr { add(j) }
        }
        let pool = strict.isEmpty ? loose : strict
        if let n = pool.first(where: { $0.native }) { return n.lines }
        return pool.first?.lines ?? []
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
