import Cocoa

final class AppleMusicPlayer: PlayerSource {
    let id = PlayerID.music

    private let stateScript = NSAppleScript(source: """
    tell application "Music"
        set stateText to (player state as text)
        if stateText is "stopped" then return {"", "", "", 0, 0, "stopped", "", ""}
        try
            set theTrack to current track
        on error
            return {"", "", "", 0, 0, "stopped", "", ""}
        end try
        set trackName to ""
        set trackArtist to ""
        set trackAlbum to ""
        set trackMs to 0
        try
            set trackName to name of theTrack
        end try
        try
            set trackArtist to artist of theTrack
        end try
        try
            set trackAlbum to album of theTrack
        end try
        try
            set trackMs to ((duration of theTrack) * 1000) as integer
        end try
        return {trackName, trackArtist, trackAlbum, trackMs, ((player position) * 1000) as integer, stateText, "", ""}
    end tell
    """)!

    private let artScript = NSAppleScript(source: """
    tell application "Music"
        try
            return data of artwork 1 of current track
        on error
            return missing value
        end try
    end tell
    """)!

    private let commands: [PlayerCommand: NSAppleScript] = [
        .previous: NSAppleScript(source: "tell application \"Music\" to previous track")!,
        .playPause: NSAppleScript(source: "tell application \"Music\" to playpause")!,
        .next: NSAppleScript(source: "tell application \"Music\" to next track")!
    ]

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: PlayerID.music.bundleID).first != nil
    }

    func fetch() -> PlayerReading? {
        var err: NSDictionary?
        let d = stateScript.executeAndReturnError(&err)
        if err != nil { return nil }
        return PlayerReading(title: d.atIndex(1)?.stringValue ?? "", artist: d.atIndex(2)?.stringValue ?? "",
                             album: d.atIndex(3)?.stringValue ?? "",
                             durMs: Int(d.atIndex(4)?.int32Value ?? 0), posMs: Int(d.atIndex(5)?.int32Value ?? 0),
                             state: d.atIndex(6)?.stringValue ?? "stopped", artURL: "", adURL: "")
    }

    func send(_ command: PlayerCommand) {
        var err: NSDictionary?
        _ = commands[command]?.executeAndReturnError(&err)
    }

    func seek(toMs ms: Int) {
        var err: NSDictionary?
        _ = NSAppleScript(source: "tell application \"Music\" to set player position to (\(max(0, ms)) / 1000)")?.executeAndReturnError(&err)
    }

    func artworkData() -> Data? {
        var err: NSDictionary?
        let d = artScript.executeAndReturnError(&err)
        if err != nil { return nil }
        let data = d.data
        return data.count > 100 ? ImageData.trimmed(data) : nil
    }
}
