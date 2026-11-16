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
    @Published var appLang = Prefs.appLanguage {
        didSet { if !syncing { Prefs.appLanguage = appLang; langTick += 1; onLanguage() } }
    }
    @Published var langTick = 0
    @Published var loginAvailable = true
    @Published var loginNote = ""
    @Published var hotKeyLines: [String] = []
    private var syncing = false
    var onTab: (String) -> Void = { _ in }
    var onLanguage: () -> Void = {}
    var onCasual: () -> Void = {}
    var onRomaji: () -> Void = {}
    var onAccent: () -> Void = {}
    var onFloat: (Bool) -> Void = { _ in }
    var onLogin: (Bool) -> Void = { _ in }
    var onHotKeys: (Bool) -> Void = { _ in }

    nonisolated static func height(for tab: String) -> CGFloat {
        switch tab {
        case "terjemahan": return 720
        case "pintasan": return 370
        case "tampilan": return 300
        default: return 300
        }
    }

    func sync(floatOn f: Bool, login l: Bool, loginAvailable a: Bool, loginNote n: String, hotKeysOn h: Bool, hotKeyLines lines: [String]) {
        syncing = true
        appLang = Prefs.appLanguage
        casual = Prefs.casual
        romaji = Prefs.showRomaji
        accent = Prefs.coverAccent
        floatOn = f
        login = l
        loginAvailable = a
        loginNote = n
        hotKeysOn = h
        hotKeyLines = lines
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
                ForEach(s.hotKeyLines, id: \.self) { l in
                    Text(l).font(.system(size: 12, design: .monospaced))
                }
            }
        }
        .formStyle(.grouped)
    }
}
