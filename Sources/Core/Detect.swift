import Foundation
import NaturalLanguage

// MARK: - Per-line language detection

enum Detect {
    static func skippable(_ t: String) -> Bool {
        let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty || s == "♪"
    }

    static func script(_ t: String) -> String? {
        var hangul = 0, kana = 0
        for u in t.unicodeScalars {
            switch u.value {
            case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F: hangul += 1
            case 0x3040...0x30FF: kana += 1
            default: break
            }
        }
        if hangul > 0 && hangul >= kana { return "ko" }
        if kana > 0 { return "ja" }
        return nil
    }

    static func line(_ t: String, _ cands: [String]) -> String? {
        if let s = script(t), cands.isEmpty || cands.contains(where: { Lang.same($0, s) }) { return s }
        let tokens = t.lowercased().split(whereSeparator: { !$0.isLetter })
        if tokens.count < 3 || Set(tokens).count < 3 { return nil }
        let r = NLLanguageRecognizer()
        if !cands.isEmpty { r.languageConstraints = cands.map { NLLanguage(rawValue: $0 == "zh" ? "zh-Hans" : $0) } }
        r.processString(t)
        guard let top = r.languageHypotheses(withMaximum: 1).first, top.value >= (tokens.count < 5 ? 0.85 : 0.6) else { return nil }
        return top.key.rawValue
    }

    static func perLine(_ texts: [String], override: String? = nil) -> [String] {
        let mode = Prefs.sourceMode
        if let o = override { return texts.map { skippable($0) ? "" : o } }
        if mode == "fixed" {
            let f = Prefs.fixedSource
            return texts.map { skippable($0) ? "" : f }
        }
        let cands = mode == "limited" ? Prefs.candidates : []
        let raw: [String?] = texts.map { skippable($0) ? nil : line($0, cands) }

        var counts = [String: Int]()
        for l in raw { if let l = l { counts[l, default: 0] += 1 } }
        var dominant = counts.max { $0.value < $1.value }?.key
        if dominant == nil {
            if let c = cands.first { dominant = c } else {
                let r = NLLanguageRecognizer()
                r.processString(String(texts.filter { !skippable($0) }.joined(separator: "\n").prefix(3000)))
                dominant = r.dominantLanguage?.rawValue
            }
        }

        var out = Array(repeating: "", count: texts.count)
        for i in texts.indices {
            if skippable(texts[i]) { continue }
            if let l = raw[i] { out[i] = l; continue }
            var found: String?
            var d = 1
            while found == nil, i - d >= 0 || i + d < texts.count {
                if i - d >= 0, let l = raw[i - d] { found = l }
                else if i + d < texts.count, let l = raw[i + d] { found = l }
                d += 1
            }
            out[i] = found ?? dominant ?? ""
        }
        return out
    }
}
