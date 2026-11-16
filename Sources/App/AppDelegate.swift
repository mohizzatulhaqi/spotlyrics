import Cocoa
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import Translation
import NaturalLanguage

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, @unchecked Sendable {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let infoItem = NSMenuItem(title: L(.spotifyInactive), action: nil, keyEquivalent: "")
    let learnItem = NSMenuItem(title: L(.learnMode), action: #selector(openLearn), keyEquivalent: "")

    let hotKeys = [
        HotKeySpec(id: 1, code: UInt32(kVK_ANSI_L), symbol: "L", titleKey: .hkFloat),
        HotKeySpec(id: 2, code: UInt32(kVK_ANSI_T), symbol: "T", titleKey: .hkMode),
        HotKeySpec(id: 3, code: UInt32(kVK_ANSI_H), symbol: "H", titleKey: .hkHide),
        HotKeySpec(id: 4, code: UInt32(kVK_ANSI_LeftBracket), symbol: "[", titleKey: .hkSlower),
        HotKeySpec(id: 5, code: UInt32(kVK_ANSI_RightBracket), symbol: "]", titleKey: .hkFaster)
    ]
    var hotRefs: [EventHotKeyRef] = []
    var hotFailed: Set<UInt32> = []
    var hotHandlerInstalled = false
    var hotKeysOn = UserDefaults.standard.object(forKey: "hotKeysOn") as? Bool ?? true
    var flashText = ""
    var flashUntil = Date.distantPast
    let reloadItem = NSMenuItem(title: L(.reloadLyrics), action: #selector(reloadLyrics), keyEquivalent: "")
    let songItem = NSMenuItem(title: L(.thisSong), action: nil, keyEquivalent: "")
    let songMenu = NSMenu()
    let settingsItem = NSMenuItem(title: L(.settingsMenu), action: #selector(openSettingsAction), keyEquivalent: ",")
    let quitItem = NSMenuItem(title: L(.quit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    var settingsWindow: NSWindow?
    var settingsModel: SettingsModel?
    var floatOn = UserDefaults.standard.bool(forKey: "floatOn")
    var floatPanel: NSPanel?
    var floatModel: FloatModel?
    var floatSig = ""
    let headerItem = NSMenuItem()
    let offsetItem = NSMenuItem()
    var menuModel: MenuModel?
    let songLangItem = NSMenuItem(title: L(.songLanguage), action: nil, keyEquivalent: "")
    let songLangs = ["en", "ko", "ja", "ko-rom", "ja-rom", "zh", "es", "fr", "de", "pt", "ru", "th", "vi", "id"]
    var shownAutomationAlert = false

    let learn = LearnPanel()
    var learnKey = ""
    var trans: [String] = []        // translation per line, aligned with `lines` ("" = not needed)
    var romaji: [String] = []
    var lineLangs: [String] = []    // detected language per line, aligned with `lines`
    var transGen = 0
    var notificationCount = 0
    var loggedAutomationFailure = false
    var romSuggestion: String?
    var suggestedKeys = Set<String>()
    var langModel: LangModel?
    let translator = Translator()
    var transKey = ""               // song that owns `trans` (also marks that a translation was already attempted)
    var transBusy = false
    var transError: String?
    var displayMode: String = UserDefaults.standard.string(forKey: "displayMode")
        ?? (UserDefaults.standard.bool(forKey: "showTrans") ? "trans" : "orig")
    var hidden = false
    var lines: [Line] = []
    var trackKey = ""
    var loaded = false
    var curTitle = "", curArtist = "", curAlbum = ""
    var curDurSec = 0
    var devUID = "", devName = ""
    var offset = 0.0
    var tickCount = 0
    let maxChars = 40
    var snap: Snap?
    var needFetch = true
    var lastFetch = Date.distantPast
    var retryAt = Date.distantPast
    var marqueeText = ""
    var marqueeStart = Date()
    var marqueeFixed = false

    let script = NSAppleScript(source: """
    tell application "Spotify"
        if player state is stopped then return {"", "", "", 0, 0, "stopped", "", ""}
        set t to current track
        return {name of t, artist of t, album of t, duration of t, (player position * 1000) as integer, (player state as text), artwork url of t, spotify url of t}
    end tell
    """)!
    let ctlScripts: [String: NSAppleScript] = [
        "prev": NSAppleScript(source: "tell application \"Spotify\" to previous track")!,
        "toggle": NSAppleScript(source: "tell application \"Spotify\" to playpause")!,
        "next": NSAppleScript(source: "tell application \"Spotify\" to next track")!
    ]
    var menuOpen = false
    var lastPosMs = 0, lastDurMs = 0
    var lastPlaying = false
    var lastIdx: Int?
    var lastIsAd = false


    func applicationDidFinishLaunching(_ n: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        MainActor.assumeIsolated {
            let mm = MenuModel()
            mm.mode = displayMode
            mm.onMode = { [weak self] v in self?.applyDisplayMode(v) }
            mm.onFaster = { [weak self] in self?.faster(); self?.syncOffsetText() }
            mm.onSlower = { [weak self] in self?.slower(); self?.syncOffsetText() }
            mm.onReset = { [weak self] in self?.resetOffset(); self?.syncOffsetText() }
            mm.onLang = { [weak self] in self?.item.menu?.cancelTracking(); self?.openSettings(tab: "terjemahan") }
            mm.onFloat = { [weak self] in self?.setFloat(!(self?.floatOn ?? false)); self?.syncMenuFlags() }
            mm.onRomaji = { [weak self] in self?.toggleRomaji(); self?.syncMenuFlags() }
            mm.onHide = { [weak self] in self?.toggleLyrics(); self?.syncMenuFlags() }
            mm.onSuggestApply = { [weak self] in self?.applyRomanizedSuggestion() }
            mm.onSuggestDismiss = { [weak self] in self?.dismissRomanizedSuggestion() }
            mm.onSettings = { [weak self] in self?.item.menu?.cancelTracking(); self?.openSettings(tab: nil) }
            mm.onHeight = { [weak self] h in
                if h > 0 { self?.headerItem.view?.frame.size.height = h }
            }
            mm.onPrev = { [weak self] in self?.control("prev") }
            mm.onToggle = { [weak self] in self?.control("toggle") }
            mm.onNext = { [weak self] in self?.control("next") }
            mm.onSeek = { [weak self] t in self?.seek(t) }
            mm.onRetry = { [weak self] in self?.item.menu?.cancelTracking(); self?.retryTrans() }
            menuModel = mm
            let hv = NSHostingView(rootView: HeaderCard(m: mm))
            hv.frame = NSRect(x: 0, y: 0, width: 300, height: 330)
            headerItem.view = hv
            let ov = NSHostingView(rootView: OffsetRow(m: mm))
            ov.frame = NSRect(x: 0, y: 0, width: 300, height: 34)
            offsetItem.view = ov
        }
        learnItem.image = NSImage(systemSymbolName: "book", accessibilityDescription: nil)
        songItem.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)
        songItem.submenu = songMenu
        reloadItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        songLangItem.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: nil)
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        if hotKeysOn { registerHotKeys() }
        infoItem.isHidden = true
        let all: [NSMenuItem] = [infoItem, headerItem, .separator(), offsetItem, .separator(),
                                 learnItem, songItem, .separator(), settingsItem]
        for m in all {
            if m.action != nil { m.target = self }
            menu.addItem(m)
        }
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)
        item.menu = menu
        item.button?.title = "♪"
        installEditMenu()
        learn.song = { [weak self] in
            guard let s = self else { return "" }
            return "\(s.curArtist) - \(s.curTitle)"
        }
        learn.translator = translator
        learn.prep = { [weak self] t in
            guard let s = self, let o = Prefs.songOverride(s.trackKey), Romaji.base(o) != nil else { return t }
            return Romaji.convert(t, o)
        }
        learn.onSeek = { [weak self] t in
            guard let s = self else { return }
            s.seek(Playback.rawPosition(forLineTime: t, offset: s.offset))
        }
        learn.langFor = { [weak self] line in self?.langForLine(line) ?? "en" }
        if floatOn { setFloat(true) }
        askTargetIfNeeded()
        refreshDevice()
        let t = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(spotifyChanged),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil,
            suspensionBehavior: .deliverImmediately)
        let m = Timer(timeInterval: Marquee.step, repeats: true) { [weak self] _ in
            guard let s = self, s.marqueeText.count > s.maxChars else { return }
            s.renderTitle()
        }
        RunLoop.main.add(m, forMode: .common)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshDevice()
        learnItem.title = L(.learnMode)
        songItem.title = L(.thisSong)
        settingsItem.title = L(.settingsMenu)
        reloadItem.title = L(.reloadLyrics)
        quitItem.title = L(.quit)
        rebuildSongMenu()
        let failing = transKey == trackKey && transError != nil
        let st = transStatusText()
        MainActor.assumeIsolated {
            guard let mm = menuModel else { return }
            if lastIsAd {
                mm.title = L(.adTitle)
                mm.subtitle = L(.adSubtitle)
            } else if trackKey.isEmpty {
                mm.title = infoItem.title
                mm.subtitle = ""
            } else {
                mm.title = curTitle
                mm.subtitle = curArtist
            }
            mm.status = lastIsAd ? L(.adWaiting) : st.text
            mm.failing = failing && !lastIsAd
            mm.kind = lastIsAd ? 2 : st.kind
            mm.device = devName.isEmpty ? "-" : devName
            mm.offsetText = String(format: "%+.2fs", offset)
            if mm.mode != displayMode { mm.mode = displayMode }
        }
        syncMenuFlags()
        pushPlayback()
        pushLyric()
    }
}
