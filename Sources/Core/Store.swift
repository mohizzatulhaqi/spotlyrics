import Foundation

// MARK: - Local storage

enum Store {
    static let dir: URL = {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpotLyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    static func transFile(_ key: String) -> URL {
        let safe = String(key.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }.prefix(150))
        return dir.appendingPathComponent(safe + ".tr.json")
    }
    static var lyricsDir: URL {
        let u = dir.appendingPathComponent("Lyrics", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    static func lyricsFile(_ key: String) -> URL {
        let safe = String(key.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }.prefix(150))
        return lyricsDir.appendingPathComponent(safe + ".json")
    }
    static func readLyrics(_ key: String) -> CachedLyrics? {
        guard let d = try? Data(contentsOf: lyricsFile(key)) else { return nil }
        return try? JSONDecoder().decode(CachedLyrics.self, from: d)
    }
    static func writeLyrics(_ key: String, _ lines: [Line]) {
        if let d = try? JSONEncoder().encode(CachedLyrics(saved: Date(), lines: lines)) {
            try? d.write(to: lyricsFile(key), options: .atomic)
        }
    }
    static func readTrans(_ key: String) -> [String]? {
        guard let d = try? Data(contentsOf: transFile(key)) else { return nil }
        return try? JSONDecoder().decode([String].self, from: d)
    }
    static func writeTrans(_ key: String, _ t: [String]) {
        if let d = try? JSONEncoder().encode(t) { try? d.write(to: transFile(key), options: .atomic) }
    }
}
