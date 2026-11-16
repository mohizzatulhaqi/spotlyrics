import Cocoa
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import Translation
import NaturalLanguage

extension AppDelegate {
    func loadLyrics(title: String, artist: String, album: String, duration: Int, key: String, refresh: Bool) {
        Task {
            let l = await Lyrics.load(title: title, artist: artist, album: album, duration: duration, refresh: refresh)
            DispatchQueue.main.async {
                if self.trackKey == key { self.lines = l; self.loaded = true }
            }
        }
    }

    @objc func reloadLyrics() {
        guard !trackKey.isEmpty else { return }
        let key = trackKey
        lines = []
        loaded = false
        clearStudyState()
        resetTranslation()
        floatSig = ""
        learnKey = ""
        loadLyrics(title: curTitle, artist: curArtist, album: curAlbum, duration: curDurSec, key: key, refresh: true)
    }

    @objc func spotifyChanged(_ n: Notification) {
        notificationCount += 1
        tracker.notify()
        runTick()
    }

    func runTick() {
        tick()
        scheduleTick()
    }

    func scheduleTick() {
        tickTimer?.invalidate()
        let iv = TickRate.interval(running: tickRunning, playing: lastPlaying, isAd: lastIsAd, menuOpen: menuOpen)
        let t = Timer(timeInterval: iv, repeats: false) { [weak self] _ in self?.runTick() }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    func control(_ k: String) {
        let cmd: PlayerCommand = k == "prev" ? .previous : k == "next" ? .next : .playPause
        player.send(cmd)
        if k == "toggle" {
            lastPlaying.toggle()
            MainActor.assumeIsolated { menuModel?.playing = lastPlaying }
        }
        tracker.markStale()
        runTick()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuOpen = true
        runTick()
    }

    func menuDidClose(_ menu: NSMenu) {
        menuOpen = false
        MainActor.assumeIsolated { menuModel?.scrub = nil }
    }

    func pushLyric() {
        MainActor.assumeIsolated {
            guard let mm = menuModel else { return }
            if lines.isEmpty {
                mm.lyric = loaded ? L(.lyricsUnavailable) : L(.lyricsLoading)
                mm.lyricTrans = ""
                return
            }
            guard let i = lastIdx else { mm.lyric = "♪"; mm.lyricTrans = ""; return }
            let t = lines[i].text
            mm.lyric = t.isEmpty ? "♪" : t
            mm.lyricTrans = transKey == trackKey && i < trans.count ? trans[i] : ""
        }
    }

    func seek(_ sec: Double, refresh: Bool = true) {
        let ms = max(0, Int(sec * 1000))
        player.seek(toMs: ms)
        tracker.didSeek(toMs: ms, now: Date())
        lastPosMs = ms
        floatSig = ""
        if refresh { runTick() }
    }

    func pushPlayback() {
        MainActor.assumeIsolated {
            guard let mm = menuModel else { return }
            mm.position = Double(lastPosMs) / 1000
            mm.duration = Double(lastDurMs) / 1000
            mm.playing = lastPlaying
            mm.hasTrack = !trackKey.isEmpty
            mm.isAd = lastIsAd
        }
    }

    func syncOffsetText() {
        MainActor.assumeIsolated { menuModel?.offsetText = String(format: "%+.2fs", offset) }
    }

    @objc func toggleLyrics() {
        hidden.toggle()
        if hidden { setTitle("♪") }
    }

    func adjust(_ delta: Double) {
        offset = ((offset + delta) * 100).rounded() / 100
        if !devUID.isEmpty { Offsets.set(devUID, offset) }
    }

    @objc func faster() { adjust(0.1) }

    @objc func slower() { adjust(-0.1) }

    @objc func resetOffset() {
        offset = 0
        if !devUID.isEmpty { Offsets.set(devUID, 0) }
    }

    // Initial offset for Bluetooth devices: a guess of -0.2s (typical latency), adjustable manually.
    func refreshDevice() {
        guard let d = AudioOut.current() else { return }
        if d.uid != devUID {
            devUID = d.uid
            devName = d.name
            offset = Offsets.get(d.uid) ?? (d.bt ? -0.2 : 0)
        }
    }

    // MARK: main loop

    func setTitle(_ s: String) {
        if s != marqueeText {
            marqueeText = s
            marqueeStart = Date()
            updateStatusWidth()
        }
        renderTitle()
    }

    func updateStatusWidth() {
        guard let b = item.button else { return }
        if marqueeText.count > maxChars {
            let font = b.font ?? NSFont.menuBarFont(ofSize: 0)
            let sample = String(marqueeText.prefix(maxChars))
            let w = NSAttributedString(string: sample, attributes: [.font: font]).size().width
            item.length = ceil(w * 1.1) + 16 + (b.image != nil ? 24 : 0)
            marqueeFixed = true
        } else if marqueeFixed {
            item.length = NSStatusItem.variableLength
            marqueeFixed = false
        }
    }

    func renderTitle() {
        let t = Marquee.window(marqueeText, width: maxChars, elapsed: Date().timeIntervalSince(marqueeStart))
        if item.button?.title != t { item.button?.title = t }
    }

    func showLearnEmpty(_ msg: String) {
        if learnKey != "empty#" + msg {
            learnKey = "empty#" + msg
            learn.setEmpty(msg)
        }
    }

    func tick() {
        tickCount += 1
        if tickCount % 10 == 0 { refreshDevice() }

        tickRunning = player.isRunning
        guard tickRunning else {
            tracker.reset()
            clearCoverIfShown()
            infoItem.title = L(.spotifyInactive)
            setTitle("♪")
            floatMessage(L(.spotifyInactive), L(.openSpotifyHint))
            if learn.window.isVisible { showLearnEmpty(L(.spotifyInactiveLearn)) }
            return
        }

        let now = Date()
        tracker.refresh(now: now)
        if !tracker.failed { loggedAutomationFailure = false }
        guard let sp = tracker.snap else {
            if !loggedAutomationFailure {
                loggedAutomationFailure = true
                Diagnostics.log("spotify: could not read player state (Automation denied or Spotify busy)")
            }
            clearCoverIfShown()
            infoItem.title = L(.automationInfo)
            setTitle("♪")
            warnAutomation()
            floatMessage(L(.automationNeeded), L(.automationPath))
            if learn.window.isVisible { showLearnEmpty(L(.automationLearn)) }
            return
        }
        let title = sp.title, artist = sp.artist, album = sp.album
        let durMs = sp.durMs
        let state = sp.state
        let artURL = sp.artURL
        let posMs = tracker.positionMs(now: now) ?? sp.posMs
        lastPosMs = posMs; lastDurMs = durMs; lastPlaying = state == "playing"
        if menuOpen { pushPlayback() }

        let isAd = sp.isAd
        if isAd != lastIsAd {
            lastIsAd = isAd
            setArtwork(nil)
        }
        if isAd {
            trackKey = ""
            lines = []
            loaded = false
            clearStudyState()
            resetTranslation()
            infoItem.title = L(.adTitle)
            let remain = max(0, (durMs - posMs) / 1000)
            if menuOpen { pushPlayback() }
            if learn.window.isVisible { showLearnEmpty(L(.adLearn)) }
            floatMessage(L(.adTitle), L(.adSubtitle))
            if !hidden { setTitle(L(.adMenuBar, remain / 60, remain % 60)) } else { setTitle("♪") }
            return
        }

        if title.isEmpty {
            clearCoverIfShown()
            infoItem.title = L(.noSong); trackKey = ""; setTitle("♪")
            floatMessage(L(.nothingPlaying))
            if learn.window.isVisible { showLearnEmpty(L(.nothingPlayingLearn)) }
            return
        }
        infoItem.title = "\(artist) - \(title)"
        curTitle = title; curArtist = artist; curAlbum = album; curDurSec = durMs / 1000

        let key = "\(artist)|\(title)"
        if key != trackKey {
            trackKey = key
            lines = []
            loaded = false
            clearStudyState()
            resetTranslation()
            setArtwork(nil)
            if let u = URL(string: artURL), !artURL.isEmpty {
                Task {
                    guard let (data, _) = try? await URLSession.shared.data(from: u), let img = NSImage(data: data) else { return }
                    DispatchQueue.main.async {
                        if self.trackKey == key { self.setArtwork(img) }
                    }
                }
            }
            loadLyrics(title: title, artist: artist, album: album, duration: durMs / 1000, key: key, refresh: false)
        }

        let pos = Playback.effective(posMs: posMs, offset: offset)
        if let r = loop, state == "playing", r.shouldWrap(effectivePos: pos), Date().timeIntervalSince(lastLoopJump) > 1.0 {
            lastLoopJump = Date()
            seek(Playback.rawPosition(forLineTime: r.startTime, offset: offset), refresh: false)
        }
        var idx: Int?
        for (n, l) in lines.enumerated() { if l.time <= pos { idx = n } else { break } }

        lastIdx = idx
        if menuOpen { pushLyric() }
        updateFloat(idx: idx)

        if loaded, !lines.isEmpty, transKey != trackKey, !transBusy { ensureTranslation() }

        if learn.window.isVisible, !loaded {
            showLearnEmpty(L(.lyricsLoading))
        } else if learn.window.isVisible {
            let showRm = Prefs.showRomaji
            let tr: [String] = lines.indices.map { i in
                let rm = showRm && i < romaji.count ? romaji[i] : ""
                let t = transKey == trackKey && i < trans.count ? trans[i] : ""
                return [rm, t].filter { !$0.isEmpty }.joined(separator: "\u{2028}")
            }
            let lk = trackKey + "#\(lines.count)#\(trans.count)#\(romaji.count)#\(showRm)#\(transKey == trackKey)"
            if lk != learnKey {
                learnKey = lk
                learn.setLyrics(lines.map { $0.text }, title: "\(artist) - \(title)", translations: tr, times: lines.map { $0.time })
            }
            learn.setCurrent(idx ?? -1)
        }

        if Date() < flashUntil { setTitle(flashText); return }
        if hidden { return }
        let prefix = state == "playing" ? "" : "⏸ "
        if lines.isEmpty {
            setTitle(prefix + (loaded ? "♪ \(title)" : "♪ …"))
            return
        }
        var text = idx.map { lines[$0].text.isEmpty ? "♪" : lines[$0].text } ?? "♪"
        if displayMode != "orig", transKey == trackKey, let n = idx, n < trans.count, !trans[n].isEmpty {
            text = displayMode == "both" ? text + " · " + trans[n] : trans[n]
        }
        setTitle(prefix + text)
    }
}
