import Foundation
import AVFoundation

enum VocabExporter {
    struct Result {
        let url: URL
        let cards: Int
        let audio: Int
        let missingVoice: Int
    }

    static func language(for e: VocabEntry) -> String? {
        if let l = e.lang, !l.isEmpty { return l }
        return Detect.script(e.word) ?? Detect.script(e.line) ?? Detect.line(e.line, [])
    }

    static func hasVoice(_ code: String) -> Bool {
        guard let l = Speech.voiceLanguage(for: code) else { return false }
        return AVSpeechSynthesisVoice(language: l) != nil
    }

    static func audioName(text: String, lang: String) -> String {
        "sl_" + AnkiPackage.sha1Hex(text + "|" + lang).prefix(12) + ".m4a"
    }

    static func exportApkg(entries: [VocabEntry], progress: @escaping (Int, Int) -> Void) async throws -> Result {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("spotlyrics-audio-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        struct Job { let name: String; let text: String; let lang: String }
        var jobs: [Job] = []
        var seen = Set<String>()
        var missing = 0
        for e in entries {
            guard let lang = language(for: e), hasVoice(lang) else { missing += 1; continue }
            for text in [e.word, e.line] where !Speech.prepare(text).isEmpty {
                let name = audioName(text: text, lang: lang)
                if seen.insert(name).inserted { jobs.append(Job(name: name, text: text, lang: lang)) }
            }
        }

        var made: [String: URL] = [:]
        for (i, j) in jobs.enumerated() {
            progress(i, jobs.count)
            let url = tmp.appendingPathComponent(j.name)
            if await AudioSynth.write(text: j.text, language: j.lang, to: url) { made[j.name] = url }
        }
        progress(jobs.count, jobs.count)

        var notes: [AnkiNote] = []
        for e in entries {
            var wa: String?, la: String?
            if let lang = language(for: e) {
                let w = audioName(text: e.word, lang: lang), l = audioName(text: e.line, lang: lang)
                if made[w] != nil { wa = w }
                if !e.line.isEmpty, made[l] != nil { la = l }
            }
            notes.append(AnkiNote(word: e.word, meaning: e.meaning, line: e.line, song: e.song, wordAudio: wa, lineAudio: la))
        }
        let media = made.keys.sorted().compactMap { n in made[n].map { AnkiMedia(name: n, url: $0) } }
        let out = Vocab.downloads("SpotLyrics-vocab.apkg")
        try AnkiPackage.write(notes: notes, media: media, to: out)
        return Result(url: out, cards: notes.count, audio: media.count, missingVoice: missing)
    }
}
