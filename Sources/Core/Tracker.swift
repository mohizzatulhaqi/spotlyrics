import Foundation

enum PlayerCommand {
    case previous, playPause, next
}

enum PlayerID: String, CaseIterable {
    case spotify, music

    var displayName: String { self == .spotify ? "Spotify" : "Apple Music" }
    var bundleID: String { self == .spotify ? "com.spotify.client" : "com.apple.Music" }
}

protocol PlayerSource: AnyObject {
    var id: PlayerID { get }
    var isRunning: Bool { get }
    func fetch() -> PlayerReading?
    func send(_ command: PlayerCommand)
    func seek(toMs ms: Int)
    func artworkData() -> Data?
}

extension PlayerSource {
    func artworkData() -> Data? { nil }
}

enum PlayerChoice {
    static func pick(setting: String, current: PlayerID, running: [PlayerID: Bool], playing: [PlayerID: Bool]) -> PlayerID {
        if let forced = PlayerID(rawValue: setting) { return forced }
        let up = PlayerID.allCases.filter { running[$0] == true }
        if up.isEmpty { return current }
        if up.count == 1 { return up[0] }
        if playing[current] == true { return current }
        if let other = up.first(where: { $0 != current && playing[$0] == true }) { return other }
        return up.contains(current) ? current : up[0]
    }
}

enum ImageData {
    static let signatures: [[UInt8]] = [
        [0x89, 0x50, 0x4E, 0x47], [0xFF, 0xD8, 0xFF], [0x49, 0x49, 0x2A, 0x00], [0x4D, 0x4D, 0x00, 0x2A], [0x47, 0x49, 0x46, 0x38]
    ]

    static func trimmed(_ d: Data) -> Data {
        let bytes = [UInt8](d.prefix(600))
        for i in 0..<bytes.count {
            for sig in signatures where i + sig.count <= bytes.count && Array(bytes[i..<(i + sig.count)]) == sig {
                return Data(d.dropFirst(i))
            }
        }
        return d
    }
}

final class PlaybackTracker {
    static let playingMaxAge = 10.0
    static let pausedMaxAge = 30.0
    static let retryDelay = 3.0

    private let source: PlayerSource
    private(set) var snap: Snap?
    private(set) var lastFetch = Date.distantPast
    private(set) var fetchCount = 0
    private(set) var failed = false
    private var needFetch = true
    private var retryAt = Date.distantPast

    init(source: PlayerSource) { self.source = source }

    func notify() {
        needFetch = true
        retryAt = .distantPast
    }

    func markStale() { needFetch = true }

    func reset() {
        snap = nil
        needFetch = true
        failed = false
    }

    @discardableResult
    func refresh(now: Date) -> Snap? {
        let maxAge = snap?.state == "playing" ? Self.playingMaxAge : Self.pausedMaxAge
        let stale = snap == nil || needFetch || now.timeIntervalSince(lastFetch) > maxAge
        if stale && now >= retryAt {
            needFetch = false
            lastFetch = now
            fetchCount += 1
            if let r = source.fetch() {
                snap = Snap(reading: r, at: now)
                failed = false
            } else {
                snap = nil
                failed = true
                retryAt = now.addingTimeInterval(Self.retryDelay)
            }
        }
        return snap
    }

    func positionMs(now: Date) -> Int? {
        guard let s = snap else { return nil }
        return Playback.position(posMs: s.posMs, durMs: s.durMs, playing: s.state == "playing", at: s.at, now: now)
    }

    func didSeek(toMs ms: Int, now: Date) {
        if let s = snap {
            snap = Snap(title: s.title, artist: s.artist, album: s.album, durMs: s.durMs, posMs: ms,
                        state: s.state, artURL: s.artURL, adURL: s.adURL, at: now)
        }
        needFetch = true
    }

    func lastFetchAge(now: Date) -> Double? {
        lastFetch == .distantPast ? nil : now.timeIntervalSince(lastFetch)
    }
}

enum TickRate {
    static func interval(running: Bool, playing: Bool, isAd: Bool, menuOpen: Bool) -> Double {
        if !running { return 2.0 }
        if menuOpen { return 0.3 }
        if isAd { return 0.5 }
        return playing ? 0.3 : 1.0
    }
}
