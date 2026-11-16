import Cocoa

final class SpotifyPlayer: PlayerSource {
    let id = PlayerID.spotify
    static let bundleID = "com.spotify.client"

    private let stateScript = NSAppleScript(source: """
    tell application "Spotify"
        if player state is stopped then return {"", "", "", 0, 0, "stopped", "", ""}
        set t to current track
        return {name of t, artist of t, album of t, duration of t, (player position * 1000) as integer, (player state as text), artwork url of t, spotify url of t}
    end tell
    """)!

    private let commands: [PlayerCommand: NSAppleScript] = [
        .previous: NSAppleScript(source: "tell application \"Spotify\" to previous track")!,
        .playPause: NSAppleScript(source: "tell application \"Spotify\" to playpause")!,
        .next: NSAppleScript(source: "tell application \"Spotify\" to next track")!
    ]

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first != nil
    }

    func fetch() -> PlayerReading? {
        var err: NSDictionary?
        let d = stateScript.executeAndReturnError(&err)
        if err != nil { return nil }
        return PlayerReading(title: d.atIndex(1)?.stringValue ?? "", artist: d.atIndex(2)?.stringValue ?? "",
                             album: d.atIndex(3)?.stringValue ?? "",
                             durMs: Int(d.atIndex(4)?.int32Value ?? 0), posMs: Int(d.atIndex(5)?.int32Value ?? 0),
                             state: d.atIndex(6)?.stringValue ?? "stopped",
                             artURL: d.atIndex(7)?.stringValue ?? "", adURL: d.atIndex(8)?.stringValue ?? "")
    }

    func send(_ command: PlayerCommand) {
        var err: NSDictionary?
        _ = commands[command]?.executeAndReturnError(&err)
    }

    func seek(toMs ms: Int) {
        var err: NSDictionary?
        _ = NSAppleScript(source: "tell application \"Spotify\" to set player position to (\(max(0, ms)) / 1000)")?.executeAndReturnError(&err)
    }
}
