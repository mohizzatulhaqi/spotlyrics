import Cocoa
import SwiftUI

@MainActor
final class MenuModel: ObservableObject {
    @Published var title = ""
    @Published var subtitle = ""
    @Published var status = ""
    @Published var kind = 0
    @Published var failing = false
    @Published var device = ""
    @Published var offsetText = "+0.00s"
    @Published var artwork: NSImage?
    @Published var accent: Color?
    @Published var scrub: Double?
    @Published var langTick = 0
    @Published var floatOn = false
    @Published var romajiOn = false
    @Published var romajiRelevant = false
    @Published var lyricsHidden = false
    @Published var position = 0.0
    @Published var duration = 0.0
    @Published var playing = false
    @Published var hasTrack = false
    @Published var isAd = false
    @Published var lyric = ""
    @Published var lyricTrans = ""
    @Published var mode = "orig" {
        didSet { if mode != oldValue { onMode(mode) } }
    }
    var onMode: (String) -> Void = { _ in }
    var onFaster: () -> Void = {}
    var onSlower: () -> Void = {}
    var onReset: () -> Void = {}
    var onLang: () -> Void = {}
    var onRetry: () -> Void = {}
    var onHeight: (CGFloat) -> Void = { _ in }
    var onPrev: () -> Void = {}
    var onToggle: () -> Void = {}
    var onNext: () -> Void = {}
    var onSeek: (Double) -> Void = { _ in }
    var onFloat: () -> Void = {}
    var onRomaji: () -> Void = {}
    var onHide: () -> Void = {}
    var onSettings: () -> Void = {}
}

struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct HeaderCard: View {
    @ObservedObject var m: MenuModel

    var color: Color {
        switch m.kind {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .gray
        }
    }

    func fmt(_ t: Double) -> String {
        let v = max(0, Int(t))
        return String(format: "%d:%02d", v / 60, v % 60)
    }

    var shown: Double { m.scrub ?? m.position }
    var fraction: Double { m.duration > 0 ? min(1, max(0, shown / m.duration)) : 0 }

    @ViewBuilder var backdrop: some View {
        ZStack {
            if let img = m.artwork {
                Image(nsImage: img).resizable().scaledToFill().blur(radius: 30)
                Color.black.opacity(0.5)
                (m.accent ?? .clear).opacity(0.2)
            } else {
                LinearGradient(colors: m.isAd
                               ? [Color(red: 0.7, green: 0.35, blue: 0.1), Color(red: 0.2, green: 0.1, blue: 0.1)]
                               : [Color(red: 0.1, green: 0.45, blue: 0.35), Color(red: 0.05, green: 0.15, blue: 0.2)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    func pill(_ k: String, _ t: String) -> some View {
        Button { m.mode = k } label: {
            Text(t).font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(m.mode == k ? (m.accent ?? .white).opacity(0.42) : Color.white.opacity(0.1), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    func iconButton(_ name: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 26)
                .background(on ? (m.accent ?? .white).opacity(0.42) : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        let _ = m.langTick
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Group {
                    if let img = m.artwork {
                        Image(nsImage: img).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Color.white.opacity(0.12)
                            Image(systemName: m.isAd ? "megaphone.fill" : "music.note")
                                .font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.title).font(.system(size: 15, weight: .bold)).foregroundStyle(.white).lineLimit(2)
                    if !m.subtitle.isEmpty {
                        Text(m.subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            if m.hasTrack || m.isAd {
                VStack(spacing: 4) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.25)).frame(height: 4)
                            Capsule().fill(m.accent ?? .white).frame(width: g.size.width * fraction, height: 4)
                            if m.scrub != nil {
                                Circle().fill(m.accent ?? .white)
                                    .frame(width: 12, height: 12)
                                    .offset(x: max(0, g.size.width * fraction - 6))
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                if !m.isAd { m.scrub = Seek.position(x: v.location.x, width: g.size.width, duration: m.duration) }
                            }
                            .onEnded { v in
                                guard !m.isAd else { return }
                                let t = Seek.position(x: v.location.x, width: g.size.width, duration: m.duration)
                                m.position = t
                                m.scrub = nil
                                m.onSeek(t)
                            })
                    }
                    .frame(height: 16)
                    HStack {
                        Text(fmt(shown))
                        Spacer()
                        Text("-" + fmt(m.duration - shown))
                    }
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.65))
                }
                if !m.isAd {
                HStack(spacing: 30) {
                    Spacer()
                    Button { m.onPrev() } label: { Image(systemName: "backward.fill").font(.system(size: 17)) }
                    Button { m.onToggle() } label: {
                        Image(systemName: m.playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(m.accent ?? .white))
                    }
                    Button { m.onNext() } label: { Image(systemName: "forward.fill").font(.system(size: 17)) }
                    Spacer()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 3) {
                    Text(m.lyric).font(.system(size: 15, weight: .bold)).foregroundStyle(.white).lineLimit(2)
                    if !m.lyricTrans.isEmpty {
                        Text(m.lyricTrans).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7)).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 62, maxHeight: 62, alignment: .topLeading)
                .padding(10)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke((m.accent ?? .clear).opacity(0.5), lineWidth: 1))
                }
            }
            HStack(alignment: .top, spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7).padding(.top, 4)
                Text(m.status).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            if m.failing {
                HStack(spacing: 8) {
                    Button(L(.downloadLanguage)) { m.onLang() }
                    Button(L(.tryAgain)) { m.onRetry() }
                }
                .controlSize(.small)
            }
            if !m.isAd {
                HStack(spacing: 6) {
                    pill("orig", L(.pillOriginal))
                    pill("trans", L(.pillTranslation))
                    pill("both", L(.pillBoth))
                }
            }
            HStack(spacing: 8) {
                iconButton("captions.bubble", on: m.floatOn) { m.onFloat() }
                if m.romajiRelevant { iconButton("textformat.abc", on: m.romajiOn) { m.onRomaji() } }
                iconButton(m.lyricsHidden ? "eye.slash" : "eye", on: m.lyricsHidden) { m.onHide() }
                Spacer()
                iconButton("gearshape", on: false) { m.onSettings() }
            }
        }
        .padding(14)
        .frame(width: 284, alignment: .topLeading)
        .background { backdrop }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(8)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { g in Color.clear.preference(key: HeightKey.self, value: g.size.height) })
        .onPreferenceChange(HeightKey.self) { m.onHeight($0) }
    }
}

struct OffsetRow: View {
    @ObservedObject var m: MenuModel

    func round(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "headphones").foregroundStyle(.secondary)
            Text(m.device).font(.system(size: 12)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            round("minus") { m.onSlower() }
            Text(m.offsetText).font(.system(size: 11, design: .monospaced)).frame(width: 52)
            round("plus") { m.onFaster() }
            if m.offsetText != "+0.00s" { round("arrow.counterclockwise") { m.onReset() } }
        }
        .padding(.horizontal, 16)
        .frame(width: 300, height: 34)
    }
}
