import Cocoa
import AVFoundation

// MARK: - Study window (click a word)

final class LyricsTextView: NSTextView {
    var onClick: ((String?, String) -> Void)?
    var onDoubleClick: ((Int) -> Void)?
    var onParagraph: ((Int) -> Void)?

    override func mouseDown(with event: NSEvent) {
        let ns = string as NSString
        guard ns.length > 0 else { return }
        let p = convert(event.locationInWindow, from: nil)
        let i = min(characterIndexForInsertion(at: p), ns.length - 1)
        // One paragraph = the original line, then (optionally) the translation after U+2028
        let paraR = ns.paragraphRange(for: NSRange(location: i, length: 0))
        let para = ns.substring(with: paraR) as NSString
        let sep = para.range(of: "\u{2028}")
        let origText = sep.location == NSNotFound ? para as String : para.substring(to: sep.location)
        let inTrans = sep.location != NSNotFound && i >= paraR.location + sep.location
        let origR = NSRange(location: paraR.location, length: (origText as NSString).length)
        let line = origText.trimmingCharacters(in: .whitespacesAndNewlines)
        onParagraph?(paraR.location)
        if event.clickCount == 2 {
            setSelectedRange(origR)
            onDoubleClick?(paraR.location)
            return
        }

        var word = ""
        var wr = origR
        if !inTrans {
            wr = selectionRange(forProposedRange: NSRange(location: i, length: 0), granularity: .selectByWord)
            word = ns.substring(with: wr)
                .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
        }
        setSelectedRange(word.isEmpty ? origR : wr)
        onClick?(word.isEmpty ? nil : word, line)
    }
}

final class LearnPanel: NSObject, @unchecked Sendable {
    let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
                         styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    let tv = LyricsTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 410))
    let result = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 130))
    var countLabel: NSTextField!
    var translateBtn: NSButton!
    var saveBtn: NSButton!
    var exportBtn: NSButton!
    var speakBtn: NSButton!
    let speaker = Speaker()
    var lastMeaningFound = false
    var times: [Double] = []
    var onSeek: (Double) -> Void = { _ in }
    var onLoop: (Int?, Int?) -> Void = { _, _ in }
    var onQuiz: () -> Void = {}
    var loopA: Int?
    var loopB: Int?
    var selectedIdx: Int?
    var loopLabel: NSTextField!
    var loopABtn: NSButton!
    var loopBBtn: NSButton!
    var loopClearBtn: NSButton!
    var quizBtn: NSButton!

    var ranges: [NSRange] = []
    var curIdx = -1
    var translator: Translator!
    var langFor: (String) -> String = { _ in "en" }
    var prep: (String) -> String = { $0 }
    var lastWord: String?
    var lastMeaning: String?
    var lastLine: String?
    var currentLineText = ""
    var lastClick = Date.distantPast
    var song: () -> String = { "" }

    func scroll(_ t: NSTextView, _ f: NSRect, _ mask: NSView.AutoresizingMask) -> NSScrollView {
        let s = NSScrollView(frame: f)
        s.hasVerticalScroller = true
        s.autoresizingMask = mask
        t.minSize = NSSize(width: 0, height: 0)
        t.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        t.isVerticallyResizable = true
        t.isHorizontallyResizable = false
        t.autoresizingMask = .width
        t.textContainer?.containerSize = NSSize(width: f.width, height: CGFloat.greatestFiniteMagnitude)
        t.textContainer?.widthTracksTextView = true
        t.isEditable = false
        s.documentView = t
        return s
    }

    func button(_ t: String, _ f: NSRect, _ a: Selector) -> NSButton {
        let b = NSButton(title: t, target: self, action: a)
        b.frame = f
        b.bezelStyle = .rounded
        b.autoresizingMask = [.maxYMargin]
        return b
    }

    override init() {
        super.init()
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.title = L(.learnWindow)
        let cv = window.contentView!

        tv.isSelectable = true
        tv.textContainerInset = NSSize(width: 12, height: 10)
        tv.onClick = { [weak self] word, line in self?.clicked(word: word, line: line) }
        tv.onDoubleClick = { [weak self] loc in self?.jump(toParagraphAt: loc) }
        tv.onParagraph = { [weak self] loc in
            guard let s = self else { return }
            s.selectedIdx = s.ranges.firstIndex(where: { $0.location == loc })
        }
        cv.addSubview(scroll(tv, NSRect(x: 0, y: 216, width: 520, height: 384), [.width, .height]))

        result.isSelectable = true
        result.font = .systemFont(ofSize: 13)
        result.textContainerInset = NSSize(width: 10, height: 8)
        result.string = L(.learnHint)
        cv.addSubview(scroll(result, NSRect(x: 0, y: 52, width: 520, height: 124), [.width, .maxYMargin]))

        loopABtn = button(L(.loopSetA), NSRect(x: 10, y: 184, width: 78, height: 26), #selector(setLoopA))
        loopBBtn = button(L(.loopSetB), NSRect(x: 92, y: 184, width: 78, height: 26), #selector(setLoopB))
        loopClearBtn = button(L(.loopClear), NSRect(x: 174, y: 184, width: 64, height: 26), #selector(clearLoopAction))
        quizBtn = button(L(.quizButton), NSRect(x: 440, y: 184, width: 70, height: 26), #selector(openQuizAction))
        quizBtn.autoresizingMask = [.maxYMargin, .minXMargin]
        for b in [loopABtn!, loopBBtn!, loopClearBtn!, quizBtn!] {
            b.controlSize = .small
            b.font = .systemFont(ofSize: 11)
            cv.addSubview(b)
        }
        loopLabel = NSTextField(labelWithString: "")
        loopLabel.frame = NSRect(x: 246, y: 189, width: 188, height: 16)
        loopLabel.font = .systemFont(ofSize: 11)
        loopLabel.textColor = .secondaryLabelColor
        loopLabel.lineBreakMode = .byTruncatingTail
        loopLabel.autoresizingMask = [.maxYMargin]
        cv.addSubview(loopLabel)
        updateLoopUI()

        translateBtn = button(L(.btnTranslate), NSRect(x: 10, y: 12, width: 94, height: 30), #selector(translateLineAction))
        saveBtn = button(L(.btnSaveWord), NSRect(x: 108, y: 12, width: 86, height: 30), #selector(saveWord))
        exportBtn = button(L(.btnExportAnki), NSRect(x: 198, y: 12, width: 92, height: 30), #selector(exportAnki))
        speakBtn = button(L(.btnSpeak), NSRect(x: 294, y: 12, width: 72, height: 30), #selector(speakAction))
        for b in [translateBtn!, saveBtn!, exportBtn!, speakBtn!] {
            b.controlSize = .small
            b.font = .systemFont(ofSize: 11)
            cv.addSubview(b)
        }
        countLabel = NSTextField(labelWithString: "")
        countLabel.frame = NSRect(x: 374, y: 18, width: 138, height: 18)
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.autoresizingMask = [.maxYMargin]
        cv.addSubview(countLabel)
        updateCount()
    }

    func show() {
        updateCount()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func updateCount() { countLabel.stringValue = L(.vocabCount, Vocab.load().count) }

    func relocalize() {
        loopABtn.title = L(.loopSetA)
        loopBBtn.title = L(.loopSetB)
        loopClearBtn.title = L(.loopClear)
        quizBtn.title = L(.quizButton)
        updateLoopUI()
        speakBtn.title = L(.btnSpeak)
        translateBtn.title = L(.btnTranslate)
        saveBtn.title = L(.btnSaveWord)
        exportBtn.title = L(.btnExportAnki)
        updateCount()
    }

    func setLyrics(_ texts: [String], title: String, translations: [String] = [], times: [Double] = []) {
        window.title = L(.learnWindowSong, title)
        self.times = times
        var s = ""
        ranges = []
        var trRanges: [NSRange] = []
        for (n, t) in texts.enumerated() {
            let line = t.isEmpty ? "♪" : t
            ranges.append(NSRange(location: (s as NSString).length, length: (line as NSString).length))
            s += line
            let tr = n < translations.count ? translations[n] : ""
            if !tr.isEmpty && line != "♪" {
                s += "\u{2028}"
                trRanges.append(NSRange(location: (s as NSString).length, length: (tr as NSString).length))
                s += tr
            }
            s += "\n"
        }
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 8
        let attr = NSMutableAttributedString(string: s, attributes: [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: para])
        for r in trRanges {
            attr.addAttributes([.font: NSFont.systemFont(ofSize: 13),
                                .foregroundColor: NSColor.tertiaryLabelColor], range: r)
        }
        tv.textStorage?.setAttributedString(attr)
        if texts.isEmpty { setEmpty(L(.lyricsNoneForSong)) }
        curIdx = -1
        lastWord = nil; lastMeaning = nil; lastLine = nil
    }

    func setEmpty(_ msg: String) {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.paragraphSpacingBefore = 160
        tv.textStorage?.setAttributedString(NSAttributedString(string: msg, attributes: [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: para]))
        ranges = []
        curIdx = -1
        lastWord = nil; lastMeaning = nil; lastLine = nil
        updateLoopUI()
    }

    static func fmt(_ t: Double) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }

    @objc func setLoopA() {
        guard let i = selectedIdx else { NSSound.beep(); return }
        loopA = i
        if let b = loopB, b < i { loopB = nil }
        loopChanged()
    }

    @objc func setLoopB() {
        guard let i = selectedIdx else { NSSound.beep(); return }
        if let a = loopA {
            if i < a { loopB = a; loopA = i } else { loopB = i }
        } else {
            loopA = i
            loopB = i
        }
        loopChanged()
    }

    @objc func clearLoopAction() {
        loopA = nil
        loopB = nil
        loopChanged()
    }

    @objc func openQuizAction() { onQuiz() }

    func clearLoopSilently() {
        loopA = nil
        loopB = nil
        selectedIdx = nil
        updateLoopUI()
    }

    func loopChanged() {
        updateLoopUI()
        if let a = loopA, let b = loopB { onLoop(a, b) } else { onLoop(nil, nil) }
    }

    func updateLoopUI() {
        guard loopLabel != nil else { return }
        func time(_ i: Int) -> String { i < times.count ? LearnPanel.fmt(times[i]) : "?" }
        if let a = loopA, let b = loopB {
            loopLabel.stringValue = L(.loopRange, time(a), time(b))
        } else if let a = loopA {
            loopLabel.stringValue = L(.loopPickB, time(a))
        } else {
            loopLabel.stringValue = L(.loopHint)
        }
        guard let ts = tv.textStorage, ts.length > 0 else { return }
        ts.beginEditing()
        ts.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: ts.length))
        if let a = loopA, let b = loopB, a < ranges.count, b < ranges.count {
            let start = ranges[a].location
            let end = ranges[b].location + ranges[b].length
            ts.addAttribute(.backgroundColor, value: NSColor.controlAccentColor.withAlphaComponent(0.22),
                            range: NSRange(location: start, length: max(0, end - start)))
        } else if let a = loopA, a < ranges.count {
            ts.addAttribute(.backgroundColor, value: NSColor.controlAccentColor.withAlphaComponent(0.22), range: ranges[a])
        }
        ts.endEditing()
    }

    func setCurrent(_ i: Int) {
        guard i != curIdx, let ts = tv.textStorage else { return }
        ts.beginEditing()
        if curIdx >= 0, curIdx < ranges.count {
            ts.addAttributes([.font: NSFont.systemFont(ofSize: 16),
                              .foregroundColor: NSColor.secondaryLabelColor], range: ranges[curIdx])
        }
        if i >= 0, i < ranges.count {
            ts.addAttributes([.font: NSFont.boldSystemFont(ofSize: 16),
                              .foregroundColor: NSColor.labelColor], range: ranges[i])
        }
        ts.endEditing()
        curIdx = i
        if i >= 0, i < ranges.count {
            currentLineText = (tv.string as NSString).substring(with: ranges[i])
            // don't auto-scroll right after a click, to avoid jumping
            if Date().timeIntervalSince(lastClick) > 8 { tv.scrollRangeToVisible(ranges[i]) }
        }
    }

    func show(_ s: String) { result.string = s }

    func jump(toParagraphAt loc: Int) {
        guard let i = ranges.firstIndex(where: { $0.location == loc }), i < times.count else { return }
        let t = times[i]
        onSeek(t)
        lastClick = Date()
        show(L(.jumpedTo, String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)))
    }

    func clicked(word: String?, line: String) {
        lastClick = Date()
        lastLine = line
        guard let w = word else {
            lastWord = nil; lastMeaning = nil
            show(L(.lineSelected))
            return
        }
        lastWord = w
        lastMeaning = nil
        show(L(.lookingUp, w))
        let src = langFor(line)
        Task {
            var parts: [String] = []
            var failure: String?
            do {
                let t = try await translator.translate(prep(w), from: src)
                if !t.isEmpty { parts.append("\(w) → \(t)") }
            } catch { failure = Translator.friendly(error) }
            if src == "en", let d = Dict.define(w) { parts.append(L(.dictEnglish) + "\n" + d) }
            let found = !parts.isEmpty
            var r = parts.joined(separator: "\n\n")
            if r.isEmpty {
                r = failure.map { L(.meaningNotFoundWith, $0) } ?? L(.meaningNotFound)
            } else if let f = failure {
                r += "\n\n" + L(.translationFailedNote, f)
            }
            let out = r
            DispatchQueue.main.async {
                if self.lastWord == w {
                    self.lastMeaning = found ? out : nil
                    self.show(out)
                }
            }
        }
    }

    @objc func translateLineAction() {
        let line = (lastLine?.isEmpty == false) ? lastLine! : currentLineText
        guard !line.isEmpty, line != "♪" else { NSSound.beep(); return }
        show(L(.translatingLine))
        let src = langFor(line)
        Task {
            var r: String
            do {
                let t = try await translator.translate(prep(line), from: src)
                r = t.isEmpty ? L(.lineNoNeed) : t
            } catch { r = L(.failedWith, Translator.friendly(error)) }
            let out = r
            DispatchQueue.main.async { self.show(out) }
        }
    }

    @objc func speakAction() {
        let line = (lastLine?.isEmpty == false) ? lastLine! : currentLineText
        let text = lastWord ?? line
        guard !text.isEmpty, text != "♪" else { NSSound.beep(); return }
        switch speaker.speak(prep(text), language: langFor(line)) {
        case .noVoice(let code): show(L(.noVoice, Lang.name(code)))
        case .empty: NSSound.beep()
        default: break
        }
    }

    @objc func saveWord() {
        guard let w = lastWord, let m = lastMeaning else {
            NSSound.beep()
            return
        }
        Vocab.add(VocabEntry(word: w, meaning: m, line: lastLine ?? "", song: song(), date: Date()))
        updateCount()
    }

    @objc func exportAnki() {
        guard let url = Vocab.exportAnki() else {
            show(L(.exportNone))
            return
        }
        show(L(.exportDone, url.lastPathComponent))
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
