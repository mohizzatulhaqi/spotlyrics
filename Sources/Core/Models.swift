import Foundation

struct Line: Codable { let time: Double; let text: String }

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
}

extension Snap {
    init(reading r: PlayerReading, at: Date) {
        self.init(title: r.title, artist: r.artist, album: r.album, durMs: r.durMs, posMs: r.posMs,
                  state: r.state, artURL: r.artURL, adURL: r.adURL, at: at)
    }

    var isAd: Bool { PlayerReading.isAd(title: title, artist: artist, adURL: adURL) }
}

struct CachedLyrics: Codable { let saved: Date; let lines: [Line] }
