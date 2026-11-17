import Cocoa
import SwiftUI

extension AppDelegate {
    @objc func openReviewAction() { openReview() }
    @objc func openLibraryAction() { openLibrary() }

    func refreshReviewTitles() {
        let due = SRS.dueCount(Vocab.load(), now: Date(), newLimit: Prefs.reviewNewPerSession)
        reviewItem.title = due > 0 ? L(.reviewMenuDue, due) : L(.reviewMenu)
        libraryItem.title = L(.libMenu)
    }

    func openReview() {
        MainActor.assumeIsolated {
            if reviewWindow == nil {
                let m = ReviewModel()
                m.onSpeak = { [weak self] e in
                    self?.learn.speaker.speak(e.word, language: e.lang ?? VocabExporter.language(for: e) ?? "en")
                }
                m.onChanged = { [weak self] in
                    self?.refreshReviewTitles()
                    self?.vocabModel?.reload()
                }
                let hc = NSHostingController(rootView: ReviewView(m: m))
                hc.sizingOptions = []
                let w = NSWindow(contentViewController: hc)
                w.styleMask = [.titled, .closable, .resizable]
                w.isReleasedWhenClosed = false
                w.setContentSize(NSSize(width: 520, height: 400))
                w.center()
                reviewModel = m
                reviewWindow = w
            }
            reviewWindow?.title = L(.reviewTitle)
            reviewModel?.start()
            NSApp.activate(ignoringOtherApps: true)
            reviewWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func openLibraryQuiz(_ e: LibraryEntry, _ translations: [String]) {
        MainActor.assumeIsolated {
            if libQuizWindow == nil {
                let m = QuizModel()
                m.canPlay = false
                m.onSpeak = { [weak self] i in
                    guard let s = self, let e = s.libraryModel?.selected, i < e.lines.count else { return }
                    let line = e.lines[i].text
                    s.learn.speaker.speak(line, language: s.libraryModel?.lang(ofLine: i, in: e) ?? "en")
                }
                let hc = NSHostingController(rootView: QuizView(m: m))
                hc.sizingOptions = []
                let w = NSWindow(contentViewController: hc)
                w.styleMask = [.titled, .closable, .resizable]
                w.isReleasedWhenClosed = false
                w.level = .floating
                w.setContentSize(NSSize(width: 520, height: 340))
                w.center()
                libQuizModel = m
                libQuizWindow = w
            }
            libQuizModel?.load(lines: e.lines.map { $0.text }, translations: translations)
            libQuizWindow?.title = "\(L(.quizTitle)) – \(e.title)"
            NSApp.activate(ignoringOtherApps: true)
            libQuizWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func openLibrary() {
        MainActor.assumeIsolated {
            if libraryWindow == nil {
                let m = LibraryModel()
                m.translator = translator
                m.onChanged = { [weak self] in self?.vocabChanged() }
                m.onSpeak = { [weak self] text, lang in
                    guard let s = self else { return }
                    s.learn.speaker.speak(s.learn.prep(text), language: lang)
                }
                m.onQuiz = { [weak self] e, tr in self?.openLibraryQuiz(e, tr) }
                let hc = NSHostingController(rootView: LibraryView(m: m))
                hc.sizingOptions = []
                let w = NSWindow(contentViewController: hc)
                w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
                w.isReleasedWhenClosed = false
                w.setContentSize(NSSize(width: 900, height: 620))
                w.center()
                libraryModel = m
                libraryWindow = w
            }
            libraryWindow?.title = L(.libTitle)
            libraryModel?.reload(select: trackKey.isEmpty ? nil : trackKey)
            NSApp.activate(ignoringOtherApps: true)
            libraryWindow?.makeKeyAndOrderFront(nil)
        }
    }
}
