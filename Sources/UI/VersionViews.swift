import Cocoa
import SwiftUI

@MainActor
final class VersionModel: ObservableObject {
    @Published var options: [LyricsOption] = []
    @Published var selection: Int?
    @Published var loading = false
    @Published var failed = false
    @Published var heading = ""
    @Published var langTick = 0
    var target = 0
    var currentLines: [Line] = []
    var onUse: (LyricsOption) -> Void = { _ in }
    var onAuto: () -> Void = {}

    func load(title: String, artist: String, duration: Int, current: [Line]) {
        heading = artist.isEmpty ? title : "\(artist) – \(title)"
        target = duration
        currentLines = current
        options = []
        selection = nil
        failed = false
        loading = true
        Task {
            var reached = false
            let found = await Lyrics.options(title: title, artist: artist, duration: duration, reached: &reached)
            self.options = found
            self.failed = !reached && found.isEmpty
            self.selection = found.first(where: { $0.matches(current: current) })?.id ?? found.first?.id
            self.loading = false
        }
    }

    var selected: LyricsOption? { options.first { $0.id == selection } }
}

struct VersionView: View {
    @ObservedObject var m: VersionModel

    func clock(_ t: Double) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }

    func detail(_ o: LyricsOption) -> String {
        var parts: [String] = []
        if !o.album.isEmpty { parts.append(o.album) }
        if let d = o.duration {
            var s = clock(d)
            if let diff = o.durationDiff(from: m.target), abs(diff) >= 1 { s += String(format: " (%+.0fs)", diff) }
            parts.append(s)
        }
        return parts.joined(separator: " · ")
    }

    func badge(_ text: String, _ color: Color) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    var body: some View {
        let _ = m.langTick
        return VStack(alignment: .leading, spacing: 12) {
            Text(L(.pickTitle)).font(.headline)
            Text(m.heading).foregroundStyle(.secondary)
            if m.loading {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(L(.pickLoading)).foregroundStyle(.secondary) }
            } else if m.options.isEmpty {
                Text(m.failed ? L(.pickOffline) : L(.pickNone)).foregroundStyle(.secondary)
            }
            List(m.options, selection: $m.selection) { o in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(o.artist) – \(o.track)").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 4)
                        if o.matches(current: m.currentLines) { badge(L(.pickInUse), .blue) }
                        badge(o.synced ? L(.pickSynced) : L(.pickPlain), o.synced ? .green : .orange)
                        if o.native { badge(L(.pickNative), .purple) }
                    }
                    Text(detail(o)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(.vertical, 2)
                .tag(o.id)
            }
            .frame(minHeight: 170)
            if let sel = m.selected {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L(.pickPreview)).font(.caption).foregroundStyle(.secondary)
                    Text(sel.preview).font(.system(size: 12)).lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            HStack {
                Button(L(.pickAuto)) { m.onAuto() }
                Spacer()
                Button(L(.pickUse)) { if let s = m.selected { m.onUse(s) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(m.selected == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 460)
    }
}
