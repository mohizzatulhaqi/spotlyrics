import Cocoa
import SwiftUI

@MainActor
final class LibraryModel: ObservableObject {
    @Published var all: [LibraryEntry] = []
    @Published var query = ""
    @Published var selection: String?
    @Published var translations: [String] = []
    @Published var words: [WordCount] = []
    @Published var status = ""
    @Published var busy = Set<String>()
    @Published var langTick = 0
    @Published var translating = false
    @Published var meanings: [String: String] = [:]
    var onChanged: () -> Void = {}
    var onQuiz: (LibraryEntry, [String]) -> Void = { _, _ in }
    var onSpeak: (String, String) -> Void = { _, _ in }
    var translator: Translator?
    private var recent = ""

    func reload(select key: String? = nil) {
        all = Store.library()
        if let key = key, let hit = all.first(where: { $0.transKey == key }) { selection = hit.id }
        if let s = selection, !all.contains(where: { $0.id == s }) { selection = nil }
        refreshDetail()
    }

    var visible: [LibraryEntry] { all.filter { $0.matches(query) } }
    var selected: LibraryEntry? { selection.flatMap { id in all.first { $0.id == id } } }

    func refreshDetail() {
        status = ""
        guard let e = selected else {
            translations = []
            words = []
            return
        }
        let target = Prefs.target
        let ov = Prefs.songOverride(e.transKey)
        let cacheKey = "\(ov.map { "o-" + $0 } ?? Prefs.signature)|\(target)|\(e.transKey)"
        if let c = Store.readTrans(cacheKey), c.count == e.lines.count {
            translations = Prefs.casual ? Casual.apply(c, target: target) : c
        } else {
            translations = []
        }
        let texts = e.lines.map { $0.text }
        let langs = Detect.perLine(texts, override: ov)
        let saved = Set(Vocab.load().map { $0.id })
        words = WordFreq.top(lines: texts, langs: langs, exclude: saved, limit: 24, minCount: 2)
    }

    func langs(for e: LibraryEntry) -> [String] {
        Detect.perLine(e.lines.map { $0.text }, override: Prefs.songOverride(e.transKey))
    }

    func lang(ofLine i: Int, in e: LibraryEntry) -> String {
        let l = langs(for: e)
        if i < l.count, !l[i].isEmpty { return l[i] }
        return l.first { !$0.isEmpty } ?? "en"
    }

    func translateSong() {
        guard let e = selected, let tr = translator, !translating else { return }
        translating = true
        status = L(.libTranslating)
        let target = Prefs.target
        let ov = Prefs.songOverride(e.transKey)
        let cacheKey = "\(ov.map { "o-" + $0 } ?? Prefs.signature)|\(target)|\(e.transKey)"
        let texts = e.lines.map { $0.text }
        let langs = self.langs(for: e)
        let id = e.id
        Task {
            let r = await tr.translateBatch(texts, langs: langs, target: target)
            self.translating = false
            if r.errors.isEmpty {
                Store.writeTrans(cacheKey, r.out)
                if self.selection == id { self.refreshDetail() }
            } else {
                self.status = L(.libTransFailed, r.errors.map { "\(Lang.name($0.key)): \($0.value)" }.sorted().joined(separator: "; "))
            }
        }
    }

    func wordsIn(_ text: String, lang: String) -> [String] {
        WordFreq.tokens(in: text, lang: lang).map { $0.display }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    }

    func loadMeanings(_ words: [String], lang: String) {
        guard let tr = translator else { return }
        for w in words where meanings[lang + "|" + w] == nil {
            meanings[lang + "|" + w] = ""
            Task {
                let r = (try? await tr.translate(w, from: lang)) ?? ""
                self.meanings[lang + "|" + w] = r
            }
        }
    }

    func saveWord(_ word: String, line: String, index: Int) {
        guard let e = selected else { return }
        save(WordCount(word: word, count: 1, sample: line.trimmingCharacters(in: .whitespacesAndNewlines), lang: lang(ofLine: index, in: e)))
    }

    func save(_ w: WordCount) {
        guard let e = selected, let tr = translator, !busy.contains(w.id) else { return }
        busy.insert(w.id)
        status = L(.libTranslating)
        Task {
            let meaning = (try? await tr.translate(w.word, from: w.lang)) ?? ""
            self.busy.remove(w.id)
            guard !meaning.isEmpty else {
                self.status = L(.libWordFailed)
                return
            }
            let style = Prefs.readingStyle
            let idx = e.lines.firstIndex { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == w.sample }
            let lineTr = idx.flatMap { $0 < self.translations.count ? self.translations[$0] : nil } ?? ""
            Vocab.add(VocabEntry(word: w.word, meaning: meaning, line: w.sample, song: e.name, date: Date(), lang: w.lang,
                                 reading: Readings.reading(w.word, lang: w.lang, style: style),
                                 lineReading: Readings.reading(w.sample, lang: w.lang, style: style),
                                 lineTranslation: lineTr))
            self.words.removeAll { $0.id == w.id }
            self.status = L(.libWordSaved, w.word)
            self.onChanged()
        }
    }

    func removeSelected() {
        guard let e = selected else { return }
        try? FileManager.default.removeItem(at: e.file)
        selection = nil
        reload()
    }
}

struct LibraryView: View {
    @ObservedObject var m: LibraryModel
    @State private var confirm = false

    var detail: some View {
        Group {
            if let e = m.selected {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.title).font(.title3.bold())
                            Text(e.artist + (e.album.isEmpty ? "" : " · " + e.album)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !e.synced { Text(L(.libUnsynced)).font(.caption).foregroundStyle(.orange) }
                        if m.translations.isEmpty {
                            Button(L(.libTranslate)) { m.translateSong() }.disabled(m.translating)
                        }
                        Button(L(.libQuiz)) { m.onQuiz(e, m.translations) }
                        Button(L(.libRemove), role: .destructive) { confirm = true }
                    }
                    Text(L(.libTopWords)).font(.caption).foregroundStyle(.secondary)
                    if m.words.isEmpty {
                        Text(L(.libNoWords)).font(.callout).foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(m.words) { w in
                                    Button { m.save(w) } label: {
                                        HStack(spacing: 4) {
                                            Text(w.word)
                                            Text(L(.libWordCount, w.count)).foregroundStyle(.secondary)
                                            Image(systemName: "plus.circle")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(m.busy.contains(w.id))
                                    .help(L(.libAddWord) + " · " + w.sample)
                                }
                            }
                        }
                    }
                    if !m.status.isEmpty { Text(m.status).font(.caption).foregroundStyle(.secondary) }
                    Divider()
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(e.lines.enumerated()), id: \.offset) { i, l in
                                LibraryLineRow(m: m, entry: e, index: i, text: l.text)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
            } else {
                Text(L(.libPick)).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    var body: some View {
        let _ = m.langTick
        return HSplitView {
            VStack(spacing: 0) {
                TextField(L(.libSearch), text: $m.query).textFieldStyle(.roundedBorder).padding(10)
                Divider()
                if m.all.isEmpty {
                    Text(L(.libEmpty)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding().frame(maxHeight: .infinity)
                } else if m.visible.isEmpty {
                    Text(L(.libNoMatch)).foregroundStyle(.secondary).frame(maxHeight: .infinity)
                } else {
                    List(m.visible, selection: $m.selection) { e in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.title).lineLimit(1)
                            Text(e.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .tag(e.id)
                    }
                }
                Divider()
                Text(L(.libCount, m.all.count)).font(.caption).foregroundStyle(.secondary).padding(8)
            }
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
            detail.frame(minWidth: 380)
        }
        .frame(minWidth: 700, minHeight: 480)
        .onChange(of: m.selection) { _, _ in m.refreshDetail() }
        .confirmationDialog(L(.libRemoveAsk), isPresented: $confirm) {
            Button(L(.libRemove), role: .destructive) { m.removeSelected() }
        } message: {
            Text(L(.libRemoveNote))
        }
    }
}

struct LibraryLineRow: View {
    @ObservedObject var m: LibraryModel
    let entry: LibraryEntry
    let index: Int
    let text: String
    @State private var open = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(text)
                if index < m.translations.count, !m.translations[index].isEmpty {
                    Text(m.translations[index]).font(.callout).foregroundStyle(.green)
                }
            }
            .textSelection(.enabled)
            Spacer(minLength: 0)
            Button { m.onSpeak(text, m.lang(ofLine: index, in: entry)) } label: { Image(systemName: "speaker.wave.2") }
                .buttonStyle(.borderless)
                .help(L(.libSpeakLine))
            Button { open = true } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.borderless)
                .help(L(.libLineWords))
                .onChange(of: open) { _, v in
                    if v { m.loadMeanings(m.wordsIn(text, lang: m.lang(ofLine: index, in: entry)), lang: m.lang(ofLine: index, in: entry)) }
                }
                .popover(isPresented: $open) {
                    let words = m.wordsIn(text, lang: m.lang(ofLine: index, in: entry))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L(.libLineWords)).font(.caption).foregroundStyle(.secondary)
                        if words.isEmpty {
                            Text(L(.libNoWords)).font(.callout)
                        } else {
                            let lang = m.lang(ofLine: index, in: entry)
                            ForEach(words, id: \.self) { w in
                                Button {
                                    m.saveWord(w, line: text, index: index)
                                } label: {
                                    HStack {
                                        Text(w)
                                        if let mean = m.meanings[lang + "|" + w], !mean.isEmpty {
                                            Text(mean).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 12)
                                        Image(systemName: "plus.circle")
                                    }
                                    .frame(minWidth: 220)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(12)
                }
        }
    }
}
