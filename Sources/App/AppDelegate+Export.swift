import Cocoa
import UniformTypeIdentifiers

extension AppDelegate {
    func copyExportItem() -> NSMenuItem {
        let it = NSMenuItem(title: L(.copyExportMenu), action: nil, keyEquivalent: "")
        it.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        let sub = NSMenu()
        var entries: [(String, Selector)] = [
            (L(.copyLine), #selector(copyCurrentLineAction)),
            (L(.copyAll), #selector(copyAllLyrics))
        ]
        if lyricsSynced { entries.append((L(.exportSRT), #selector(exportSRT))) }
        entries.append((L(.exportText), #selector(exportText)))
        for (title, sel) in entries {
            let m = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            m.target = self
            sub.addItem(m)
        }
        it.submenu = sub
        return it
    }

    func currentTranslations() -> [String] { transKey == trackKey ? trans : [] }
    func currentRomaji() -> [String] { Prefs.showRomaji ? romaji : [] }

    func copyToClipboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    @objc func copyCurrentLineAction() { copyCurrentLine() }

    func copyCurrentLine() {
        guard let i = lastIdx, i < lines.count, !LyricsExport.isBlank(lines[i].text) else { return }
        let tr = currentTranslations()
        let rm = currentRomaji()
        copyToClipboard(LyricsExport.block(text: lines[i].text,
                                           romaji: i < rm.count ? rm[i] : "",
                                           translation: i < tr.count ? tr[i] : ""))
        flash(L(.copiedLine))
    }

    @objc func copyAllLyrics() {
        guard !lines.isEmpty else { return }
        copyToClipboard(LyricsExport.text(lines: lines, translations: currentTranslations(), romaji: currentRomaji()))
        flash(L(.copiedAll))
    }

    @objc func exportSRT() {
        let content = LyricsExport.srt(lines: lines, translations: currentTranslations(), romaji: currentRomaji(),
                                       duration: Double(lastDurMs) / 1000)
        export(ext: "srt", content: content)
    }

    @objc func exportText() {
        export(ext: "txt", content: LyricsExport.text(lines: lines, translations: currentTranslations(), romaji: currentRomaji()))
    }

    func export(ext: String, content: String) {
        guard !lines.isEmpty else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = LyricsExport.fileName(artist: curArtist, title: curTitle, ext: ext)
        if let t = UTType(filenameExtension: ext) { panel.allowedContentTypes = [t] }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            flash(L(.exportDoneMsg, url.lastPathComponent))
        } catch {
            flash(L(.exportFailed))
            Diagnostics.log("export failed: \(error.localizedDescription)")
        }
    }
}
