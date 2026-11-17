import Foundation

struct Line: Codable, Equatable { let time: Double; let text: String }

struct Snap {
    let title: String, artist: String, album: String
    let durMs: Int, posMs: Int
    let state: String, artURL: String, adURL: String
    let at: Date
}

struct PlayerReading: Equatable {
    var title = "", artist = "", album = ""
    var durMs = 0, posMs = 0
    var state = "stopped"
    var artURL = "", adURL = ""

    static func isAd(title: String, artist: String, adURL: String) -> Bool {
        adURL.hasPrefix("spotify:ad") || (artist.isEmpty && ["advertisement", "spotify"].contains(title.lowercased()))
    }

    var isAd: Bool { PlayerReading.isAd(title: title, artist: artist, adURL: adURL) }
    var isEpisode: Bool { adURL.hasPrefix("spotify:episode") }
}

extension Snap {
    init(reading r: PlayerReading, at: Date) {
        self.init(title: r.title, artist: r.artist, album: r.album, durMs: r.durMs, posMs: r.posMs,
                  state: r.state, artURL: r.artURL, adURL: r.adURL, at: at)
    }

    var isAd: Bool { PlayerReading.isAd(title: title, artist: artist, adURL: adURL) }
    var isEpisode: Bool { adURL.hasPrefix("spotify:episode") }
}

struct LyricsResult: Equatable {
    var lines: [Line]
    var synced: Bool
    static let empty = LyricsResult(lines: [], synced: true)
}

struct SongMeta: Equatable {
    let artist: String
    let title: String
    let album: String
    let duration: Int
}

struct LibraryEntry: Identifiable, Equatable {
    let file: URL
    let artist: String
    let title: String
    let album: String
    let duration: Int
    let saved: Date
    let lines: [Line]
    let synced: Bool
    let pinned: Bool
    var id: String { file.lastPathComponent }
    var name: String { "\(artist) - \(title)" }
    var transKey: String { "\(artist)|\(title)" }

    func matches(_ query: String) -> Bool {
        let q = Vocab.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        if q.isEmpty { return true }
        if Vocab.fold(name).contains(q) || Vocab.fold(album).contains(q) { return true }
        return lines.contains { Vocab.fold($0.text).contains(q) }
    }
}

struct CachedLyrics: Codable {
    let saved: Date
    let lines: [Line]
    let synced: Bool?
    let pinned: Bool?
    var artist: String? = nil
    var title: String? = nil
    var album: String? = nil
    var duration: Int? = nil
    var isSynced: Bool { synced ?? true }
    var isPinned: Bool { pinned ?? false }
}
