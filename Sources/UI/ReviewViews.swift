import Cocoa
import SwiftUI

@MainActor
final class ReviewModel: ObservableObject {
    @Published var current: VocabEntry?
    @Published var revealed = false
    @Published var left = 0
    @Published var reviewed = 0
    @Published var hasAny = false
    @Published var langTick = 0
    @Published var song = "" { didSet { if song != oldValue { start() } } }
    @Published var newCount = Prefs.reviewNewPerSession {
        didSet { if newCount != oldValue { Prefs.reviewNewPerSession = newCount; start() } }
    }
    @Published var reverse = Prefs.reviewReverse {
        didSet { if reverse != oldValue { Prefs.reviewReverse = reverse; resetCard() } }
    }
    @Published var songs: [String] = []
    @Published var summary = ReviewLog.Summary(today: 0, week: 0, accuracy: nil, streak: 0, known: 0)
    var onSpeak: (VocabEntry) -> Void = { _ in }
    var onChanged: () -> Void = {}
    private var queue: [String] = []
    private var entries: [String: VocabEntry] = [:]
    private var cycle = 0

    func start() {
        let everything = Vocab.load()
        songs = Vocab.songs(everything)
        if !song.isEmpty && !songs.contains(song) { song = "" }
        let all = song.isEmpty ? everything : everything.filter { $0.song == song }
        hasAny = !everything.isEmpty
        entries = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        queue = SRS.queue(all, now: Date(), newLimit: newCount)
        reviewed = 0
        cycle = 0
        refreshSummary(everything)
        advance()
    }

    private func advance() {
        revealed = false
        while let id = queue.first {
            if let e = entries[id] {
                current = e
                left = queue.count
                return
            }
            queue.removeFirst()
        }
        current = nil
        left = 0
    }

    func intervalLabel(_ r: Rating) -> String {
        guard let e = current else { return "" }
        return SRS.intervalLabel(SRS.state(of: e), rating: r, now: Date())
    }

    func rate(_ r: Rating) {
        guard revealed, var e = current else { return }
        let now = Date()
        let next = SRS.review(SRS.state(of: e), rating: r, now: now)
        SRS.apply(next, to: &e, now: now)
        Vocab.saveEntry(e)
        ReviewLog.record(r, at: now)
        refreshSummary()
        entries[e.id] = e
        queue.removeFirst()
        reviewed += 1
        if r == .again {
            queue.append(e.id)
        }
        advance()
        onChanged()
    }

    func refreshSummary(_ all: [VocabEntry]? = nil) {
        summary = ReviewLog.summary(log: ReviewLog.load(), entries: all ?? Vocab.load())
    }

    private func resetCard() { revealed = false }

    func reveal() {
        if current != nil { revealed = true }
    }
}

struct ReviewView: View {
    @ObservedObject var m: ReviewModel

    func ratingButton(_ r: Rating, _ title: String, _ key: String) -> some View {
        Button {
            m.rate(r)
        } label: {
            VStack(spacing: 2) {
                Text(title)
                Text(m.intervalLabel(r)).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(minWidth: 70)
        }
        .keyboardShortcut(KeyEquivalent(Character(key)), modifiers: [])
    }

    var statsLine: some View {
        let s = m.summary
        return Text(L(.reviewStats, s.today, s.week, s.accuracy.map { "\($0)%" } ?? "–", s.streak, s.known))
            .font(.caption).foregroundStyle(.secondary)
    }

    var body: some View {
        let _ = m.langTick
        return VStack(spacing: 16) {
            HStack(spacing: 14) {
                Picker("", selection: $m.song) {
                    Text(L(.vocabAllSongs)).tag("")
                    ForEach(m.songs, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
                Stepper(L(.reviewNewCount, m.newCount), value: $m.newCount, in: 0...50, step: 5)
                    .fixedSize()
                Toggle(L(.reviewReverseOpt), isOn: $m.reverse).toggleStyle(.checkbox)
                Spacer()
            }
            .font(.caption)
            if !m.hasAny {
                Text(L(.reviewNone)).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let e = m.current {
                Text(L(.reviewLeft, m.left)).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    if m.reverse && !m.revealed {
                        Text(e.meaning).font(.system(size: 28, weight: .bold)).multilineTextAlignment(.center)
                    } else {
                        Text(e.word).font(.system(size: 34, weight: .bold))
                        if let r = e.reading, !r.isEmpty { Text(r).font(.title3).foregroundStyle(.secondary) }
                    }
                    Button { m.onSpeak(e) } label: { Image(systemName: "speaker.wave.2") }.buttonStyle(.borderless)
                }
                if m.revealed {
                    VStack(spacing: 8) {
                        if !m.reverse { Text(e.meaning).font(.title2).multilineTextAlignment(.center) }
                        if !e.line.isEmpty {
                            Text(e.line).italic().multilineTextAlignment(.center)
                            if let t = e.lineTranslation, !t.isEmpty { Text(t).foregroundStyle(.green).multilineTextAlignment(.center) }
                        }
                        Text(e.song).font(.caption).foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                } else if !e.line.isEmpty && !m.reverse {
                    Text(e.line).italic().foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if m.revealed {
                    HStack(spacing: 10) {
                        ratingButton(.again, L(.reviewAgain), "1")
                        ratingButton(.hard, L(.reviewHard), "2")
                        ratingButton(.good, L(.reviewGood), "3")
                        ratingButton(.easy, L(.reviewEasy), "4")
                    }
                } else {
                    Button(L(.reviewShow)) { m.reveal() }
                        .keyboardShortcut(.space, modifiers: [])
                        .controlSize(.large)
                }
                Text(L(.reviewHint)).font(.caption).foregroundStyle(.secondary)
                statsLine
            } else {
                Image(systemName: "checkmark.circle").font(.system(size: 40)).foregroundStyle(.green)
                Text(L(.reviewDone)).multilineTextAlignment(.center)
                statsLine
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 360)
    }
}
