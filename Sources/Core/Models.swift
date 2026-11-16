import Foundation

struct Line: Codable { let time: Double; let text: String }

struct Snap {
    let title: String, artist: String, album: String
    let durMs: Int, posMs: Int
    let state: String, artURL: String, adURL: String
    let at: Date
}

struct CachedLyrics: Codable { let saved: Date; let lines: [Line] }
