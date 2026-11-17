import Cocoa
import SwiftUI

extension AppDelegate {
    @objc func openVocabAction() { openVocab() }

    func openVocab() {
        MainActor.assumeIsolated {
            if vocabWindow == nil {
                let m = VocabModel()
                m.onSpeak = { [weak self] e in
                    self?.learn.speaker.speak(e.word, language: e.lang ?? VocabExporter.language(for: e) ?? "en")
                }
                m.onChanged = { [weak self] in self?.learn.updateCount() }
                m.onReview = { [weak self] in self?.openReview() }
                vocabModel = m
                let hc = NSHostingController(rootView: VocabView(m: m))
                hc.sizingOptions = []
                let w = NSWindow(contentViewController: hc)
                w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
                w.isReleasedWhenClosed = false
                w.setContentSize(NSSize(width: 760, height: 600))
                w.center()
                vocabWindow = w
            }
            vocabWindow?.title = L(.vocabTitle)
            vocabModel?.reload()
            NSApp.activate(ignoringOtherApps: true)
            vocabWindow?.makeKeyAndOrderFront(nil)
        }
    }

    func vocabChanged() {
        MainActor.assumeIsolated {
            vocabModel?.reload()
            libraryModel?.refreshDetail()
        }
        refreshReviewTitles()
        learn.updateCount()
    }
}
