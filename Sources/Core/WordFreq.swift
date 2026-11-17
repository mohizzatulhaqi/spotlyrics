import Foundation
import NaturalLanguage

struct WordCount: Equatable, Identifiable {
    let word: String
    let count: Int
    let sample: String
    let lang: String
    var id: String { Vocab.fold(word) }
}

enum WordFreq {
    static let taggerLanguages: Set<String> = ["en", "es", "fr", "de", "it", "pt", "nl", "sv", "da", "nb", "tr", "pl"]
    static let contentClasses: Set<NLTag> = [.noun, .verb, .adjective, .adverb]

    static let filler: Set<String> = ["oh", "ooh", "ohh", "ah", "aah", "yeah", "yea", "hey", "la", "na", "uh", "woah", "whoa", "mm", "mmm",
                                      "hmm", "nah", "ayy", "ay", "eh", "huh", "yo", "ha", "doo", "da", "ba", "sha", "woo", "ohoh"]

    static let stopwords: [String: Set<String>] = [
        "en": ["the", "and", "you", "your", "that", "this", "with", "for", "are", "was", "were", "but", "not", "have", "has", "had", "its", "all", "can", "will", "just", "when", "what", "from", "they", "them", "than", "then", "there", "been", "into", "out", "get", "got", "gonna", "wanna", "gotta", "dont", "cant", "wont", "ill", "ive", "youre", "thats", "cause"],
        "id": ["yang", "dan", "di", "ke", "dari", "untuk", "dengan", "pada", "dalam", "itu", "ini", "aku", "kamu", "kau", "dia", "kita", "kami", "mereka", "saya", "engkau", "ku", "mu", "nya", "tidak", "tak", "bukan", "belum", "sudah", "telah", "akan", "bisa", "dapat", "ada", "adalah", "ialah", "atau", "tapi", "tetapi", "karena", "agar", "supaya", "jika", "kalau", "saat", "ketika", "sebab", "lagi", "pun", "lah", "kah", "juga", "masih", "hanya", "saja", "sangat", "sekali", "oleh", "bagi", "seperti", "sampai", "hingga", "sebuah", "para", "apa", "siapa", "mana", "bagaimana", "kenapa", "mengapa", "tanpa", "antara", "lebih", "paling", "semua", "setiap", "setelah", "sebelum", "walau", "meski", "ya", "yaa", "nah", "deh", "sih", "dong", "kok"],
        "ja": ["の", "は", "を", "が", "に", "で", "と", "も", "へ", "や", "か", "よ", "ね", "な", "だ", "です", "ます", "た", "て", "し", "ない", "ある", "いる", "する", "なる", "こと", "もの", "これ", "それ", "あの", "その", "この", "から", "まで", "より", "だけ", "でも", "けど", "って", "ので", "のに", "さ", "ぞ", "わ", "ぜ"],
        "zh": ["的", "了", "我", "你", "他", "她", "它", "是", "不", "在", "就", "都", "也", "很", "和", "有", "这", "那", "个", "吗", "呢", "吧", "啊", "着", "过", "把", "被", "要", "会", "能", "去", "来", "到", "说", "对", "还", "没", "们"],
        "ru": ["я", "ты", "он", "она", "оно", "мы", "вы", "они", "и", "в", "не", "на", "что", "это", "как", "то", "но", "а", "с", "по", "за", "из", "у", "к", "о", "от", "для", "бы", "же", "ли", "мне", "тебя", "меня", "тебе", "его", "её", "их", "так", "все", "всё", "был", "была", "было", "были"],
        "ko": ["너무", "이제", "그냥", "정말", "진짜", "내가", "네가", "나는", "너는", "그리고", "하지만", "그래서", "그런데", "이", "그", "저", "나", "너", "더", "또", "다"]
    ]

    static func baseLanguage(_ code: String) -> String {
        Locale.Language(identifier: code).languageCode?.identifier ?? code
    }

    static func isKana(_ s: String) -> Bool {
        !s.isEmpty && s.unicodeScalars.allSatisfy { (0x3040...0x30FF).contains($0.value) }
    }

    static func keep(_ word: String, base: String) -> Bool {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty, w.contains(where: { $0.isLetter }) else { return false }
        let folded = Vocab.fold(w)
        if filler.contains(folded) { return false }
        if let sw = stopwords[base], sw.contains(w) || sw.contains(folded) { return false }
        if base == "ja" || base == "zh" {
            if isKana(w) && w.count <= 2 { return false }
            return true
        }
        if Readings.hasCJK(w) { return w.count >= 2 || base == "zh" }
        return w.filter { $0.isLetter }.count >= 3
    }

    static func tokens(in line: String, lang: String) -> [(display: String, key: String)] {
        let base = baseLanguage(lang)
        var out: [(String, String)] = []
        if taggerLanguages.contains(base) {
            let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
            tagger.string = line
            tagger.setLanguage(NLLanguage(rawValue: base), range: line.startIndex..<line.endIndex)
            tagger.enumerateTags(in: line.startIndex..<line.endIndex, unit: .word, scheme: .lexicalClass,
                                 options: [.omitWhitespace, .omitPunctuation, .omitOther]) { tag, r in
                guard let tag = tag, contentClasses.contains(tag) else { return true }
                let surface = String(line[r])
                let lemma = tagger.tag(at: r.lowerBound, unit: .word, scheme: .lemma).0?.rawValue ?? surface
                let display = lemma.lowercased()
                if keep(display, base: base) { out.append((display, Vocab.fold(display))) }
                return true
            }
        } else {
            let tk = NLTokenizer(unit: .word)
            tk.string = line
            tk.setLanguage(NLLanguage(rawValue: base))
            tk.enumerateTokens(in: line.startIndex..<line.endIndex) { r, _ in
                let w = String(line[r])
                if keep(w, base: base) { out.append((w.lowercased(), Vocab.fold(w))) }
                return true
            }
        }
        return out
    }

    static func top(lines: [String], langs: [String], exclude: Set<String> = [], limit: Int = 20, minCount: Int = 2) -> [WordCount] {
        var counts: [String: Int] = [:]
        var first: [String: (display: String, sample: String, lang: String)] = [:]
        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, t != "♪" else { continue }
            let lang = i < langs.count && !langs[i].isEmpty ? langs[i] : "en"
            for tok in tokens(in: t, lang: lang) where !exclude.contains(tok.key) {
                counts[tok.key, default: 0] += 1
                if first[tok.key] == nil { first[tok.key] = (tok.display, t, lang) }
            }
        }
        return counts.compactMap { k, c in
            guard c >= minCount, let f = first[k] else { return nil }
            return WordCount(word: f.display, count: c, sample: f.sample, lang: f.lang)
        }
        .sorted { $0.count != $1.count ? $0.count > $1.count : $0.word < $1.word }
        .prefix(limit)
        .map { $0 }
    }
}
