import Foundation
import SQLite3
import CryptoKit

struct AnkiNote: Equatable {
    var word: String
    var meaning: String
    var line: String
    var song: String
    var wordAudio: String?
    var lineAudio: String?
    var reading: String = ""
    var lineReading: String = ""
    var lineTranslation: String = ""
    var tags: [String] = []
    var reverse: Bool = false
}

struct AnkiMedia: Equatable {
    let name: String
    let url: URL
}

enum AnkiError: Error, Equatable {
    case sqlite(String)
    case zip(Int32)
    case io(String)
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteDB {
    private var db: OpaquePointer?

    init(path: String, readOnly: Bool = false) throws {
        let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK else {
            throw AnkiError.sqlite("open: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    deinit { sqlite3_close(db) }

    func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
            let m = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw AnkiError.sqlite(m)
        }
    }

    func run(_ sql: String, _ params: [Any]) throws {
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else {
            throw AnkiError.sqlite("prepare: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(st) }
        for (i, p) in params.enumerated() {
            let idx = Int32(i + 1)
            if let v = p as? Int { sqlite3_bind_int64(st, idx, Int64(v)) }
            else if let v = p as? Int64 { sqlite3_bind_int64(st, idx, v) }
            else if let v = p as? String { sqlite3_bind_text(st, idx, v, -1, sqliteTransient) }
        }
        guard sqlite3_step(st) == SQLITE_DONE else { throw AnkiError.sqlite("step: \(String(cString: sqlite3_errmsg(db)))") }
    }

    func rows(_ sql: String) -> [[String]] {
        var st: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(st) }
        var out: [[String]] = []
        while sqlite3_step(st) == SQLITE_ROW {
            let n = Int(sqlite3_column_count(st))
            out.append((0..<n).map { i in sqlite3_column_text(st, Int32(i)).map { String(cString: $0) } ?? "" })
        }
        return out
    }
}

enum AnkiPackage {
    static let fieldNames = ["Word", "Reading", "Meaning", "Line", "LineReading", "LineTranslation", "Song", "WordAudio", "LineAudio", "Reverse"]
    static let modelName = "SpotLyrics Vocabulary"
    static let stableModelID = 1_732_000_000_123
    static let stableDeckID = 1_732_000_000_456
    static let separator = "\u{1f}"

    static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    static func sha1Hex(_ s: String) -> String {
        Insecure.SHA1.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func guid(for n: AnkiNote) -> String { String(sha1Hex(n.word.lowercased() + "|" + n.song).prefix(10)) }

    static func checksum(_ s: String) -> Int { Int(sha1Hex(s).prefix(8), radix: 16) ?? 0 }

    static func fields(_ n: AnkiNote) -> [String] {
        [htmlEscape(n.word), htmlEscape(n.reading), htmlEscape(n.meaning), htmlEscape(n.line), htmlEscape(n.lineReading),
         htmlEscape(n.lineTranslation), htmlEscape(n.song),
         n.wordAudio.map { "[sound:\($0)]" } ?? "", n.lineAudio.map { "[sound:\($0)]" } ?? "", n.reverse ? "1" : ""]
    }

    static func tag(_ s: String) -> String {
        var out = ""
        var lastUnderscore = false
        for ch in s.trimmingCharacters(in: .whitespacesAndNewlines) {
            if ch.isLetter || ch.isNumber || ch == "-" {
                out.append(ch)
                lastUnderscore = false
            } else if !lastUnderscore {
                out.append("_")
                lastUnderscore = true
            }
        }
        return String(out.trimmingCharacters(in: CharacterSet(charactersIn: "_")).prefix(60))
    }

    static func tags(song: String, lang: String?) -> [String] {
        var out = ["SpotLyrics"]
        let parts = song.components(separatedBy: " - ")
        let artist = tag(parts.first ?? "")
        let title = tag(parts.dropFirst().joined(separator: " - "))
        if !artist.isEmpty { out.append("SpotLyrics::" + artist + (title.isEmpty ? "" : "::" + title)) }
        if let l = lang, !tag(l).isEmpty { out.append("lang_" + tag(l)) }
        return out
    }

    static func tagString(_ tags: [String]) -> String {
        let clean = tags.map { $0.replacingOccurrences(of: " ", with: "_") }.filter { !$0.isEmpty }
        return clean.isEmpty ? "" : " " + clean.joined(separator: " ") + " "
    }

    static func json(_ obj: Any) -> String {
        let d = (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])) ?? Data()
        return String(data: d, encoding: .utf8) ?? "{}"
    }

    static let css = ".card { font-family: -apple-system, Arial, sans-serif; font-size: 20px; text-align: center; color: black; background-color: white; } .word { font-size: 34px; font-weight: bold; margin-bottom: 8px; } .reading { font-size: 18px; color: #666; margin-bottom: 6px; } .meaning { margin: 10px 0; white-space: pre-wrap; } .line { font-style: italic; color: #444; margin-top: 12px; } .linereading { font-size: 15px; color: #777; } .linetr { font-size: 16px; color: #2a6; margin-top: 4px; } .song { font-size: 14px; color: #888; margin-top: 10px; }"

    static func modelObject(modelID: Int, deckID: Int, now: Int) -> [String: Any] {
        let flds: [[String: Any]] = fieldNames.enumerated().map { i, n in
            ["name": n, "ord": i, "sticky": false, "rtl": false, "font": "Arial", "size": 20, "media": [String]()]
        }
        let forward: [String: Any] = [
            "name": "Word to meaning", "ord": 0,
            "qfmt": "<div class=\"word\">{{Word}}</div>{{WordAudio}}",
            "afmt": "{{FrontSide}}<hr id=answer>{{#Reading}}<div class=\"reading\">{{Reading}}</div>{{/Reading}}<div class=\"meaning\">{{Meaning}}</div>{{#Line}}<div class=\"line\">{{Line}}</div>{{#LineReading}}<div class=\"linereading\">{{LineReading}}</div>{{/LineReading}}{{#LineTranslation}}<div class=\"linetr\">{{LineTranslation}}</div>{{/LineTranslation}}{{LineAudio}}{{/Line}}<div class=\"song\">{{Song}}</div>",
            "bqfmt": "", "bafmt": "", "did": NSNull(), "bfont": "", "bsize": 0
        ]
        let backward: [String: Any] = [
            "name": "Meaning to word", "ord": 1,
            "qfmt": "{{#Reverse}}<div class=\"meaning\">{{Meaning}}</div>{{/Reverse}}",
            "afmt": "{{FrontSide}}<hr id=answer><div class=\"word\">{{Word}}</div>{{WordAudio}}{{#Reading}}<div class=\"reading\">{{Reading}}</div>{{/Reading}}<div class=\"song\">{{Song}}</div>",
            "bqfmt": "", "bafmt": "", "did": NSNull(), "bfont": "", "bsize": 0
        ]
        return [
            "id": modelID, "name": modelName, "type": 0, "mod": now, "usn": -1, "sortf": 0, "did": deckID,
            "tmpls": [forward, backward], "flds": flds, "css": css,
            "latexPre": "\\documentclass[12pt]{article}\n\\special{papersize=3in,5in}\n\\usepackage[utf8]{inputenc}\n\\usepackage{amssymb,amsmath}\n\\pagestyle{empty}\n\\setlength{\\parindent}{0in}\n\\begin{document}\n",
            "latexPost": "\\end{document}", "latexsvg": false, "req": [[0, "all", [0]], [1, "all", [2, 9]]], "tags": [String](), "vers": [Int]()
        ]
    }

    static func deckObject(id: Int, name: String, now: Int) -> [String: Any] {
        ["id": id, "mod": now, "name": name, "usn": -1, "lrnToday": [0, 0], "revToday": [0, 0], "newToday": [0, 0],
         "timeToday": [0, 0], "collapsed": false, "browserCollapsed": false, "desc": "", "dyn": 0, "conf": 1,
         "extendNew": 0, "extendRev": 0]
    }

    static let dconf: [String: Any] = [
        "1": ["id": 1, "mod": 0, "name": "Default", "usn": 0, "maxTaken": 60, "autoplay": true, "timer": 0, "replayq": true,
              "new": ["bury": false, "delays": [1, 10], "initialFactor": 2500, "ints": [1, 4, 7], "order": 1, "perDay": 20],
              "rev": ["bury": false, "ease4": 1.3, "ivlFct": 1, "maxIvl": 36500, "perDay": 200, "hardFactor": 1.2],
              "lapse": ["delays": [10], "leechAction": 1, "leechFails": 8, "minInt": 1, "mult": 0],
              "dyn": false] as [String: Any]
    ]

    static func buildCollection(notes: [AnkiNote], deckName: String, at path: String, now: Date) throws {
        let db = try SQLiteDB(path: path)
        try db.exec("""
        CREATE TABLE col (id integer primary key, crt integer not null, mod integer not null, scm integer not null, ver integer not null, dty integer not null, usn integer not null, ls integer not null, conf text not null, models text not null, decks text not null, dconf text not null, tags text not null);
        CREATE TABLE notes (id integer primary key, guid text not null, mid integer not null, mod integer not null, usn integer not null, tags text not null, flds text not null, sfld integer not null, csum integer not null, flags integer not null, data text not null);
        CREATE TABLE cards (id integer primary key, nid integer not null, did integer not null, ord integer not null, mod integer not null, usn integer not null, type integer not null, queue integer not null, due integer not null, ivl integer not null, factor integer not null, reps integer not null, lapses integer not null, left integer not null, odue integer not null, odid integer not null, flags integer not null, data text not null);
        CREATE TABLE revlog (id integer primary key, cid integer not null, usn integer not null, ease integer not null, ivl integer not null, lastIvl integer not null, factor integer not null, time integer not null, type integer not null);
        CREATE TABLE graves (usn integer not null, oid integer not null, type integer not null);
        CREATE INDEX ix_notes_usn on notes (usn);
        CREATE INDEX ix_cards_usn on cards (usn);
        CREATE INDEX ix_revlog_usn on revlog (usn);
        CREATE INDEX ix_cards_nid on cards (nid);
        CREATE INDEX ix_cards_sched on cards (did, queue, due);
        CREATE INDEX ix_revlog_cid on revlog (cid);
        CREATE INDEX ix_notes_csum on notes (csum);
        """)
        let sec = Int(now.timeIntervalSince1970)
        let ms = sec * 1000
        let modelID = stableModelID
        let deckID = stableDeckID
        let conf: [String: Any] = ["nextPos": notes.count + 1, "estTimes": true, "activeDecks": [deckID], "sortType": "noteFld",
                                   "timeLim": 0, "sortBackwards": false, "addToCur": true, "curDeck": deckID, "newBury": true,
                                   "newSpread": 0, "dueCounts": true, "curModel": String(modelID), "collapseTime": 1200]
        let models: [String: Any] = [String(modelID): modelObject(modelID: modelID, deckID: deckID, now: sec)]
        let decks: [String: Any] = ["1": deckObject(id: 1, name: "Default", now: sec), String(deckID): deckObject(id: deckID, name: deckName, now: sec)]
        try db.run("INSERT INTO col VALUES (1, ?, ?, ?, 11, 0, 0, 0, ?, ?, ?, ?, '{}')",
                   [sec / 86400 * 86400, ms, ms, json(conf), json(models), json(decks), json(dconf)])
        for (i, n) in notes.enumerated() {
            let flds = fields(n)
            let noteID = ms + i + 1
            try db.run("INSERT INTO notes VALUES (?, ?, ?, ?, -1, ?, ?, ?, ?, 0, '')",
                       [noteID, guid(for: n), modelID, sec, tagString(n.tags), flds.joined(separator: separator), n.word, checksum(n.word)])
            try db.run("INSERT INTO cards VALUES (?, ?, ?, 0, ?, -1, 0, 0, ?, 0, 0, 0, 0, 0, 0, 0, 0, '')",
                       [noteID, noteID, deckID, sec, i + 1])
            if n.reverse {
                try db.run("INSERT INTO cards VALUES (?, ?, ?, 1, ?, -1, 0, 0, ?, 0, 0, 0, 0, 0, 0, 0, 0, '')",
                           [noteID + 500_000_000, noteID, deckID, sec, notes.count + i + 1])
            }
        }
    }

    static func write(notes: [AnkiNote], media: [AnkiMedia], deckName: String = "SpotLyrics", to out: URL, now: Date = Date()) throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("spotlyrics-apkg-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }
        try buildCollection(notes: notes, deckName: deckName, at: tmp.appendingPathComponent("collection.anki2").path, now: now)
        var mapping: [String: String] = [:]
        for (i, m) in media.enumerated() {
            mapping[String(i)] = m.name
            do { try fm.copyItem(at: m.url, to: tmp.appendingPathComponent(String(i))) } catch { throw AnkiError.io(error.localizedDescription) }
        }
        try json(mapping).write(to: tmp.appendingPathComponent("media"), atomically: true, encoding: .utf8)
        try? fm.removeItem(at: out)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.currentDirectoryURL = tmp
        p.arguments = ["-q", "-X", out.path, "collection.anki2", "media"] + media.indices.map { String($0) }
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw AnkiError.zip(p.terminationStatus) }
    }

    struct Summary: Equatable {
        var notes: Int
        var cards: Int
        var version: String
        var modelFieldCount: Int
        var noteFieldCounts: [Int]
        var deckNames: [String]
        var templateCount: Int = 0
        var cardOrds: [Int] = []
        var tags: [String] = []
        var modelIDs: [Int] = []
    }

    static func summary(ofCollection path: String) -> Summary? {
        guard let db = try? SQLiteDB(path: path, readOnly: true) else { return nil }
        let notes = Int(db.rows("SELECT count(*) FROM notes").first?.first ?? "") ?? -1
        let cards = Int(db.rows("SELECT count(*) FROM cards").first?.first ?? "") ?? -1
        let version = db.rows("SELECT ver FROM col").first?.first ?? ""
        var fieldCount = 0
        var templateCount = 0
        var modelIDs: [Int] = []
        var deckNames: [String] = []
        if let row = db.rows("SELECT models, decks FROM col").first, row.count == 2 {
            if let m = (try? JSONSerialization.jsonObject(with: Data(row[0].utf8))) as? [String: [String: Any]],
               let first = m.values.first, let f = first["flds"] as? [Any] {
                fieldCount = f.count
                templateCount = (first["tmpls"] as? [Any])?.count ?? 0
                modelIDs = m.values.compactMap { $0["id"] as? Int }
            }
            if let d = (try? JSONSerialization.jsonObject(with: Data(row[1].utf8))) as? [String: [String: Any]] {
                deckNames = d.values.compactMap { $0["name"] as? String }.sorted()
            }
        }
        let counts = db.rows("SELECT flds FROM notes ORDER BY id").map { $0[0].components(separatedBy: separator).count }
        let ords = db.rows("SELECT ord FROM cards ORDER BY id").compactMap { Int($0[0]) }
        let tags = db.rows("SELECT tags FROM notes ORDER BY id").map { $0[0] }
        return Summary(notes: notes, cards: cards, version: version, modelFieldCount: fieldCount, noteFieldCounts: counts,
                       deckNames: deckNames, templateCount: templateCount, cardOrds: ords, tags: tags, modelIDs: modelIDs)
    }
}
