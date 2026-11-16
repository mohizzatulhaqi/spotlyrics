import Cocoa
import SwiftUI

@MainActor
final class SettingsModel: ObservableObject {
    @Published var tab = "umum" {
        didSet { if tab != oldValue { onTab(tab) } }
    }
    @Published var casual = Prefs.casual {
        didSet { if !syncing { Prefs.casual = casual; onCasual() } }
    }
    @Published var romaji = Prefs.showRomaji {
        didSet { if !syncing { Prefs.showRomaji = romaji; onRomaji() } }
    }
    @Published var menuCover = Prefs.menuBarCover {
        didSet { if !syncing { Prefs.menuBarCover = menuCover; onMenuCover() } }
    }
    @Published var accent = Prefs.coverAccent {
        didSet { if !syncing { Prefs.coverAccent = accent; onAccent() } }
    }
    @Published var floatOn = false {
        didSet { if !syncing { onFloat(floatOn) } }
    }
    @Published var login = false {
        didSet { if !syncing { onLogin(login) } }
    }
    @Published var hotKeysOn = true {
        didSet { if !syncing { onHotKeys(hotKeysOn) } }
    }
    @Published var player = Prefs.playerChoice {
        didSet { if !syncing { Prefs.playerChoice = player; onPlayer() } }
    }
    @Published var appLang = Prefs.appLanguage {
        didSet { if !syncing { Prefs.appLanguage = appLang; langTick += 1; onLanguage() } }
    }
    @Published var langTick = 0
    @Published var diagCopied = false
    @Published var loginAvailable = true
    @Published var loginNote = ""
    @Published var shortcuts: [ShortcutRow] = []
    @Published var recordingId: Int?
    @Published var recordMessage = ""
    private var syncing = false
    var onTab: (String) -> Void = { _ in }
    var onPlayer: () -> Void = {}
    var onRecord: (Int) -> Void = { _ in }
    var onResetShortcut: (Int) -> Void = { _ in }
    var onResetAllShortcuts: () -> Void = {}
    var onOpenSetup: () -> Void = {}
    var onCopyDiagnostics: () -> Void = {}
    var onRevealData: () -> Void = {}
    let versionText: String = {
        let i = Bundle.main.infoDictionary
        guard let v = i?["CFBundleShortVersionString"] as? String else { return "dev" }
        return v + (((i?["CFBundleVersion"] as? String).map { " (\($0))" }) ?? "")
    }()

    func flashCopied() {
        diagCopied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.diagCopied = false
        }
    }
    var onLanguage: () -> Void = {}
    var onCasual: () -> Void = {}
    var onRomaji: () -> Void = {}
    var onAccent: () -> Void = {}
    var onMenuCover: () -> Void = {}
    var onFloat: (Bool) -> Void = { _ in }
    var onLogin: (Bool) -> Void = { _ in }
    var onHotKeys: (Bool) -> Void = { _ in }

    nonisolated static func height(for tab: String) -> CGFloat {
        switch tab {
        case "terjemahan": return 720
        case "pintasan": return 480
        case "tentang": return 340
        case "tampilan": return 300
        default: return 300
        }
    }

    func sync(floatOn f: Bool, login l: Bool, loginAvailable a: Bool, loginNote n: String, hotKeysOn h: Bool, shortcuts rows: [ShortcutRow]) {
        syncing = true
        appLang = Prefs.appLanguage
        player = Prefs.playerChoice
        casual = Prefs.casual
        romaji = Prefs.showRomaji
        accent = Prefs.coverAccent
        menuCover = Prefs.menuBarCover
        floatOn = f
        login = l
        loginAvailable = a
        loginNote = n
        hotKeysOn = h
        shortcuts = rows
        syncing = false
    }
}

struct SettingsView: View {
    @ObservedObject var s: SettingsModel
    @ObservedObject var lang: LangModel

    var body: some View {
        TabView(selection: $s.tab) {
            general.tabItem { Label(L(.tabGeneral), systemImage: "gearshape") }.tag("umum")
            translation.tabItem { Label(L(.tabTranslation), systemImage: "globe") }.tag("terjemahan")
            appearance.tabItem { Label(L(.tabAppearance), systemImage: "paintpalette") }.tag("tampilan")
            shortcuts.tabItem { Label(L(.tabShortcuts), systemImage: "keyboard") }.tag("pintasan")
            about.tabItem { Label(L(.tabAbout), systemImage: "info.circle") }.tag("tentang")
        }
        .id(s.langTick)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var general: some View {
        Form {
            Section {
                Picker(L(.appLanguage), selection: $s.appLang) {
                    Text(L(.appLangSystem)).tag("system")
                    Text("Indonesia").tag("id")
                    Text("English").tag("en")
                }
                Picker(L(.playerLabel), selection: $s.player) {
                    Text(L(.playerAuto)).tag("auto")
                    Text(L(.playerSpotify)).tag("spotify")
                    Text(L(.playerMusic)).tag("music")
                }
                Toggle(L(.loginToggle), isOn: $s.login).disabled(!s.loginAvailable)
                if !s.loginNote.isEmpty {
                    Text(s.loginNote).font(.caption).foregroundStyle(.secondary)
                }
                Toggle(L(.floatToggle), isOn: $s.floatOn)
            }
            Section {
                Text(L(.aboutText))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    var translation: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle(L(.casualToggle), isOn: $s.casual)
                    Text(L(.casualNote))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(height: 130)
            LangView(m: lang).id(lang.langTick)
        }
    }

    var appearance: some View {
        Form {
            Section {
                Toggle(L(.romajiToggle), isOn: $s.romaji)
                Text(L(.romajiNote))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(L(.accentToggle), isOn: $s.accent)
                Toggle(L(.menuBarCoverToggle), isOn: $s.menuCover)
            }
        }
        .formStyle(.grouped)
    }

    var about: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SpotLyrics").font(.headline)
                        Text(L(.aboutVersion, s.versionText)).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                HStack {
                    Button(L(.copyDiagnostics)) { s.onCopyDiagnostics() }
                    if s.diagCopied {
                        Label(L(.diagCopied), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                Text(L(.diagHint)).font(.caption).foregroundStyle(.secondary)
                Button(L(.revealData)) { s.onRevealData() }
                Button(L(.openSetup)) { s.onOpenSetup() }
                if let url = URL(string: "https://github.com/mohizzatulhaqi/spotlyrics/issues") {
                    Link(L(.reportIssue), destination: url)
                }
            }
        }
        .formStyle(.grouped)
    }

    var shortcuts: some View {
        Form {
            Section {
                Toggle(L(.hotkeysToggle), isOn: $s.hotKeysOn)
            }
            Section {
                ForEach(s.shortcuts) { row in
                    HStack(spacing: 8) {
                        Text(row.title)
                        Spacer()
                        if row.taken { Text(L(.hotkeyTaken)).font(.caption).foregroundStyle(.orange) }
                        Button(s.recordingId == row.id ? L(.pressKeys) : row.combo) { s.onRecord(row.id) }
                            .font(.system(size: 12, design: .monospaced))
                        if row.custom {
                            Button(L(.resetShortcut)) { s.onResetShortcut(row.id) }.controlSize(.small)
                        }
                    }
                }
                if !s.recordMessage.isEmpty {
                    Text(s.recordMessage).font(.caption).foregroundStyle(.red)
                }
                Text(L(.recordHint)).font(.caption).foregroundStyle(.secondary)
                Button(L(.resetAllShortcuts)) { s.onResetAllShortcuts() }
            }
        }
        .formStyle(.grouped)
    }
}
