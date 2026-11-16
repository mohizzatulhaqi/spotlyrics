import Cocoa

enum MenuBarCover {
    static func make(from image: NSImage, side: CGFloat = 18) -> NSImage {
        let out = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).addClip()
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        out.isTemplate = false
        return out
    }
}
