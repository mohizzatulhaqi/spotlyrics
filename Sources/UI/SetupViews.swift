import Cocoa
import SwiftUI

@MainActor
final class SetupModel: ObservableObject {
    @Published var spotifyRunning = false
    @Published var automation: AutomationState = .appNotRunning
    @Published var target = Prefs.target {
        didSet { if !syncing { Prefs.target = target; onTarget() } }
    }
    @Published var login = false {
        didSet { if !syncing { onLogin(login) } }
    }
    @Published var loginAvailable = true
    @Published var langTick = 0
    private var syncing = false
    var onOpenSpotify: () -> Void = {}
    var onAllow: () -> Void = {}
    var onOpenSystemSettings: () -> Void = {}
    var onOpenTranslation: () -> Void = {}
    var onDone: () -> Void = {}
    var onTarget: () -> Void = {}
    var onLogin: (Bool) -> Void = { _ in }

    func sync(spotify: Bool, automation a: AutomationState, login l: Bool, loginAvailable av: Bool) {
        syncing = true
        spotifyRunning = spotify
        automation = a
        login = l
        loginAvailable = av
        target = Prefs.target
        syncing = false
    }

    var completed: Int {
        Setup.completed(spotifyRunning: spotifyRunning, automation: automation, targetChosen: true)
    }
}

struct SetupRow<Trailing: View>: View {
    let ok: Bool
    let title: String
    let detail: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(ok ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

struct SetupView: View {
    @ObservedObject var m: SetupModel

    var autoDetail: String {
        switch m.automation {
        case .granted: return L(.setupAutoGranted)
        case .denied: return L(.setupAutoDenied)
        case .notAsked: return L(.setupAutoAsk)
        case .appNotRunning, .unknown: return L(.setupAutoWait)
        }
    }

    var body: some View {
        let _ = m.langTick
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L(.setupTitle)).font(.title2.bold())
                Text(L(.setupSubtitle)).foregroundStyle(.secondary)
            }
            Divider()
            SetupRow(ok: m.spotifyRunning, title: L(.setupSpotify),
                     detail: m.spotifyRunning ? L(.setupSpotifyOk) : L(.setupSpotifyNo)) {
                if !m.spotifyRunning { Button(L(.setupOpenSpotify)) { m.onOpenSpotify() } }
            }
            SetupRow(ok: m.automation == .granted, title: L(.setupAutomation), detail: autoDetail) {
                switch m.automation {
                case .notAsked: Button(L(.setupAllow)) { m.onAllow() }
                case .denied: Button(L(.openSystemSettings)) { m.onOpenSystemSettings() }
                default: EmptyView()
                }
            }
            SetupRow(ok: true, title: L(.setupTarget), detail: Lang.name(m.target)) {
                Picker("", selection: $m.target) {
                    ForEach(Prefs.supportedTargets.map { (id: $0, name: Lang.name($0)) }
                        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }, id: \.id) {
                        Text($0.name).tag($0.id)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }
            SetupRow(ok: true, title: L(.setupPacks), detail: L(.setupPacksNote)) {
                Button(L(.setupOpenTranslation)) { m.onOpenTranslation() }
            }
            SetupRow(ok: true, title: L(.setupLogin), detail: "") {
                Toggle("", isOn: $m.login).labelsHidden().disabled(!m.loginAvailable)
            }
            Spacer(minLength: 0)
            HStack {
                if m.completed == Setup.total {
                    Label(L(.setupAllSet), systemImage: "party.popper.fill").foregroundStyle(.green)
                } else {
                    Text("\(m.completed)/\(Setup.total)").foregroundStyle(.secondary)
                }
                Spacer()
                Button(L(.setupDone)) { m.onDone() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
