import Foundation

enum LyricsExport {
    static func clock(_ t: Double) -> String {
        let ms = max(0, Int((t * 1000).rounded()))
        return String(format: "%02d:%02d:%02d,%03d", ms / 3_600_000, (ms / 60_000) % 60, (ms / 1000) % 60, ms % 1000)
    }

    static func isBlank(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty || t == "♪"
    }

    static func block(text: String, romaji: String = "", translation: String = "") -> String {
        [text, romaji, translation].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func text(lines: [Line], translations: [String] = [], romaji: [String] = []) -> String {
        let hasExtras = translations.contains { !$0.isEmpty } || romaji.contains { !$0.isEmpty }
        var blocks: [String] = []
        for (i, l) in lines.enumerated() {
            if isBlank(l.text) {
                if !hasExtras { blocks.append("") }
                continue
            }
            let rm = i < romaji.count ? romaji[i] : ""
            let tr = i < translations.count ? translations[i] : ""
            blocks.append(block(text: l.text, romaji: rm, translation: tr))
        }
        return blocks.joined(separator: hasExtras ? "\n\n" : "\n")
    }

    static func srt(lines: [Line], translations: [String] = [], romaji: [String] = [], duration: Double = 0, maxCue: Double = 8) -> String {
        var cues: [String] = []
        var n = 0
        for (i, l) in lines.enumerated() where !isBlank(l.text) {
            n += 1
            let nextTime: Double
            if i + 1 < lines.count {
                nextTime = lines[i + 1].time
            } else {
                nextTime = duration > l.time ? duration : l.time + 5
            }
            let end = min(max(nextTime, l.time + 0.3), l.time + maxCue)
            let rm = i < romaji.count ? romaji[i] : ""
            let tr = i < translations.count ? translations[i] : ""
            cues.append("\(n)\n\(clock(l.time)) --> \(clock(end))\n\(block(text: l.text, romaji: rm, translation: tr))")
        }
        return cues.joined(separator: "\n\n") + (cues.isEmpty ? "" : "\n")
    }

    static func fileName(artist: String, title: String, ext: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        func clean(_ s: String) -> String {
            s.unicodeScalars.map { bad.contains($0) ? "_" : String($0) }.joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let base = [clean(artist), clean(title)].filter { !$0.isEmpty }.joined(separator: " - ")
        return (base.isEmpty ? "lyrics" : String(base.prefix(120))) + "." + ext
    }
}
