import Foundation

enum Casual {
    static let indonesian: [(String, String)] = [
        (#"\bsangat (\p{L}+)"#, "$1 banget"),
        (#"\bsangat\b"#, "banget"),
        (#"\bAnda\b"#, "kamu"),
        (#"\bsaya\b"#, "aku"),
        (#"\btidak\b"#, "nggak"),
        (#"\bsedang\b"#, "lagi"),
        (#"\bmengapa\b"#, "kenapa"),
        (#"\bbagaimana\b"#, "gimana"),
        (#"\bsudah\b"#, "udah"),
        (#"\bsaja\b"#, "aja"),
        (#"\bhanya\b"#, "cuma"),
        (#"\bseperti\b"#, "kayak"),
        (#"\bjika\b"#, "kalau"),
        (#"\bapabila\b"#, "kalau"),
        (#"\bnamun\b"#, "tapi"),
        (#"\btetapi\b"#, "tapi"),
        (#"\bkemudian\b"#, "terus"),
        (#"\bmemiliki\b"#, "punya"),
        (#"\bmengatakan\b"#, "bilang"),
        (#"\bberbicara\b"#, "ngomong"),
        (#"\bbilang bahwa\b"#, "bilang"),
        (#"\bhendak\b"#, "mau"),
        (#"\bapakah\b"#, "apa")
    ]

    static let english: [(String, String)] = [
        (#"\bI am\b"#, "I'm"), (#"\byou are\b"#, "you're"), (#"\bwe are\b"#, "we're"), (#"\bthey are\b"#, "they're"),
        (#"\bdo not\b"#, "don't"), (#"\bdoes not\b"#, "doesn't"), (#"\bdid not\b"#, "didn't"),
        (#"\bcannot\b"#, "can't"), (#"\bwill not\b"#, "won't"),
        (#"\bis not\b"#, "isn't"), (#"\bare not\b"#, "aren't"), (#"\bwas not\b"#, "wasn't"),
        (#"\bit is\b"#, "it's"), (#"\bthat is\b"#, "that's"),
        (#"\bI will\b"#, "I'll"), (#"\bI have\b"#, "I've"), (#"\bI would\b"#, "I'd"),
        (#"\blet us\b"#, "let's"), (#"\bwant to\b"#, "wanna")
    ]

    static func rules(for target: String) -> [(String, String)] {
        let base = Locale.Language(identifier: target).languageCode?.identifier ?? target
        switch base {
        case "id": return indonesian
        case "en": return english
        default: return []
        }
    }

    static func apply(_ text: String, target: String) -> String {
        var s = text
        for (pat, rep) in rules(for: target) {
            guard let re = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) else { continue }
            let ns = s as NSString
            let matches = re.matches(in: s, range: NSRange(location: 0, length: ns.length))
            for m in matches.reversed() {
                let original = ns.substring(with: m.range)
                var out = re.replacementString(for: m, in: s, offset: 0, template: rep)
                if let f = original.first, f.isUppercase, atSentenceStart(s as NSString, m.range.location),
                   let o = out.first, o.isLowercase {
                    out = o.uppercased() + out.dropFirst()
                }
                s = (s as NSString).replacingCharacters(in: m.range, with: out)
            }
        }
        return s
    }

    static func atSentenceStart(_ s: NSString, _ loc: Int) -> Bool {
        var i = loc - 1
        while i >= 0, let u = Unicode.Scalar(s.character(at: i)), CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"'“‘(¿¡-")).contains(u) { i -= 1 }
        if i < 0 { return true }
        return [".", "!", "?", "…"].contains(Character(Unicode.Scalar(s.character(at: i)) ?? " "))
    }

    static func apply(_ lines: [String], target: String) -> [String] {
        lines.map { $0.isEmpty ? $0 : apply($0, target: target) }
    }
}
