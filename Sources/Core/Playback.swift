import Foundation

enum Playback {
    static func position(posMs: Int, durMs: Int, playing: Bool, at: Date, now: Date) -> Int {
        guard playing else { return posMs }
        let p = posMs + max(0, Int(now.timeIntervalSince(at) * 1000))
        return durMs > 0 ? min(durMs, p) : p
    }
}

enum Seek {
    static func position(x: Double, width: Double, duration: Double) -> Double {
        guard width > 0, duration > 0 else { return 0 }
        return min(1, max(0, x / width)) * duration
    }
}

enum Marquee {
    static let gap = "   •   "
    static let pause = 1.4
    static let step = 0.13

    static func window(_ text: String, width: Int, elapsed: Double) -> String {
        if text.count <= width { return text }
        let loop = Array(text + gap)
        let cycle = pause + Double(loop.count) * step
        let t = elapsed.truncatingRemainder(dividingBy: cycle)
        let off = t < pause ? 0 : Int((t - pause) / step) % loop.count
        return String((0..<width).map { loop[(off + $0) % loop.count] })
    }
}
