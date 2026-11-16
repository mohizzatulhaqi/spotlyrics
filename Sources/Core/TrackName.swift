import Foundation

enum TrackName {
    struct Variant: Equatable {
        let title: String
        let artist: String
    }

    private static let bracketStart = #"(?:feat\.?|ft\.?|featuring|with|prod\.?|live|radio edit|radio version|single version|album version|mono|stereo|bonus track|deluxe|explicit|clean|from\b)"#
    private static let bracketRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"\s*[\(\[]\s*"# + bracketStart + #"[^\)\]]*[\)\]]"#, options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: #"\s*[\(\[][^\)\]]*\bremaster(?:ed)?\b[^\)\]]*[\)\]]"#, options: [.caseInsensitive])
    ]
    private static let dashSuffix = try! NSRegularExpression(
        pattern: #"\s+[-–—]\s+(?:(?:\d{4}\s+)?remaster(?:ed)?\b.*|live\b.*|radio edit.*|radio version.*|single version.*|album version.*|mono\b.*|stereo\b.*|bonus track.*|from\b.*|feat\.?\s.*|ft\.?\s.*|with\s.*)$"#,
        options: [.caseInsensitive])
    private static let featTail = try! NSRegularExpression(pattern: #"\s+(?:feat\.?|ft\.?|featuring)\s+.*$"#, options: [.caseInsensitive])

    static func tidy(_ s: String) -> String {
        s.replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func cleanTitle(_ title: String) -> String {
        var s = tidy(title)
        for re in bracketRegexes {
            s = re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "")
        }
        for re in [dashSuffix, featTail] {
            s = re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "")
        }
        s = s.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-–—,;")))
        return s.isEmpty ? tidy(title) : s
    }

    static func firstArtist(_ artist: String, separators: [String]) -> String {
        var s = tidy(artist)
        for sep in separators {
            if let r = s.range(of: sep, options: .caseInsensitive) {
                let head = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !head.isEmpty { s = head }
            }
        }
        return s
    }

    static func variants(title: String, artist: String, limit: Int = 5) -> [Variant] {
        let t0 = tidy(title), a0 = tidy(artist)
        let t1 = cleanTitle(title)
        let a1 = firstArtist(artist, separators: [",", ";", " feat.", " ft.", " featuring "])
        let a2 = firstArtist(artist, separators: [" & ", " x ", "/"])
        var seen: Set<String> = [key(t0, a0)]
        var out: [Variant] = []
        for (t, a) in [(t1, a0), (t0, a1), (t1, a1), (t0, a2), (t1, a2)] {
            let k = key(t, a)
            if t.isEmpty || a.isEmpty || seen.contains(k) { continue }
            seen.insert(k)
            out.append(Variant(title: t, artist: a))
            if out.count >= limit { break }
        }
        return out
    }

    private static func key(_ t: String, _ a: String) -> String { normalize(t) + "|" + normalize(a) }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }

    static func similar(_ a: String, _ b: String) -> Bool {
        let x = normalize(cleanTitle(a)), y = normalize(cleanTitle(b))
        guard x.count >= 2, y.count >= 2 else { return false }
        return x == y || x.contains(y) || y.contains(x)
    }
}
