import Foundation

struct KeyCombo: Equatable {
    static let command: UInt32 = 0x100
    static let shift: UInt32 = 0x200
    static let option: UInt32 = 0x800
    static let control: UInt32 = 0x1000

    var code: UInt32
    var modifiers: UInt32

    var hasRequiredModifier: Bool {
        modifiers & (KeyCombo.command | KeyCombo.option | KeyCombo.control) != 0
    }

    var display: String {
        var s = ""
        if modifiers & KeyCombo.control != 0 { s += "⌃" }
        if modifiers & KeyCombo.option != 0 { s += "⌥" }
        if modifiers & KeyCombo.shift != 0 { s += "⇧" }
        if modifiers & KeyCombo.command != 0 { s += "⌘" }
        return s + (KeyCombo.keyName(code) ?? "#\(code)")
    }

    static let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W",
        14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 109: "F10",
        111: "F12", 118: "F4", 120: "F2", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    static func keyName(_ code: UInt32) -> String? { names[code] }

    var storage: [Int] { [Int(code), Int(modifiers)] }

    init(code: UInt32, modifiers: UInt32) {
        self.code = code
        self.modifiers = modifiers
    }

    init?(storage: [Int]) {
        guard storage.count == 2, storage[0] >= 0, storage[1] >= 0 else { return nil }
        self.init(code: UInt32(storage[0]), modifiers: UInt32(storage[1]))
    }
}

enum HotKeyRules {
    static func conflict(for combo: KeyCombo, excluding id: Int, current: [Int: KeyCombo]) -> Int? {
        current.first { $0.key != id && $0.value == combo }?.key
    }
}

enum AutomationState: Equatable {
    case granted, denied, notAsked, appNotRunning, unknown(Int)

    init(osStatus s: Int) {
        switch s {
        case 0: self = .granted
        case -1743: self = .denied
        case -1744: self = .notAsked
        case -600: self = .appNotRunning
        default: self = .unknown(s)
        }
    }

    var label: String {
        switch self {
        case .granted: return "granted"
        case .denied: return "denied"
        case .notAsked: return "not asked yet"
        case .appNotRunning: return "unknown (Spotify is not running)"
        case .unknown(let s): return "unknown (\(s))"
        }
    }
}

enum Setup {
    static func completed(spotifyRunning: Bool, automation: AutomationState, targetChosen: Bool) -> Int {
        [spotifyRunning, automation == .granted, targetChosen].filter { $0 }.count
    }

    static let total = 3

    static func isComplete(spotifyRunning: Bool, automation: AutomationState, targetChosen: Bool) -> Bool {
        completed(spotifyRunning: spotifyRunning, automation: automation, targetChosen: targetChosen) == total
    }
}
