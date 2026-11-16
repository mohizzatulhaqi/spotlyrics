import Foundation
import Translation

// MARK: - On-device translation (Apple Translation)

struct BatchResult: Sendable {
    var out: [String]
    var errors: [String: String]
}

@MainActor
final class Translator {
    nonisolated init() {}
    private var sessions: [String: TranslationSession] = [:]

    nonisolated static func friendly(_ e: Error) -> String { String(e.localizedDescription.prefix(60)) }

    nonisolated static func same(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == b.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func reset() { sessions = [:] }

    private func session(_ src: String, _ tgt: String) -> TranslationSession {
        let k = src + ">" + tgt
        if let s = sessions[k] { return s }
        let s = TranslationSession(installedSource: Locale.Language(identifier: src),
                                       target: Locale.Language(identifier: tgt))
        sessions[k] = s
        return s
    }

    func translate(_ text: String, from src: String) async throws -> String {
        let tgt = Prefs.target
        if Lang.same(src, tgt) { return "" }
        let r = try await session(src, tgt).translate(text)
        if Translator.same(r.targetText, text) { return "" }
        return Prefs.casual ? Casual.apply(r.targetText, target: tgt) : r.targetText
    }

    func translateBatch(_ texts: [String], langs: [String], target: String) async -> BatchResult {
        var out = Array(repeating: "", count: texts.count)
        var errors: [String: String] = [:]
        var groups: [String: [Int]] = [:]
        for (i, t) in texts.enumerated() where i < langs.count {
            let l = langs[i]
            if l.isEmpty || t.isEmpty || t == "♪" || Lang.same(l, target) { continue }
            groups[l, default: []].append(i)
        }
        for (lang, idxs) in groups {
            let reqs = idxs.map { TranslationSession.Request(sourceText: texts[$0], clientIdentifier: String($0)) }
            do {
                let resp = try await session(lang, target).translations(from: reqs)
                for r in resp {
                    if let id = r.clientIdentifier, let i = Int(id), i >= 0, i < out.count,
                       !Translator.same(r.targetText, texts[i]) {
                        out[i] = r.targetText
                    }
                }
            } catch {
                errors[lang] = Translator.friendly(error)
            }
        }
        return BatchResult(out: out, errors: errors)
    }
}
