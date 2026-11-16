import Cocoa
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import Translation
import NaturalLanguage

extension AppDelegate {
    @objc func toggleFloat() { setFloat(!floatOn) }

    func setFloat(_ on: Bool) {
        floatOn = on
        UserDefaults.standard.set(on, forKey: "floatOn")
        if !on { floatPanel?.orderOut(nil); return }
        MainActor.assumeIsolated {
            if floatPanel == nil {
                let fm = FloatModel()
                fm.artwork = menuModel?.artwork
                fm.accent = menuModel?.accent
                fm.onClose = { [weak self] in self?.setFloat(false) }
                let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 580, height: 220),
                                styleMask: [.borderless, .resizable, .nonactivatingPanel],
                                backing: .buffered, defer: false)
                p.contentView = NSHostingView(rootView: FloatView(m: fm))
                p.isOpaque = false
                p.backgroundColor = .clear
                p.hasShadow = true
                p.level = .floating
                p.hidesOnDeactivate = false
                p.isMovableByWindowBackground = true
                p.isReleasedWhenClosed = false
                p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                p.minSize = NSSize(width: 360, height: 160)
                if !p.setFrameUsingName("SpotLyricsFloat"), let sc = NSScreen.main {
                    let f = sc.visibleFrame
                    p.setFrameOrigin(NSPoint(x: f.midX - 290, y: f.minY + 80))
                }
                p.setFrameAutosaveName("SpotLyricsFloat")
                floatModel = fm
                floatPanel = p
            }
        }
        floatSig = ""
        floatPanel?.orderFrontRegardless()
    }

    func floatMessage(_ cur: String, _ sub: String = "") {
        guard floatOn else { return }
        let sig = "msg|\(cur)|\(sub)"
        guard sig != floatSig else { return }
        floatSig = sig
        MainActor.assumeIsolated { floatModel?.set(prev: "", cur: cur, sub: sub, next: "") }
    }

    func updateFloat(idx: Int?) {
        guard floatOn else { return }
        let sig = "\(trackKey)#\(idx ?? -1)#\(transKey == trackKey ? trans.count : -1)#\(displayMode)#\(loaded)#\(lines.count)#\(romaji.count)#\(Prefs.showRomaji)#\(lyricsSynced)"
        guard sig != floatSig else { return }
        floatSig = sig
        MainActor.assumeIsolated {
            guard let f = floatModel else { return }
            if lines.isEmpty {
                if lastIsEpisode {
                    f.set(prev: "", cur: L(.podcastNoLyrics), sub: "", next: "")
                    return
                }
                f.set(prev: "", cur: loaded ? L(.lyricsUnavailable) : L(.lyricsLoading), sub: "", next: "")
                return
            }
            if !lyricsSynced {
                let tr = transKey == trackKey ? trans : []
                let showRm = Prefs.showRomaji && displayMode != "trans"
                f.setPlain(lines.indices.map { i in
                    let t = i < tr.count ? tr[i] : ""
                    let r = showRm && i < romaji.count ? romaji[i] : ""
                    return PlainLine(id: i, text: lines[i].text, rom: r, trans: displayMode == "orig" ? "" : t)
                })
                return
            }
            func text(_ i: Int) -> String { lines[i].text.isEmpty ? "♪" : lines[i].text }
            let nx = (idx ?? -1) + 1
            let orig = idx.map(text) ?? "♪"
            let tr = (transKey == trackKey && idx != nil && idx! < trans.count) ? trans[idx!] : ""
            let rm = (Prefs.showRomaji && displayMode != "trans" && idx != nil && idx! < romaji.count) ? romaji[idx!] : ""
            let cur: String, sub: String
            switch displayMode {
            case "trans": cur = tr.isEmpty ? orig : tr; sub = ""
            case "both": cur = orig; sub = tr
            default: cur = orig; sub = ""
            }
            f.set(prev: (idx ?? 0) > 0 ? text(idx! - 1) : "", cur: cur, sub: sub, next: nx < lines.count ? text(nx) : "", rom: rm)
        }
    }

    func setArtwork(_ img: NSImage?) {
        MainActor.assumeIsolated {
            menuModel?.artwork = img
            floatModel?.artwork = img
        }
        applyAccent(img)
        updateMenuBarCover(img)
    }

    func clearCoverIfShown() {
        if item.button?.image != nil { setArtwork(nil) }
    }

    func updateMenuBarCover(_ img: NSImage?) {
        guard let b = item.button else { return }
        if Prefs.menuBarCover, let img = img {
            b.image = MenuBarCover.make(from: img)
            b.imagePosition = .imageLeft
        } else {
            b.image = nil
        }
        updateStatusWidth()
    }

    func applyAccent(_ img: NSImage?) {
        let c: Color? = Prefs.coverAccent ? img.flatMap { AccentExtractor.color(from: $0) } : nil
        MainActor.assumeIsolated {
            menuModel?.accent = c
            floatModel?.accent = c
        }
    }

}
