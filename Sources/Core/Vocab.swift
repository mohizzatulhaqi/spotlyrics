import Foundation

// MARK: - Vocabulary + Anki export

struct VocabEntry: Codable, Equatable, Identifiable {
    var word: String
    var meaning: String
    var line: String
    var song: String
    var date: Date
    var lang: String?
    var reading: String?
    var lineReading: String?
    var lineTranslation: String?
    var due: Date?
    var interval: Double?
    var ease: Double?
    var reps: Int?
    var lapses: Int?
    var lastReview: Date?

    var id: String { word.lowercased() }
}

enum Vocab {
    static var file: URL { Store.dir.appendingPathComponent("vocab.json") }

    static func load(from url: URL = Vocab.file) -> [VocabEntry] {
        guard let d = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([VocabEntry].self, from: d)) ?? []
    }

    static func save(_ entries: [VocabEntry], to url: URL = Vocab.file) {
        if let d = try? JSONEncoder().encode(entries) { try? d.write(to: url, options: .atomic) }
    }

    @discardableResult
    static func add(_ e: VocabEntry, to url: URL = Vocab.file) -> Int {
        var all = load(from: url)
        all.removeAll { $0.id == e.id }
        all.append(e)
        save(all, to: url)
        return all.count
    }

    @discardableResult
    static func remove(ids: Set<String>, from url: URL = Vocab.file) -> Int {
        let kept = load(from: url).filter { !ids.contains($0.id) }
        save(kept, to: url)
        return kept.count
    }

    static func saveEntry(_ e: VocabEntry, in url: URL = Vocab.file) {
        var all = load(from: url)
        guard let i = all.firstIndex(where: { $0.id == e.id }) else { return }
        all[i] = e
        save(all, to: url)
    }

    static func setMeaning(id: String, _ meaning: String, in url: URL = Vocab.file) {
        var all = load(from: url)
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        all[i].meaning = meaning
        save(all, to: url)
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    static func filter(_ entries: [VocabEntry], query: String, song: String) -> [VocabEntry] {
        let q = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return entries.filter { e in
            if !song.isEmpty && e.song != song { return false }
            if q.isEmpty { return true }
            return [e.word, e.meaning, e.line, e.song, e.reading ?? "", e.lineTranslation ?? ""].contains { fold($0).contains(q) }
        }
    }

    static func songs(_ entries: [VocabEntry]) -> [String] {
        Array(Set(entries.map { $0.song }.filter { !$0.isEmpty })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func stats(_ entries: [VocabEntry], now: Date = Date(), calendar: Calendar = .current) -> (total: Int, today: Int, week: Int) {
        let weekAgo = now.addingTimeInterval(-7 * 86400)
        return (entries.count,
                entries.filter { calendar.isDate($0.date, inSameDayAs: now) }.count,
                entries.filter { $0.date >= weekAgo }.count)
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

    static func tsv(_ entries: [VocabEntry]) -> String {
        func clean(_ s: String) -> String {
            s.replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "<br>")
        }
        var out = "#separator:tab\n#html:true\n"
        for e in entries {
            var back = clean(e.meaning)
            if let r = e.reading, !r.isEmpty { back = clean(r) + "<br>" + back }
            back += "<br><br><i>" + clean(e.line) + "</i>"
            if let lr = e.lineReading, !lr.isEmpty { back += "<br>" + clean(lr) }
            if let lt = e.lineTranslation, !lt.isEmpty { back += "<br>" + clean(lt) }
            back += "<br>" + clean(e.song)
            out += clean(e.word) + "\t" + back + "\n"
        }
        return out
    }

    static func downloads(_ name: String) -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }

    static func exportCSV(_ entries: [VocabEntry]) -> URL? {
        guard !entries.isEmpty else { return nil }
        let url = downloads("SpotLyrics-vocab.csv")
        do { try csv(entries).write(to: url, atomically: true, encoding: .utf8) } catch { return nil }
        return url
    }

    static func exportAnki(_ entries: [VocabEntry]) -> URL? {
        guard !entries.isEmpty else { return nil }
        let url = downloads("SpotLyrics-vocab.tsv")
        do { try tsv(entries).write(to: url, atomically: true, encoding: .utf8) } catch { return nil }
        return url
    }
}
