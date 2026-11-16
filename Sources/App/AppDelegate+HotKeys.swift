import Cocoa
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import Translation
import NaturalLanguage

extension AppDelegate {
    func registerHotKeys() {
        if !hotHandlerInstalled {
            hotHandlerInstalled = true
            gHotKeyHandler = { [weak self] id in DispatchQueue.main.async { self?.handleHotKey(id) } }
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var hk = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(0x686B6964),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
                gHotKeyHandler?(hk.id)
                return noErr
            }, 1, &spec, nil, nil)
        }
        hotFailed = []
        for h in hotKeys {
            var ref: EventHotKeyRef?
            let st = RegisterEventHotKey(h.code, UInt32(controlKey | optionKey), EventHotKeyID(signature: OSType(0x53504C59), id: h.id),
                                         GetApplicationEventTarget(), 0, &ref)
            if st == noErr, let r = ref { hotRefs.append(r) } else { hotFailed.insert(h.id) }
        }
    }

    func unregisterHotKeys() {
        for r in hotRefs { UnregisterEventHotKey(r) }
        hotRefs = []
        hotFailed = []
    }

    func setHotKeys(_ on: Bool) {
        hotKeysOn = on
        UserDefaults.standard.set(on, forKey: "hotKeysOn")
        if on { registerHotKeys() } else { unregisterHotKeys() }
        refreshSettings()
    }

    func hotKeyLines() -> [String] {
        hotKeys.map { h in
            let note = hotFailed.contains(h.id) ? "  " + L(.hotkeyTaken) : ""
            return "⌃⌥\(h.symbol)   \(h.title)\(note)"
        }
    }

    func flash(_ t: String) {
        flashText = t
        flashUntil = Date().addingTimeInterval(1.6)
        setTitle(t)
    }

    func handleHotKey(_ id: UInt32) {
        switch id {
        case 1:
            setFloat(!floatOn)
            flash(floatOn ? L(.floatOnMsg) : L(.floatOffMsg))
        case 2:
            let order = ["orig", "trans", "both"]
            let names = ["orig": L(.modeOriginal), "trans": L(.modeTranslation), "both": L(.modeBoth)]
            let next = order[((order.firstIndex(of: displayMode) ?? 0) + 1) % order.count]
            applyDisplayMode(next)
            floatSig = ""
            learnKey = ""
            MainActor.assumeIsolated { menuModel?.mode = next }
            flash(L(.displayModeMsg, names[next] ?? next))
        case 3:
            toggleLyrics()
            flash(hidden ? L(.menuBarLyricsHidden) : L(.menuBarLyricsShown))
        case 4:
            slower()
            syncOffsetText()
            flash(L(.offsetMsg, offset))
        case 5:
            faster()
            syncOffsetText()
            flash(L(.offsetMsg, offset))
        default: break
        }
    }
}
