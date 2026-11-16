import Cocoa
import Carbon.HIToolbox
import Translation

extension AppDelegate {
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
        let age = tracker.lastFetchAge(now: Date()).map { "\(Int($0))s ago" } ?? "never"
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
            ("Player", [
                ("Setting", Prefs.playerChoice),
                ("Active player", router.activeID.displayName),
                ("Spotify running", router.spotify.isRunning ? "yes" : "no"),
                ("Apple Music running", router.music.isRunning ? "yes" : "no"),
                ("Automation permission", automationState().label),
                ("Player state", tracker.snap?.state ?? "none"),
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
        return Diagnostics.report(sections: sections, recent: Diagnostics.recent, previous: Diagnostics.previous)
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
