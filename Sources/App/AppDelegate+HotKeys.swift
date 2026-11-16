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
            let c = h.combo
            let st = RegisterEventHotKey(c.code, c.modifiers, EventHotKeyID(signature: OSType(0x53504C59), id: h.id),
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

    func shortcutRows() -> [ShortcutRow] {
        hotKeys.map { h in
            ShortcutRow(id: Int(h.id), title: h.title, combo: h.combo.display,
                        taken: hotFailed.contains(h.id), custom: Prefs.hasCustomHotKey(id: Int(h.id)))
        }
    }

    func startRecordingShortcut(_ id: Int) {
        stopRecordingShortcut()
        unregisterHotKeys()
        recordingId = id
        MainActor.assumeIsolated {
            settingsModel?.recordingId = id
            settingsModel?.recordMessage = ""
        }
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let s = self, let id = s.recordingId else { return e }
            let code = UInt32(e.keyCode)
            if code == 53 {
                s.stopRecordingShortcut()
                return nil
            }
            var mods: UInt32 = 0
            let f = e.modifierFlags
            if f.contains(.control) { mods |= KeyCombo.control }
            if f.contains(.option) { mods |= KeyCombo.option }
            if f.contains(.shift) { mods |= KeyCombo.shift }
            if f.contains(.command) { mods |= KeyCombo.command }
            let combo = KeyCombo(code: code, modifiers: mods)
            guard combo.hasRequiredModifier else {
                MainActor.assumeIsolated { s.settingsModel?.recordMessage = L(.recordNeedMod) }
                return nil
            }
            var current: [Int: KeyCombo] = [:]
            for h in s.hotKeys { current[Int(h.id)] = h.combo }
            if let other = HotKeyRules.conflict(for: combo, excluding: id, current: current),
               let spec = s.hotKeys.first(where: { Int($0.id) == other }) {
                MainActor.assumeIsolated { s.settingsModel?.recordMessage = L(.recordConflict, spec.title) }
                return nil
            }
            let isDefault = s.hotKeys.first(where: { Int($0.id) == id })?.defaultCombo == combo
            Prefs.setHotKeyCombo(id: id, isDefault ? nil : combo)
            s.stopRecordingShortcut()
            return nil
        }
    }

    func stopRecordingShortcut() {
        guard recordingId != nil || recordMonitor != nil else { return }
        if let m = recordMonitor { NSEvent.removeMonitor(m) }
        recordMonitor = nil
        recordingId = nil
        MainActor.assumeIsolated {
            settingsModel?.recordingId = nil
            settingsModel?.recordMessage = ""
        }
        unregisterHotKeys()
        if hotKeysOn { registerHotKeys() }
        refreshSettings()
    }

    func resetShortcut(_ id: Int) {
        Prefs.setHotKeyCombo(id: id, nil)
        unregisterHotKeys()
        if hotKeysOn { registerHotKeys() }
        refreshSettings()
    }

    func resetAllShortcuts() {
        Prefs.resetHotKeys()
        unregisterHotKeys()
        if hotKeysOn { registerHotKeys() }
        refreshSettings()
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
        case 6:
            copyCurrentLine()
        default: break
        }
    }
}
