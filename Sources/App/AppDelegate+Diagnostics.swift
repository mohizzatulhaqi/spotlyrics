import Cocoa
import Carbon.HIToolbox
import Translation

extension AppDelegate {
    func automationStatus() -> String {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first != nil else {
            return "unknown (Spotify is not running)"
        }
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.spotify.client")
        guard let desc = target.aeDesc else { return "unknown" }
        let st = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, false)
        switch Int(st) {
        case 0: return "granted"
        case Int(errAEEventNotPermitted): return "denied"
        case Int(errAEEventWouldRequireUserConsent): return "not asked yet"
        default: return "unknown (\(st))"
        }
    }

    func collectDiagnostics() async -> String {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "dev"
        let build = (info?["CFBundleVersion"] as? String) ?? "-"
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "x86_64"
        #endif

        let av = LanguageAvailability()
        let tgt = Locale.Language(identifier: Prefs.target)
        var installed: [String] = []
        var missing: [String] = []
        for id in Prefs.supportedTargets where !Lang.same(id, Prefs.target) {
            switch await av.status(from: Locale.Language(identifier: id), to: tgt) {
            case .installed: installed.append(id)
            case .supported: missing.append(id)
            default: break
            }
        }

        let stats = Store.cacheStats()
        let age = lastFetch == .distantPast ? "never" : "\(Int(Date().timeIntervalSince(lastFetch)))s ago"
        let hotFailedCount = hotFailed.count

        let sections: [(title: String, rows: [(String, String)])] = [
            ("App", [
                ("Version", "\(version) (\(build))"),
                ("macOS", ProcessInfo.processInfo.operatingSystemVersionString),
                ("Architecture", arch),
                ("Running as .app", inBundle ? "yes" : "no")
            ]),
            ("Settings", [
                ("App language", "\(Prefs.appLanguage) (resolved: \(L10n.current))"),
                ("Target language", Prefs.target),
                ("Lyrics language mode", Prefs.signature),
                ("Casual style", Prefs.casual ? "on" : "off"),
                ("Readings", Prefs.showRomaji ? "on" : "off"),
                ("Cover accent", Prefs.coverAccent ? "on" : "off"),
                ("Display mode", displayMode),
                ("Floating lyrics", floatOn ? "on" : "off"),
                ("Global shortcuts", hotKeysOn ? "on (\(hotFailedCount) unavailable)" : "off")
            ]),
            ("Spotify", [
                ("Running", NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first != nil ? "yes" : "no"),
                ("Automation permission", automationStatus()),
                ("Player state", snap?.state ?? "none"),
                ("Last data fetch", age),
                ("Playback notifications received", "\(notificationCount)")
            ]),
            ("Cache", [
                ("Lyrics", "\(stats.lyricsCount) songs, \(Diagnostics.size(stats.lyricsBytes))"),
                ("Translations", "\(stats.transCount) entries, \(Diagnostics.size(stats.transBytes))"),
                ("Saved vocabulary", "\(Vocab.load().count) words")
            ]),
            ("Translation languages (to \(Prefs.target))", [
                ("Installed", installed.isEmpty ? "none" : installed.joined(separator: ", ")),
                ("Not installed", missing.isEmpty ? "none" : missing.joined(separator: ", "))
            ])
        ]
        return Diagnostics.report(sections: sections, recent: Diagnostics.recent)
    }

    func copyDiagnostics() {
        Task {
            let text = await collectDiagnostics()
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                MainActor.assumeIsolated { self.settingsModel?.flashCopied() }
            }
        }
    }

    func revealDataFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([Store.dir])
    }
}
