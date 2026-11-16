import Foundation
import Carbon.HIToolbox

nonisolated(unsafe) var gHotKeyHandler: ((UInt32) -> Void)?

struct HotKeySpec {
    let id: UInt32
    let defaultCode: UInt32
    let titleKey: S
    var title: String { L(titleKey) }
    var defaultCombo: KeyCombo { KeyCombo(code: defaultCode, modifiers: KeyCombo.control | KeyCombo.option) }
    var combo: KeyCombo { Prefs.hotKeyCombo(id: Int(id), default: defaultCombo) }
}

struct ShortcutRow: Identifiable {
    let id: Int
    let title: String
    let combo: String
    let taken: Bool
    let custom: Bool
}
