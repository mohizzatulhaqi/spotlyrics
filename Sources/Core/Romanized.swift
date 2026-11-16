import Foundation

enum Romanized {
    static let japaneseWords: Set<String> = [
        "wa", "wo", "desu", "masu", "kimi", "boku", "watashi", "anata", "suki", "daisuki", "koi", "kokoro",
        "yume", "itsumo", "sayonara", "arigatou", "aishiteru", "onegai", "tsuki", "sora", "hoshi", "kaze",
        "hana", "namida", "egao", "mirai", "kimochi", "dakara", "kedo", "shita", "iru", "naku", "nakute",
        "mou", "motto", "zutto", "sekai", "hikari", "tomodachi", "omoi", "kanashii", "tanoshii", "ureshii",
        "koe", "ima", "kono", "sono", "ano", "nante", "datte", "demo", "tada", "mada", "yasashii", "owaranai"
    ]
    static let japaneseSuffixes = ["teru", "tteru", "shite", "mashita", "nakute", "itai", "imasu", "tai"]

    static let koreanWords: Set<String> = [
        "saranghae", "saranghaeyo", "naega", "neoreul", "neol", "nareul", "jigeum", "eodiya", "eotteoke",
        "wae", "aniya", "geudae", "geudaega", "neomu", "jeongmal", "haengbok", "maeum", "norae", "nunmul",
        "bogosipeo", "gidaryeo", "geureoke", "geurae", "mianhae", "gomawo", "oneul", "naeil", "uri", "neoui",
        "naui", "nae", "nega", "naneun", "neoneun", "geunyang", "hamkke", "sesang", "haneul", "byeol",
        "kkum", "chingu", "oppa", "daebak", "nuguna", "eonjena", "mworago", "geuraeseo", "hajiman"
    ]
    static let koreanSuffixes = ["haeyo", "hae", "neun", "reul", "eseo", "eoyo", "seumnida", "jyo", "geol", "geon", "eulgeoya"]

    static func tokens(_ lines: [String]) -> [String] {
        lines.flatMap { line in
            line.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        }.filter { $0.count >= 2 }
    }

    static func score(_ toks: [String], words: Set<String>, suffixes: [String]) -> (hits: Int, ratio: Double) {
        var hits = 0
        for t in toks {
            if words.contains(t) { hits += 1; continue }
            if t.count >= 5, suffixes.contains(where: { t.hasSuffix($0) }) { hits += 1 }
        }
        return (hits, toks.isEmpty ? 0 : Double(hits) / Double(toks.count))
    }

    static func guess(_ lines: [String]) -> String? {
        let text = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0 != "♪" }
        guard text.count >= 6 else { return nil }
        let cjk = text.filter { Readings.hasCJK($0) }.count
        if Double(cjk) / Double(text.count) > 0.2 { return nil }
        let toks = tokens(text)
        guard toks.count >= 30 else { return nil }
        let ja = score(toks, words: japaneseWords, suffixes: japaneseSuffixes)
        let ko = score(toks, words: koreanWords, suffixes: koreanSuffixes)
        let minHits = 6
        let minRatio = 0.12
        let jaOK = ja.hits >= minHits && ja.ratio >= minRatio
        let koOK = ko.hits >= minHits && ko.ratio >= minRatio
        if jaOK && koOK { return ja.ratio >= ko.ratio ? "ja-rom" : "ko-rom" }
        if jaOK { return "ja-rom" }
        if koOK { return "ko-rom" }
        return nil
    }
}
