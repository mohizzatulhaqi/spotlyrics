import Foundation

// MARK: - Vocabulary + Anki export

struct VocabEntry: Codable {
    var word: String
    var meaning: String
    var line: String
    var song: String
    var date: Date
    var lang: String?
}

enum Vocab {
    static var file: URL { Store.dir.appendingPathComponent("vocab.json") }

    static func load() -> [VocabEntry] {
        guard let d = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([VocabEntry].self, from: d)) ?? []
    }

    @discardableResult
    static func add(_ e: VocabEntry) -> Int {
        var all = load()
        all.removeAll { $0.word.lowercased() == e.word.lowercased() }
        all.append(e)
        if let d = try? JSONEncoder().encode(all) { try? d.write(to: file, options: .atomic) }
        return all.count
    }

    static func csvField(_ s: String) -> String {
        if s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    static func csv(_ entries: [VocabEntry]) -> String {
        let f = ISO8601DateFormatter()
        var out = "word,meaning,line,song,date\n"
        for e in entries {
            out += [e.word, e.meaning, e.line, e.song, f.string(from: e.date)].map { csvField($0) }.joined(separator: ",") + "\n"
        }
        return out
    }

    static func downloads(_ name: String) -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }

    static func exportCSV() -> URL? {
        let all = load()
        guard !all.isEmpty else { return nil }
        let url = downloads("SpotLyrics-vocab.csv")
        do { try csv(all).write(to: url, atomically: true, encoding: .utf8) } catch { return nil }
        return url
    }

    static func exportAnki() -> URL? {
        let all = load()
        guard !all.isEmpty else { return nil }
        func clean(_ s: String) -> String {
            s.replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "<br>")
        }
        var out = "#separator:tab\n#html:true\n"
        for e in all {
            let back = clean(e.meaning) + "<br><br><i>" + clean(e.line) + "</i><br>" + clean(e.song)
            out += clean(e.word) + "\t" + back + "\n"
        }
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("SpotLyrics-vocab.tsv")
        do { try out.write(to: url, atomically: true, encoding: .utf8) } catch { return nil }
        return url
    }
}
