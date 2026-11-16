import Foundation

enum PlayerCommand {
    case previous, playPause, next
}

protocol PlayerSource: AnyObject {
    var isRunning: Bool { get }
    func fetch() -> PlayerReading?
    func send(_ command: PlayerCommand)
    func seek(toMs ms: Int)
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
