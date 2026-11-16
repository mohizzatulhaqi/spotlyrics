import Cocoa

let out = CommandLine.arguments[1]
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: rect, xRadius: 184, yRadius: 184)
let grad = NSGradient(colors: [NSColor(red: 0.12, green: 0.84, blue: 0.38, alpha: 1), NSColor(red: 0.02, green: 0.45, blue: 0.5, alpha: 1)])!
grad.draw(in: path, angle: -60)
let cfg = NSImage.SymbolConfiguration(pointSize: 460, weight: .bold)
if let sym = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    let tinted = NSImage(size: sym.size)
    tinted.lockFocus()
    sym.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: sym.size).fill(using: .sourceAtop)
    tinted.unlockFocus()
    let r = NSRect(x: (size - sym.size.width) / 2, y: (size - sym.size.height) / 2,
                   width: sym.size.width, height: sym.size.height)
    tinted.draw(in: r)
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
