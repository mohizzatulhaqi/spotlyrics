import Cocoa
import SwiftUI

extension AppDelegate {
    func openQuiz() {
        MainActor.assumeIsolated {
            if quizWindow == nil {
                let m = QuizModel()
                m.onPlay = { [weak self] i in
                    guard let s = self, s.lyricsSynced, i < s.lines.count else { return }
                    s.seek(Playback.rawPosition(forLineTime: s.lines[i].time, offset: s.offset))
                }
                m.onSpeak = { [weak self] i in
                    guard let s = self, i < s.lines.count else { return }
                    let line = s.lines[i].text
                    s.learn.speaker.speak(s.learn.prep(line), language: s.langForLine(line))
                }
                let hc = NSHostingController(rootView: QuizView(m: m))
                hc.sizingOptions = []
                let w = NSWindow(contentViewController: hc)
                w.styleMask = [.titled, .closable, .resizable]
                w.isReleasedWhenClosed = false
                w.level = .floating
                w.setContentSize(NSSize(width: 520, height: 340))
                w.center()
                quizModel = m
                quizWindow = w
            }
            let tr = transKey == trackKey ? trans : []
            quizModel?.load(lines: lines.map { $0.text }, translations: tr)
            quizWindow?.title = L(.quizTitle)
            NSApp.activate(ignoringOtherApps: true)
            quizWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func clearStudyState() {
        learn.speaker.stop()
        loop = nil
        learn.clearLoopSilently()
        quizWindow?.close()
    }
}

extension AppDelegate {
    func vocabInfo(word: String, line: String) -> (reading: String, lineReading: String, lineTranslation: String) {
        let lang = langForLine(line)
        let style = Prefs.readingStyle
        let idx = lines.firstIndex(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == line })
        let wordReading = Readings.reading(word, lang: lang, style: style)
        let lineReading = idx.flatMap { $0 < romaji.count ? romaji[$0] : nil } ?? Readings.reading(line, lang: lang, style: style)
        let translation = (idx != nil && transKey == trackKey && idx! < trans.count) ? trans[idx!] : ""
        return (wordReading, lineReading, translation)
    }
}
