import Foundation
import CoreServices

enum Dict {
    // macOS built-in dictionary (offline, English definitions).
    static func define(_ w: String) -> String? {
        let cf = w as CFString
        guard let r = DCSCopyTextDefinition(nil, cf, CFRange(location: 0, length: CFStringGetLength(cf)))?.takeRetainedValue()
        else { return nil }
        let s = r as String
        return s.count > 500 ? String(s.prefix(500)) + "…" : s
    }
}
