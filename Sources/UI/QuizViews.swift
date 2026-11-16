import Cocoa
import SwiftUI

@MainActor
final class QuizModel: ObservableObject {
    @Published var item: ClozeItem?
    @Published var translation = ""
    @Published var input = ""
    @Published var status = 0
    @Published var correct = 0
    @Published var total = 0
    @Published var empty = false
    @Published var langTick = 0
    var onPlay: (Int) -> Void = { _ in }
    var onSpeak: (Int) -> Void = { _ in }
    private var lines: [String] = []
    private var translations: [String] = []
    private var counted = false
    private var seen = Set<Int>()

    func load(lines: [String], translations: [String]) {
        self.lines = lines
        self.translations = translations
        seen = []
        correct = 0
        total = 0
        empty = Cloze.eligible(lines: lines).isEmpty
        next(count: false)
    }

    private func finishCurrent() {
        if !counted, item != nil {
            counted = true
            total += 1
        }
    }

    func next(count: Bool = true) {
        if count { finishCurrent() }
        var pool = Cloze.eligible(lines: lines).filter { !seen.contains($0) }
        if pool.isEmpty {
            seen = []
            pool = Cloze.eligible(lines: lines)
        }
        guard let i = pool.randomElement() else {
            item = nil
            return
        }
        seen.insert(i)
        item = Cloze.make(line: lines[i], lineIndex: i, pick: { Int.random(in: 0..<$0) })
        translation = i < translations.count ? translations[i] : ""
        input = ""
        status = 0
        counted = false
    }

    func check() {
        guard let it = item, status != 1, status != 3 else { return }
        if Cloze.matches(answer: it.answer, input: input) {
            status = 1
            if !counted {
                counted = true
                total += 1
                correct += 1
            }
        } else {
            status = 2
        }
    }

    func reveal() {
        guard item != nil else { return }
        finishCurrent()
        status = 3
    }
}

struct QuizView: View {
    @ObservedObject var m: QuizModel

    var message: (String, Color)? {
        guard let it = m.item else { return nil }
        switch m.status {
        case 1: return (L(.quizCorrect), .green)
        case 2: return (L(.quizWrong), .orange)
        case 3: return (L(.quizAnswerIs, it.answer), .secondary)
        default: return nil
        }
    }

    var body: some View {
        let _ = m.langTick
        return VStack(alignment: .leading, spacing: 14) {
            Text(L(.quizTitle)).font(.headline)
            if m.empty || m.item == nil {
                Text(L(.quizEmpty)).foregroundStyle(.secondary)
                Spacer()
            } else if let it = m.item {
                Text(it.prompt)
                    .font(.system(size: 22, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if !m.translation.isEmpty {
                    Text(m.translation).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                TextField(L(.quizPlaceholder), text: $m.input)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { m.check() }
                    .disabled(m.status == 1 || m.status == 3)
                HStack {
                    Button(L(.quizCheck)) { m.check() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(m.status == 1 || m.status == 3)
                    Button(L(.quizShow)) { m.reveal() }.disabled(m.status == 1 || m.status == 3)
                    Button(L(.quizPlay)) { m.onPlay(it.lineIndex) }
                    Button(L(.quizSpeak)) { m.onSpeak(it.lineIndex) }
                    Spacer()
                    Button(L(.quizNext)) { m.next() }
                }
                if let (text, color) = message {
                    Text(text).foregroundStyle(color).font(.system(size: 14, weight: .medium))
                }
                Spacer(minLength: 0)
                Text(L(.quizScore, m.correct, m.total)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 300)
    }
}
