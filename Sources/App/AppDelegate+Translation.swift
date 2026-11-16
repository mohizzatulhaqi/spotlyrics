import Cocoa
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import Translation
import NaturalLanguage

extension AppDelegate {
    @objc func openLearn() {
        learnKey = ""   // force the window to reload the lyrics
        learn.show()
    }

    // Drop translations from memory. The disk cache stays and is reused.
    func resetTranslation() {
        transGen += 1
        romSuggestion = nil
        trans = []
        lineLangs = []
        romaji = []
        transKey = ""
        transError = nil
    }

    @objc func retryTrans() {
        Task { await translator.reset() }   // fresh session, in case a new language finished downloading
        resetTranslation()
    }

    func langChanged() {
        Task { await translator.reset() }
        resetTranslation()
    }

    @objc func openLang() { openSettings(tab: "terjemahan") }

    @objc func openSettingsAction() { openSettings(tab: nil) }

    func openSettings(tab: String?) {
        MainActor.assumeIsolated {
            if settingsWindow == nil {
                let lm = LangModel()
                lm.onChange = { [weak self] in self?.langChanged() }
                langModel = lm
                let sm = SettingsModel()
                sm.onCasual = { [weak self] in self?.casualChanged() }
                sm.onRomaji = { [weak self] in self?.romajiChanged() }
                sm.onAccent = { [weak self] in self?.accentChanged() }
                sm.onMenuCover = { [weak self] in
                    guard let s = self else { return }
                    s.updateMenuBarCover(MainActor.assumeIsolated { s.menuModel?.artwork })
                }
                sm.onFloat = { [weak self] on in self?.setFloat(on); self?.syncMenuFlags() }
                sm.onLogin = { [weak self] on in self?.setLogin(on) }
                sm.onHotKeys = { [weak self] on in self?.setHotKeys(on) }
                sm.onTab = { [weak self] t in self?.resizeSettings(t) }
                sm.onPlayer = { [weak self] in self?.playerChoiceChanged() }
                sm.onCopyDiagnostics = { [weak self] in self?.copyDiagnostics() }
                sm.onRevealData = { [weak self] in self?.revealDataFolder() }
                sm.onRecord = { [weak self] id in self?.startRecordingShortcut(id) }
                sm.onResetShortcut = { [weak self] id in self?.resetShortcut(id) }
                sm.onResetAllShortcuts = { [weak self] in self?.resetAllShortcuts() }
                sm.onOpenSetup = { [weak self] in self?.openSetup() }
                sm.onLanguage = { [weak self] in self?.languageChanged() }
                settingsModel = sm
                let hc = NSHostingController(rootView: SettingsView(s: sm, lang: lm))
                hc.sizingOptions = []
                let w = NSWindow(contentViewController: hc)
                w.title = L(.settingsTitle)
                w.styleMask = [.titled, .closable, .miniaturizable]
                w.isReleasedWhenClosed = false
                w.setContentSize(NSSize(width: 560, height: SettingsModel.height(for: sm.tab)))
                settingsWindow = w
                w.center()
                NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
                    self?.stopRecordingShortcut()
                }
            }
            refreshSettings()
            if let t = tab { settingsModel?.tab = t }
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func languageChanged() {
        L10n.refresh()
        learnItem.title = L(.learnMode)
        songItem.title = L(.thisSong)
        settingsItem.title = L(.settingsMenu)
        reloadItem.title = L(.reloadLyrics)
        quitItem.title = L(.quit)
        settingsWindow?.title = L(.settingsTitle)
        quizWindow?.title = L(.quizTitle)
        setupWindow?.title = L(.setupTitle)
        learn.relocalize()
        floatSig = ""
        learnKey = ""
        MainActor.assumeIsolated {
            menuModel?.langTick += 1
            quizModel?.langTick += 1
            setupModel?.langTick += 1
            langModel?.langTick += 1
        }
    }

    func resizeSettings(_ tab: String) {
        stopRecordingShortcut()
        guard let w = settingsWindow else { return }
        let h = SettingsModel.height(for: tab)
        var f = w.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 560, height: h))
        f.origin = NSPoint(x: w.frame.minX, y: w.frame.maxY - f.height)
        w.setFrame(f, display: true, animate: w.isVisible)
    }

    func refreshSettings() {
        guard settingsWindow != nil else { return }
        let ls = loginState()
        MainActor.assumeIsolated {
            settingsModel?.sync(floatOn: floatOn, login: ls.on, loginAvailable: ls.available, loginNote: ls.note,
                                hotKeysOn: hotKeysOn, shortcuts: shortcutRows())
        }
    }

    func syncMenuFlags() {
        MainActor.assumeIsolated {
            guard let mm = menuModel else { return }
            mm.floatOn = floatOn
            mm.romajiOn = Prefs.showRomaji
            mm.romajiRelevant = romaji.contains { !$0.isEmpty }
            mm.lyricsHidden = hidden
            mm.suggestion = romSuggestion.map { $0 == "ja-rom" ? L(.suggestJa) : L(.suggestKo) }
        }
        if settingsWindow?.isVisible == true { refreshSettings() }
    }

    var hasForeign: Bool {
        let t = Prefs.target
        return lineLangs.contains { !$0.isEmpty && !Lang.same($0, t) }
    }

    func langSummary() -> String {
        let t = Prefs.target
        var seen: [String] = []
        for l in lineLangs where !l.isEmpty && !Lang.same(l, t) && !seen.contains(l) { seen.append(l) }
        return seen.joined(separator: "+")
    }

    func langForLine(_ line: String) -> String {
        if let i = lines.firstIndex(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == line }),
           i < lineLangs.count, !lineLangs[i].isEmpty {
            return lineLangs[i]
        }
        return lineLangs.first(where: { !$0.isEmpty }) ?? "en"
    }

    func transStatusText() -> TransStatus {
        if trackKey.isEmpty { return .noSong }
        if !loaded { return .waiting }
        if lines.isEmpty { return .noLyrics }
        if transKey == trackKey {
            if let f = transError { return .failed(f) }
            if transBusy || trans.isEmpty { return .busy }
            if !hasForeign { return .same }
            return .ready(langSummary(), Prefs.target)
        }
        return .queued
    }

    @objc func setSongLang(_ s: NSMenuItem) {
        guard !trackKey.isEmpty else { return }
        let v = s.representedObject as? String
        Prefs.setSongOverride(trackKey, v?.isEmpty == true ? nil : v)
        langChanged()
    }

    func rebuildSongLangMenu() {
        let sub = NSMenu()
        let cur = Prefs.songOverride(trackKey)
        let auto = NSMenuItem(title: L(.followSettings), action: #selector(setSongLang(_:)), keyEquivalent: "")
        auto.representedObject = ""
        auto.target = self
        auto.state = cur == nil ? .on : .off
        sub.addItem(auto)
        sub.addItem(.separator())
        for l in songLangs {
            let m = NSMenuItem(title: Lang.name(l), action: #selector(setSongLang(_:)), keyEquivalent: "")
            m.representedObject = l
            m.target = self
            m.state = cur == l ? .on : .off
            sub.addItem(m)
        }
        songLangItem.submenu = sub
        songLangItem.title = cur.map { L(.songLanguageValue, Lang.name($0)) } ?? L(.songLanguage)
    }

    func rebuildSongMenu() {
        songMenu.removeAllItems()
        let hasTrack = !trackKey.isEmpty && !lastIsAd
        songItem.isEnabled = hasTrack
        guard hasTrack else { return }
        if hasForeign || Prefs.songOverride(trackKey) != nil {
            rebuildSongLangMenu()
            songLangItem.target = self
            songMenu.addItem(songLangItem)
        }
        reloadItem.target = self
        songMenu.addItem(reloadItem)
        if !lines.isEmpty { songMenu.addItem(copyExportItem()) }
    }

    func applyDisplayMode(_ m: String) {
        displayMode = m
        UserDefaults.standard.set(m, forKey: "displayMode")
    }

    func applyRomanizedSuggestion() {
        guard let tag = romSuggestion, !trackKey.isEmpty else { return }
        Prefs.setSongOverride(trackKey, tag)
        langChanged()
        syncMenuFlags()
    }

    func dismissRomanizedSuggestion() {
        Prefs.dismissRomanized(trackKey)
        romSuggestion = nil
        syncMenuFlags()
    }

    func casualChanged() {
        resetTranslation()
        floatSig = ""
        learnKey = ""
    }

    func romajiChanged() {
        floatSig = ""
        learnKey = ""
        syncMenuFlags()
    }

    func accentChanged() {
        applyAccent(MainActor.assumeIsolated { menuModel?.artwork })
    }

    func toggleRomaji() {
        Prefs.showRomaji.toggle()
        romajiChanged()
    }

    func ensureTranslation() {
        let key = trackKey
        let texts = lines.map { $0.text }
        let target = Prefs.target
        let ov = Prefs.songOverride(key)
        if ov == nil, Prefs.sourceMode != "fixed", !Prefs.isRomanizedDismissed(key), let g = Romanized.guess(texts) {
            romSuggestion = g
            if suggestedKeys.insert(key).inserted { flash(L(.suggestFlash)) }
        } else {
            romSuggestion = nil
        }
        let cacheKey = "\(ov.map { "o-" + $0 } ?? Prefs.signature)|\(target)|\(key)"
        let gen = transGen
        transKey = key
        transError = nil
        trans = []
        let rom = ov.flatMap { Romaji.base($0) }
        let work = ov.map { o in rom == nil ? texts : texts.map { Romaji.convert($0, o) } } ?? texts
        let langs = Detect.perLine(texts, override: rom ?? ov)
        lineLangs = langs
        romaji = zip(texts, langs).map { Readings.romanize($0, lang: $1) }
        if !langs.contains(where: { !$0.isEmpty && !Lang.same($0, target) }) {
            trans = Array(repeating: "", count: texts.count)
            return
        }
        let casual = Prefs.casual
        if let c = Store.readTrans(cacheKey), c.count == texts.count {
            trans = casual ? Casual.apply(c, target: target) : c
            return
        }
        transBusy = true
        Task {
            let r = await self.translator.translateBatch(work, langs: langs, target: target)
            DispatchQueue.main.async {
                self.transBusy = false
                guard self.transGen == gen, self.trackKey == key, self.lines.count == texts.count else { return }
                self.trans = casual ? Casual.apply(r.out, target: target) : r.out
                if r.errors.isEmpty {
                    Store.writeTrans(cacheKey, r.out)
                } else {
                    let msg = r.errors.map { "\(Lang.name($0.key)): \($0.value)" }.sorted().joined(separator: "; ")
                    self.transError = msg
                    Diagnostics.log("translation failed: \(msg)")
                    if self.learn.window.isVisible {
                        self.learn.show(L(.transFailedLearn, msg))
                    }
                }
            }
        }
    }

    // MARK: menu
}
