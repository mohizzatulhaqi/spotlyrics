import Foundation

// MARK: - Romaji / romanization to native script

enum Romaji {
    static func base(_ tag: String) -> String? { tag == "ja-rom" ? "ja" : tag == "ko-rom" ? "ko" : nil }

    static func convert(_ text: String, _ tag: String) -> String {
        if tag == "ja-rom" {
            var s = text
            for (pat, rep) in [(#"(?<![A-Za-z'])wa(?![A-Za-z'])"#, "ha"),
                               (#"(?<![A-Za-z'])e(?![A-Za-z'])"#, "he"),
                               (#"(?<![A-Za-z'])o(?![A-Za-z'])"#, "wo")] {
                s = s.replacingOccurrences(of: pat, with: rep, options: [.regularExpression, .caseInsensitive])
            }
            return s.applyingTransform(.latinToHiragana, reverse: false) ?? text
        }
        if tag == "ko-rom" { return text.applyingTransform(.latinToHangul, reverse: false) ?? text }
        return text
    }
}

// MARK: - Readings (romaji / Korean romanization)

enum Readings {
    static func hasCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains {
            (0xAC00...0xD7AF).contains($0.value) || (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
        }
    }

    static func romanize(_ text: String, lang: String) -> String {
        let base = Locale.Language(identifier: lang).languageCode?.identifier ?? lang
        switch base {
        case "ja": return hasCJK(text) ? japanese(text) : ""
        case "ko": return hasCJK(text) ? korean(text) : ""
        case "zh": return hasHan(text) ? pinyin(text) : ""
        case "ru": return hasCyrillic(text) ? cyrillic(text) : ""
        case "uk": return hasCyrillic(text) ? cyrillic(text, ukrainian: true) : ""
        case "el", "hi": return hasGreekOrDevanagari(text) ? greekOrDevanagari(text) : ""
        default: return ""
        }
    }

    static func japanese(_ s: String) -> String {
        let cf = s as CFString
        let tk = CFStringTokenizerCreate(nil, cf, CFRange(location: 0, length: CFStringGetLength(cf)),
                                         kCFStringTokenizerUnitWord, Locale(identifier: "ja") as CFLocale)
        var parts: [String] = []
        while CFStringTokenizerAdvanceToNextToken(tk) != [] {
            let r = CFStringTokenizerGetCurrentTokenRange(tk)
            let tok = (s as NSString).substring(with: NSRange(location: r.location, length: r.length))
            var lat = CFStringTokenizerCopyCurrentTokenAttribute(tk, kCFStringTokenizerAttributeLatinTranscription) as? String ?? tok
            switch tok {
            case "は": lat = "wa"
            case "へ": lat = "e"
            case "を": lat = "o"
            default: break
            }
            parts.append(lat)
        }
        var out = parts.joined(separator: " ")
        for (pat, rep) in [("~tsu ?ch", "tch"), ("~tsu ?([a-z])", "$1$1"), ("~tsu", "")] {
            out = out.replacingOccurrences(of: pat, with: rep, options: .regularExpression)
        }
        return out
    }

    static let ini = ["g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"]
    static let vow = ["a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae", "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"]
    static let coda = ["", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l", "l", "l", "p", "l", "m", "p", "p", "t", "t", "ng", "t", "t", "k", "t", "p", "t"]
    static let stay = ["", "", "", "k", "", "n", "n", "", "", "l", "l", "l", "l", "l", "l", "l", "", "", "p", "", "", "", "", "", "", "", "", ""]
    static let move = ["", "g", "kk", "s", "n", "j", "", "d", "r", "g", "m", "b", "s", "t", "p", "", "m", "b", "s", "s", "ss", "", "j", "ch", "k", "t", "p", ""]

    static func korean(_ s: String) -> String {
        let chars = Array(s.unicodeScalars)
        let syl: [(Int, Int, Int)?] = chars.map {
            guard (0xAC00...0xD7A3).contains($0.value) else { return nil }
            let c = Int($0.value) - 0xAC00
            return (c / 588, (c % 588) / 28, c % 28)
        }
        var out = ""
        var carry: String?
        for k in chars.indices {
            guard let (i, v, f) = syl[k] else {
                out.unicodeScalars.append(chars[k])
                carry = nil
                continue
            }
            var onset = ini[i]
            if let c = carry { onset = c; carry = nil }
            out += onset + vow[v]
            if f == 0 { continue }
            guard k + 1 < chars.count, let nx = syl[k + 1] else { out += coda[f]; continue }
            let n = nx.0
            if n == 11 && f != 21 {
                out += stay[f]
                carry = move[f]
                if nx.1 == 20 && f == 25 { carry = "ch" }
                if nx.1 == 20 && f == 7 { carry = "j" }
                continue
            }
            var c = coda[f]
            if f == 27, let ai = [0, 3, 12].firstIndex(of: n) {
                c = ""
                carry = ["k", "t", "ch"][ai]
            } else if n == 2 || n == 6 {
                if c == "k" { c = "ng" } else if c == "t" { c = "n" } else if c == "p" { c = "m" }
            } else if c == "n" && n == 5 {
                c = "l"; carry = "l"
            } else if c == "l" && n == 2 {
                carry = "l"
            }
            out += c
        }
        return out
    }
}
