import Foundation
import Carbon.HIToolbox

nonisolated(unsafe) var gHotKeyHandler: ((UInt32) -> Void)?

struct HotKeySpec {
    let id: UInt32
    let code: UInt32
    let symbol: String
    let titleKey: S
    var title: String { L(titleKey) }
}
