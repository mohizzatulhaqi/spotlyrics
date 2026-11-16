import Foundation

final class RoutingPlayer: PlayerSource {
    let spotify = SpotifyPlayer()
    let music = AppleMusicPlayer()
    private(set) var activeID: PlayerID = .spotify
    private var lastProbe = Date.distantPast

    var id: PlayerID { activeID }
    var active: PlayerSource { source(activeID) }
    var isRunning: Bool { active.isRunning }
    var anyRunning: Bool { spotify.isRunning || music.isRunning }

    func source(_ id: PlayerID) -> PlayerSource { id == .spotify ? spotify : music }
    func fetch() -> PlayerReading? { active.fetch() }
    func send(_ command: PlayerCommand) { active.send(command) }
    func seek(toMs ms: Int) { active.seek(toMs: ms) }
    func artworkData() -> Data? { active.artworkData() }

    @discardableResult
    func reevaluate(now: Date, activePlaying: Bool) -> Bool {
        let running: [PlayerID: Bool] = [.spotify: spotify.isRunning, .music: music.isRunning]
        var playing: [PlayerID: Bool] = [activeID: activePlaying]
        let setting = Prefs.playerChoice
        if setting == "auto", running[.spotify] == true, running[.music] == true, !activePlaying,
           now.timeIntervalSince(lastProbe) >= 3 {
            lastProbe = now
            let other: PlayerID = activeID == .spotify ? .music : .spotify
            playing[other] = source(other).fetch()?.state == "playing"
        }
        let next = PlayerChoice.pick(setting: setting, current: activeID, running: running, playing: playing)
        if next != activeID {
            activeID = next
            return true
        }
        return false
    }
}
