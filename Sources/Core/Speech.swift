import Foundation

enum Speech {
    static let voiceLanguages: [String: String] = [
        "ar": "ar-SA", "de": "de-DE", "en": "en-US", "es": "es-ES", "fr": "fr-FR", "hi": "hi-IN", "id": "id-ID",
        "it": "it-IT", "ja": "ja-JP", "ko": "ko-KR", "nl": "nl-NL", "pl": "pl-PL", "pt": "pt-BR", "ru": "ru-RU",
        "th": "th-TH", "tr": "tr-TR", "uk": "uk-UA", "vi": "vi-VN", "zh": "zh-CN"
    ]

    static func voiceLanguage(for code: String) -> String? {
        let lang = Locale.Language(identifier: code)
        guard let base = lang.languageCode?.identifier else { return nil }
        if base == "zh" {
            let trad = lang.script?.identifier == "Hant" || code.contains("TW") || code.contains("HK")
            return trad ? "zh-TW" : "zh-CN"
        }
        return voiceLanguages[base]
    }

    static func prepare(_ text: String) -> String {
        let collapsed = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return collapsed == "♪" ? "" : collapsed
    }
}
