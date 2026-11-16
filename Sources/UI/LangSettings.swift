import Cocoa
import SwiftUI
import Translation

// MARK: - Language settings window (SwiftUI)

struct LangRow: Identifiable {
    let id: String
    let name: String
}

@MainActor
final class LangModel: ObservableObject {
    @Published var languages: [LangRow] = []
    @Published var status: [String: LanguageAvailability.Status] = [:]
    @Published var config: TranslationSession.Configuration?
    @Published var downloading: String?
    @Published var langTick = 0
    @Published var downloadStart: Date?
    @Published var failed: [String: String] = [:]
    @Published var query = ""
    @Published var mode: String = Prefs.sourceMode {
        didSet { Prefs.sourceMode = mode; onChange() }
    }
    @Published var fixed: String = Prefs.fixedSource {
        didSet { Prefs.fixedSource = fixed; onChange() }
    }
    @Published var candidates: Set<String> = Set(Prefs.candidates) {
        didSet { Prefs.candidates = candidates.sorted(); onChange() }
    }
    @Published var target: String = Prefs.target {
        didSet { Prefs.target = target; failed = [:]; onChange(); Task { await refresh() } }
    }
    var onChange: () -> Void = {}
    let availability = LanguageAvailability()
    private var queue: [String] = []
    private var token = 0

    func load() async {
        let sup = await availability.supportedLanguages
        var seen = Set<String>()
        var rows: [LangRow] = []
        for l in sup.sorted(by: { $0.minimalIdentifier.count < $1.minimalIdentifier.count }) {
            let id = l.minimalIdentifier
            let base = l.languageCode?.identifier ?? id
            let key = base == "zh" ? id : base
            if seen.insert(key).inserted { rows.append(LangRow(id: id, name: Lang.name(id))) }
        }
        languages = rows.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        await refresh()
    }

    func refresh() async {
        let tgt = Locale.Language(identifier: target)
        var st: [String: LanguageAvailability.Status] = [:]
        for l in languages where !Lang.same(l.id, target) {
            st[l.id] = await availability.status(from: Locale.Language(identifier: l.id), to: tgt)
        }
        status = st
    }

    func installed(_ id: String) -> Bool { status[id] == .installed }

    var visible: [LangRow] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let base = q.isEmpty ? languages : languages.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.id.localizedCaseInsensitiveContains(q)
        }
        return base.sorted {
            let a = installed($0.id), b = installed($1.id)
            if a != b { return a }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    var missingChecked: [String] {
        candidates.filter { !Lang.same($0, target) && status[$0] == .supported }.sorted()
    }

    func download(_ id: String) {
        guard downloading == nil else { return }
        failed[id] = nil
        token += 1
        downloading = id
        downloadStart = Date()
        config = TranslationSession.Configuration(source: Locale.Language(identifier: id),
                                                  target: Locale.Language(identifier: target))
    }

    func downloadChecked() {
        queue = missingChecked
        next()
    }

    private func next() {
        guard downloading == nil, !queue.isEmpty else { return }
        download(queue.removeFirst())
    }

    func cancel() {
        queue = []
        token += 1
        if let id = downloading { failed[id] = L(.cancelled) }
        downloading = nil
        config = nil
        Task { await refresh() }
    }

    func started() -> Int { token }

    func finished(token t: Int, error: String?) async {
        guard t == token, let id = downloading else { return }
        downloading = nil
        config = nil
        if let e = error { failed[id] = e; queue = [] }
        await refresh()
        if status[id] != .installed && error == nil {
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await refresh()
                if status[id] == .installed { break }
            }
        }
        if status[id] != .installed && failed[id] == nil { failed[id] = L(.notInstalled) }
        if status[id] == .installed { onChange() }
        next()
    }
}

struct LangView: View {
    @ObservedObject var m: LangModel

    func toggle(_ id: String) -> Binding<Bool> {
        Binding(get: { m.candidates.contains(id) },
                set: { if $0 { m.candidates.insert(id) } else { m.candidates.remove(id) } })
    }

    @ViewBuilder func statusView(_ l: LangRow) -> some View {
        if Lang.same(l.id, m.target) {
            Text(L(.targetLanguage)).foregroundStyle(.secondary)
        } else if m.downloading == l.id {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    TimelineView(.periodic(from: .now, by: 1)) { c in
                        let sec = Int(c.date.timeIntervalSince(m.downloadStart ?? c.date))
                        Text(L(.downloadingTime, sec / 60, sec % 60)).monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                    Button(L(.cancel)) { m.cancel() }
                }
                Text(L(.noPercent)).font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            switch m.status[l.id] {
            case .some(.installed): Text(L(.installed)).foregroundStyle(.green)
            case .some(.supported):
                HStack(spacing: 8) {
                    if let f = m.failed[l.id] { Text(f).font(.caption).foregroundStyle(.orange) }
                    Button(m.failed[l.id] == nil ? L(.download) : L(.tryAgain)) { m.download(l.id) }
                        .disabled(m.downloading != nil)
                }
            case .some(.unsupported): Text(L(.unsupported)).foregroundStyle(.secondary)
            default: ProgressView().controlSize(.small)
            }
        }
    }

    var hint: String {
        switch m.mode {
        case "limited": return L(.hintLimited)
        case "fixed": return L(.hintFixed)
        default: return L(.hintAuto)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L(.translateTo))
                Picker("", selection: $m.target) {
                    ForEach(m.languages) { Text($0.name).tag($0.id) }
                }
                .labelsHidden()
                .frame(width: 220)
            }
            Picker(L(.lyricsLanguage), selection: $m.mode) {
                Text(L(.srcAuto)).tag("auto")
                Text(L(.srcLimited)).tag("limited")
                Text(L(.srcFixed)).tag("fixed")
            }
            .pickerStyle(.radioGroup)
            if m.mode == "fixed" {
                Picker(L(.lyricsLanguage), selection: $m.fixed) {
                    ForEach(m.languages) { Text($0.name).tag($0.id) }
                }
                .frame(width: 320)
            }
            Text(hint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField(L(.searchLanguage), text: $m.query).textFieldStyle(.roundedBorder)
                if m.mode == "limited" {
                    Button(L(.downloadChecked, m.missingChecked.count)) { m.downloadChecked() }
                        .disabled(m.missingChecked.isEmpty || m.downloading != nil)
                }
            }
            List(m.visible) { l in
                HStack {
                    if m.mode == "limited" { Toggle("", isOn: toggle(l.id)).labelsHidden() }
                    Text(l.name)
                    Spacer()
                    statusView(l)
                }
            }
            Text(L(.onDeviceNote))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(minWidth: 480, minHeight: 520)
        .translationTask(m.config) { session in
            let t = m.started()
            var err: String?
            do { try await session.prepareTranslation() }
            catch { err = Task.isCancelled ? nil : L(.failedWith, Translator.friendly(error)) }
            await m.finished(token: t, error: err)
        }
        .task { await m.load() }
    }
}
