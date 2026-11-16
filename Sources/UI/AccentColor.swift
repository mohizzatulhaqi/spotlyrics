import Cocoa
import SwiftUI

enum AccentExtractor {
    static func color(from image: NSImage) -> Color? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let n = 32
        var data = [UInt8](repeating: 0, count: n * n * 4)
        let ok: Bool = data.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8,
                                      bytesPerRow: n * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        guard ok else { return nil }
        var px: [RGB] = []
        for i in 0..<(n * n) {
            let a = Double(data[i * 4 + 3])
            if a == 0 { continue }
            px.append(RGB(r: min(1, Double(data[i * 4]) / a), g: min(1, Double(data[i * 4 + 1]) / a), b: min(1, Double(data[i * 4 + 2]) / a)))
        }
        guard let c = Palette.accent(from: px) else { return nil }
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}
