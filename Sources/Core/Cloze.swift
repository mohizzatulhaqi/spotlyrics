import Foundation
import NaturalLanguage

struct ClozeItem: Equatable {
    let lineIndex: Int
    let prompt: String
    let answer: String
}

enum Cloze {
    static let blank = "_____"

    static func candidates(in line: String) -> [Range<String.Index>] {
        let tk = NLTokenizer(unit: .word)
        tk.string = line
        var out: [Range<String.Index>] = []
        tk.enumerateTokens(in: line.startIndex..<line.endIndex) { r, _ in
            let w = String(line[r])
            let letters = w.filter { $0.isLetter }
            if Readings.hasCJK(w) {
                if letters.count >= 1 { out.append(r) }
            } else if letters.count >= 3 {
                out.append(r)
            }
            return true
        }
        return out
    }

    static func make(line: String, lineIndex: Int, pick: (Int) -> Int) -> ClozeItem? {
        let c = candidates(in: line)
        guard !c.isEmpty else { return nil }
        let r = c[min(max(0, pick(c.count)), c.count - 1)]
        var prompt = line
        prompt.replaceSubrange(r, with: blank)
        return ClozeItem(lineIndex: lineIndex, prompt: prompt, answer: String(line[r]))
    }

    static func eligible(lines: [String]) -> [Int] {
        lines.indices.filter { i in
            let t = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            return t != "♪" && candidates(in: t).count >= 2
        }
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }

    static func matches(answer: String, input: String) -> Bool {
        let n = normalize(input)
        return !n.isEmpty && n == normalize(answer)
    }
}
