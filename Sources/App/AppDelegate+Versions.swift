import Cocoa
import SwiftUI

extension AppDelegate {
    func openVersionPicker() {
        guard !trackKey.isEmpty, !lastIsAd, !lastIsEpisode else { return }
        MainActor.assumeIsolated {
            if versionWindow == nil {
                let m = VersionModel()
                m.onUse = { [weak self] o in self?.useLyricsVersion(o) }
                m.onAuto = { [weak self] in self?.resetLyricsVersion() }
                versionModel = m
                let hc = NSHostingController(rootView: VersionView(m: m))
                hc.sizingOptions = []
                let w = NSWindow(contentViewController: hc)
                w.styleMask = [.titled, .closable, .resizable]
                w.isReleasedWhenClosed = false
                w.level = .floating
                w.setContentSize(NSSize(width: 620, height: 540))
                w.center()
                versionWindow = w
            }
            versionWindow?.title = L(.pickTitle)
            versionModel?.load(title: curTitle, artist: curArtist, duration: curDurSec, current: lines)
            NSApp.activate(ignoringOtherApps: true)
            versionWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func useLyricsVersion(_ o: LyricsOption) {
        let key = Lyrics.cacheKey(artist: curArtist, title: curTitle, duration: curDurSec)
        Lyrics.pin(key, o)
        lines = o.lines
        lyricsSynced = o.synced
        loaded = true
        clearStudyState()
        resetTranslation()
        floatSig = ""
        learnKey = ""
        versionWindow?.close()
    }

    func resetLyricsVersion() {
        versionWindow?.close()
        reloadLyrics()
    }
}
