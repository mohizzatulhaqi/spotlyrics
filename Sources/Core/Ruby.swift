import Foundation

struct RubyToken: Equatable {
    let base: String
    let reading: String?
}

extension Readings {
    static func isHan(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) || $0.value == 0x3005 }
    }

    static func isHiragana(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0x3041...0x309F).contains($0.value) }
    }

    static func hasHan(_ s: String) -> Bool { s.contains(where: { isHan($0) }) }

    static func hasCyrillic(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }

    static func hasGreekOrDevanagari(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0370...0x03FF).contains($0.value) || (0x0900...0x097F).contains($0.value) }
    }

    static func japaneseTokens(_ s: String) -> [(text: String, romaji: String?)] {
        let ns = s as NSString
        let cf = s as CFString
        let tk = CFStringTokenizerCreate(nil, cf, CFRange(location: 0, length: CFStringGetLength(cf)),
                                         kCFStringTokenizerUnitWord, Locale(identifier: "ja") as CFLocale)
        var out: [(String, String?)] = []
        var cursor = 0
        while CFStringTokenizerAdvanceToNextToken(tk) != [] {
            let r = CFStringTokenizerGetCurrentTokenRange(tk)
            if r.location > cursor {
                out.append((ns.substring(with: NSRange(location: cursor, length: r.location - cursor)), nil))
            }
            let text = ns.substring(with: NSRange(location: r.location, length: r.length))
            let lat = CFStringTokenizerCopyCurrentTokenAttribute(tk, kCFStringTokenizerAttributeLatinTranscription) as? String
            out.append((text, lat))
            cursor = r.location + r.length
        }
        if cursor < ns.length { out.append((ns.substring(from: cursor), nil)) }
        return out.map { (text: $0.0, romaji: $0.1) }
    }

    static func hiraganaReading(_ romaji: String) -> String? {
        guard let k = romaji.applyingTransform(.latinToHiragana, reverse: false) else { return nil }
        let cleaned = k.replacingOccurrences(of: " ", with: "")
        return cleaned.isEmpty ? nil : cleaned
    }

    static func splitOkurigana(base: String, reading: String) -> (prefix: String, base: String, reading: String, suffix: String) {
        var b = Array(base), r = Array(reading)
        var prefix = "", suffix = ""
        while b.count > 1, r.count > 1, let f = b.first, isHiragana(f), f == r.first {
            prefix.append(f)
            b.removeFirst()
            r.removeFirst()
        }
        var tail: [Character] = []
        while b.count > 1, r.count > 1, let l = b.last, isHiragana(l), l == r.last {
            tail.insert(l, at: 0)
            b.removeLast()
            r.removeLast()
        }
        suffix = String(tail)
        return (prefix, String(b), String(r), suffix)
    }

    static func japaneseRuby(_ s: String) -> [RubyToken] {
        var out: [RubyToken] = []
        for t in japaneseTokens(s) {
            guard hasHan(t.text), let rom = t.romaji, let kana = hiraganaReading(rom) else {
                out.append(RubyToken(base: t.text, reading: nil))
                continue
            }
            let p = splitOkurigana(base: t.text, reading: kana)
            if !p.prefix.isEmpty { out.append(RubyToken(base: p.prefix, reading: nil)) }
            out.append(RubyToken(base: p.base, reading: p.reading))
            if !p.suffix.isEmpty { out.append(RubyToken(base: p.suffix, reading: nil)) }
        }
        return out
    }

    static func japaneseKana(_ s: String) -> String {
        japaneseTokens(s).map { t in
            if hasHan(t.text), let rom = t.romaji, let kana = hiraganaReading(rom) { return kana }
            return t.text
        }.joined()
    }

    static func pinyin(_ s: String) -> String {
        (s.applyingTransform(.mandarinToLatin, reverse: false) ?? "").trimmingCharacters(in: .whitespaces)
    }

    static let cyrillicMap: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo", "ж": "zh", "з": "z", "и": "i", "й": "y",
        "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f",
        "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
        "і": "i", "ї": "yi", "є": "ye", "ґ": "g"
    ]

    static func cyrillic(_ s: String, ukrainian: Bool = false) -> String {
        var out = ""
        for ch in s {
            let lower = Character(String(ch).lowercased())
            var key = lower
            if ukrainian {
                if lower == "г" { out += ch.isUppercase ? "H" : "h"; continue }
                if lower == "и" { out += ch.isUppercase ? "Y" : "y"; continue }
            }
            key = lower
            guard let m = cyrillicMap[key] else { out.append(ch); continue }
            if ch.isUppercase, let f = m.first { out += String(f).uppercased() + m.dropFirst() } else { out += m }
        }
        return out
    }

    static func greekOrDevanagari(_ s: String) -> String {
        let t = s.applyingTransform(.toLatin, reverse: false) ?? s
        return (t.applyingTransform(.stripDiacritics, reverse: false) ?? t).trimmingCharacters(in: .whitespaces)
    }

    static func reading(_ text: String, lang: String, style: String) -> String {
        let base = Locale.Language(identifier: lang).languageCode?.identifier ?? lang
        if base == "ja" && style == "furigana" {
            return hasHan(text) ? japaneseKana(text) : ""
        }
        return romanize(text, lang: lang)
    }
}
