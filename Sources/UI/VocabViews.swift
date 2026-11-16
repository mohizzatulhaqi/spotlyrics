import Cocoa
import SwiftUI

@MainActor
final class VocabModel: ObservableObject {
    @Published var all: [VocabEntry] = []
    @Published var query = ""
    @Published var song = ""
    @Published var selection = Set<String>()
    @Published var status = ""
    @Published var busy = false
    @Published var langTick = 0
    @Published var reverse = Prefs.ankiReverse {
        didSet { Prefs.ankiReverse = reverse }
    }
    var onSpeak: (VocabEntry) -> Void = { _ in }
    var onChanged: () -> Void = {}
    private var saveWork: DispatchWorkItem?

    func reload() {
        all = Vocab.load().sorted { $0.date > $1.date }
        selection = selection.filter { id in all.contains { $0.id == id } }
        if !song.isEmpty && !all.contains(where: { $0.song == song }) { song = "" }
    }

    var visible: [VocabEntry] { Vocab.filter(all, query: query, song: song) }
    var songs: [String] { Vocab.songs(all) }
    var stats: (total: Int, today: Int, week: Int) { Vocab.stats(all) }

    var selected: VocabEntry? {
        guard selection.count == 1, let id = selection.first else { return nil }
        return all.first { $0.id == id }
    }

    func updateMeaning(_ text: String) {
        guard let id = selection.first, selection.count == 1, let i = all.firstIndex(where: { $0.id == id }) else { return }
        all[i].meaning = text
        saveWork?.cancel()
        let work = DispatchWorkItem { Vocab.setMeaning(id: id, text) }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func deleteSelected() {
        saveWork?.perform()
        Vocab.remove(ids: selection)
        selection = []
        reload()
        onChanged()
    }

    func export(_ kind: VocabExportKind) {
        guard !busy else { return }
        busy = true
        status = ""
        let entries = visible
        Task {
            let r = await VocabExportRunner.run(kind, entries: entries) { msg in
                Task { @MainActor in self.status = msg }
            }
            self.status = r.message
            self.busy = false
            if let u = r.url { NSWorkspace.shared.activateFileViewerSelecting([u]) }
        }
    }
}

struct VocabView: View {
    @ObservedObject var m: VocabModel
    @State private var confirm = false

    var detail: some View {
        Group {
            if let e = m.selected {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(e.word).font(.system(size: 22, weight: .bold))
                        if let r = e.reading, !r.isEmpty { Text(r).foregroundStyle(.secondary) }
                        Spacer()
                        Button(L(.btnSpeak)) { m.onSpeak(e) }
                    }
                    Text(L(.vocabMeaningLabel)).font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: Binding(get: { m.selected?.meaning ?? "" }, set: { m.updateMeaning($0) }))
                        .font(.system(size: 13))
                        .frame(height: 64)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15)))
                    if !e.line.isEmpty {
                        Text(L(.vocabLineLabel)).font(.caption).foregroundStyle(.secondary)
                        Text(e.line).italic()
                        if let lr = e.lineReading, !lr.isEmpty { Text(lr).font(.caption).foregroundStyle(.secondary) }
                        if let lt = e.lineTranslation, !lt.isEmpty { Text(lt).font(.callout).foregroundStyle(.green) }
                    }
                    Text(e.song).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text(L(.vocabPickOne)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
    }

    var body: some View {
        let _ = m.langTick
        let s = m.stats
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField(L(.vocabSearch), text: $m.query).textFieldStyle(.roundedBorder)
                Picker("", selection: $m.song) {
                    Text(L(.vocabAllSongs)).tag("")
                    ForEach(m.songs, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 240)
            }
            .padding(12)
            Divider()
            if m.all.isEmpty {
                Text(L(.vocabEmpty)).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if m.visible.isEmpty {
                Text(L(.vocabNoMatch)).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(m.visible, selection: $m.selection) {
                    TableColumn(L(.colWord), value: \.word)
                    TableColumn(L(.colMeaning), value: \.meaning)
                    TableColumn(L(.colSong), value: \.song)
                    TableColumn(L(.colAdded)) { e in Text(e.date, style: .date) }
                }
                .frame(minHeight: 160)
                Divider()
                detail
            }
            Divider()
            HStack(spacing: 12) {
                Text(L(.vocabStats, s.total, s.today, s.week)).font(.caption).foregroundStyle(.secondary)
                Toggle(L(.vocabReverse), isOn: $m.reverse).toggleStyle(.checkbox).font(.caption)
                Spacer()
                if m.busy { ProgressView().controlSize(.small) }
                Menu(m.visible.count == 1 ? L(.vocabExportOne) : L(.vocabExportN, m.visible.count)) {
                    Button(L(.exportApkgItem)) { m.export(.apkg) }
                    Button(L(.exportTsvItem)) { m.export(.tsv) }
                    Button(L(.exportCsvItem)) { m.export(.csv) }
                }
                .fixedSize()
                .disabled(m.visible.isEmpty || m.busy)
                Button(L(.vocabDelete), role: .destructive) { confirm = true }
                    .disabled(m.selection.isEmpty)
            }
            .padding(12)
            if !m.status.isEmpty {
                Text(m.status).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.bottom, 10)
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .confirmationDialog(m.selection.count == 1 ? L(.vocabDeleteOne) : L(.vocabDeleteAsk, m.selection.count), isPresented: $confirm) {
            Button(L(.vocabDelete), role: .destructive) { m.deleteSelected() }
        } message: {
            Text(L(.vocabDeleteNote))
        }
    }
}
