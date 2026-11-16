import Foundation

struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double
}

enum Palette {
    static func hsv(_ c: RGB) -> (h: Double, s: Double, v: Double) {
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b)
        let d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == c.r { h = 60 * ((c.g - c.b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == c.g { h = 60 * ((c.b - c.r) / d + 2) }
            else { h = 60 * ((c.r - c.g) / d + 4) }
        }
        if h < 0 { h += 360 }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }

    static func rgb(h: Double, s: Double, v: Double) -> RGB {
        let c = v * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (r, g, b): (Double, Double, Double)
        switch h {
        case ..<60: (r, g, b) = (c, x, 0)
        case ..<120: (r, g, b) = (x, c, 0)
        case ..<180: (r, g, b) = (0, c, x)
        case ..<240: (r, g, b) = (0, x, c)
        case ..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return RGB(r: r + m, g: g + m, b: b + m)
    }

    static func accent(from pixels: [RGB]) -> RGB? {
        guard !pixels.isEmpty else { return nil }
        let bins = 12
        var weight = Array(repeating: 0.0, count: bins)
        var sr = weight, sg = weight, sb = weight
        var qualifying = 0
        for p in pixels {
            let (h, s, v) = hsv(p)
            if v < 0.2 || s < 0.15 { continue }
            qualifying += 1
            let w = s * s * (0.3 + v)
            let i = Int(h / 30) % bins
            weight[i] += w
            sr[i] += p.r * w
            sg[i] += p.g * w
            sb[i] += p.b * w
        }
        guard Double(qualifying) >= Double(pixels.count) * 0.03 else { return nil }
        var best = -1
        var bestScore = 0.0
        for i in 0..<bins {
            let score = weight[i] + 0.5 * (weight[(i + 1) % bins] + weight[(i + bins - 1) % bins])
            if score > bestScore { bestScore = score; best = i }
        }
        guard best >= 0, weight[best] > 0 else { return nil }
        let avg = RGB(r: sr[best] / weight[best], g: sg[best] / weight[best], b: sb[best] / weight[best])
        let (h, s, v) = hsv(avg)
        return rgb(h: h, s: min(max(s, 0.45), 0.9), v: min(max(v, 0.78), 1.0))
    }
}
