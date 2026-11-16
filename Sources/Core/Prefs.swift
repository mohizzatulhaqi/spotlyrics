import Foundation

// MARK: - Language preferences

enum Prefs {
    static let supportedTargets = ["ar", "de", "en", "es", "fr", "hi", "id", "it", "ja", "ko", "nl", "pl", "pt", "ru", "th", "tr", "uk", "vi", "zh"]

    static func defaultTarget(appLanguage: String, preferred: [String]) -> String {
        if appLanguage == "id" || appLanguage == "en" { return appLanguage }
        for p in preferred {
            let lang = Locale.Language(identifier: p)
            guard let code = lang.languageCode?.identifier else { continue }
            if code == "zh" {
                let trad = lang.script?.identifier == "Hant" || p.contains("TW") || p.contains("HK")
                return trad ? "zh-TW" : "zh"
            }
            if supportedTargets.contains(code) { return code }
        }
        return "en"
    }

    static var hasChosenTarget: Bool { UserDefaults.standard.string(forKey: "targetLang") != nil }

    static var target: String {
        get {
            UserDefaults.standard.string(forKey: "targetLang")
                ?? defaultTarget(appLanguage: appLanguage, preferred: Locale.preferredLanguages)
        }
        set { UserDefaults.standard.set(newValue, forKey: "targetLang") }
    }
    static var sourceMode: String {
        get { UserDefaults.standard.string(forKey: "sourceMode") ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: "sourceMode") }
    }
    static var fixedSource: String {
        get { UserDefaults.standard.string(forKey: "fixedSource") ?? "en" }
        set { UserDefaults.standard.set(newValue, forKey: "fixedSource") }
    }
    static var candidates: [String] {
        get { UserDefaults.standard.stringArray(forKey: "candidateLangs") ?? ["en", "ko"] }
        set { UserDefaults.standard.set(newValue, forKey: "candidateLangs") }
    }
    static func songOverride(_ key: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: "songLang") as? [String: String])?[key]
    }
    static func setSongOverride(_ key: String, _ lang: String?) {
        var d = (UserDefaults.standard.dictionary(forKey: "songLang") as? [String: String]) ?? [:]
        d[key] = lang
        UserDefaults.standard.set(d, forKey: "songLang")
    }
    static var showRomaji: Bool {
        get { UserDefaults.standard.object(forKey: "showRomaji") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showRomaji") }
    }
    static var casual: Bool {
        get { UserDefaults.standard.object(forKey: "casual") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "casual") }
    }
    static var appLanguage: String {
        get { UserDefaults.standard.string(forKey: "appLanguage") ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: "appLanguage"); L10n.refresh() }
    }
    static func isRomanizedDismissed(_ key: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: "romDismissed") ?? []).contains(key)
    }
    static func dismissRomanized(_ key: String) {
        var a = UserDefaults.standard.stringArray(forKey: "romDismissed") ?? []
        if !a.contains(key) { a.append(key) }
        UserDefaults.standard.set(Array(a.suffix(500)), forKey: "romDismissed")
    }
    static var coverAccent: Bool {
        get { UserDefaults.standard.object(forKey: "coverAccent") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "coverAccent") }
    }
    static var signature: String {
        switch sourceMode {
        case "fixed": return "f-" + fixedSource
        case "limited": return "l-" + candidates.sorted().joined(separator: "-")
        default: return "auto"
        }
    }
}

enum Lang {
    static func name(_ id: String) -> String {
        if id == "ja-rom" { return L(.langJaRom) }
        if id == "ko-rom" { return L(.langKoRom) }
        return L10n.locale.localizedString(forIdentifier: id) ?? id
    }

    static func same(_ a: String, _ b: String) -> Bool {
        Locale.Language(identifier: a).minimalIdentifier == Locale.Language(identifier: b).minimalIdentifier
    }
}
