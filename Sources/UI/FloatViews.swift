import Cocoa
import SwiftUI

struct PlainLine: Identifiable, Equatable {
    let id: Int
    let text: String
    let rom: String
    let trans: String
}

@MainActor
final class FloatModel: ObservableObject {
    @Published var prev = ""
    @Published var cur = "♪"
    @Published var sub = ""
    @Published var rom = ""
    @Published var next = ""
    @Published var artwork: NSImage?
    @Published var accent: Color?
    @Published var plain: [PlainLine] = []
    var onClose: () -> Void = {}

    func set(prev: String, cur: String, sub: String, next: String, rom: String = "") {
        self.prev = prev; self.cur = cur; self.sub = sub; self.next = next; self.rom = rom
        plain = []
    }

    func setPlain(_ lines: [PlainLine]) {
        plain = lines
    }
}

struct FloatView: View {
    @ObservedObject var m: FloatModel
    @State private var hover = false

    @ViewBuilder var backdrop: some View {
        ZStack {
            if let img = m.artwork {
                Image(nsImage: img).resizable().scaledToFill().blur(radius: 40)
                Color.black.opacity(0.55)
                (m.accent ?? .clear).opacity(0.18)
            } else {
                LinearGradient(colors: [Color(red: 0.1, green: 0.3, blue: 0.4), Color(red: 0.05, green: 0.05, blue: 0.12)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    var plainView: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(m.plain) { l in
                    if l.text.isEmpty {
                        Spacer().frame(height: 10)
                    } else {
                        VStack(spacing: 2) {
                            Text(l.text).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            if !l.rom.isEmpty {
                                Text(l.rom).font(.system(size: 13).italic()).foregroundStyle(.white.opacity(0.6))
                            }
                            if !l.trans.isEmpty {
                                Text(l.trans).font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(m.accent ?? Color(red: 0.6, green: 0.95, blue: 0.8))
                            }
                        }
                        .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if !m.plain.isEmpty {
                plainView
            } else {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                Text(m.prev).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                Text(m.cur).font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.6)
                    .shadow(color: (m.accent ?? .black).opacity(0.55), radius: 9, y: 1)
                    .id(m.cur)
                    .transition(.opacity)
                if !m.rom.isEmpty {
                    Text(m.rom).font(.system(size: 15, weight: .regular).italic())
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                }
                if !m.sub.isEmpty {
                    Text(m.sub).font(.system(size: 17, weight: .medium))
                        .foregroundStyle(m.accent ?? Color(red: 0.6, green: 0.95, blue: 0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                }
                Text(m.next).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button { m.onClose() } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(10)
            .opacity(hover ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { backdrop }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .animation(.easeInOut(duration: 0.25), value: m.cur)
        .onHover { hover = $0 }
    }
}
