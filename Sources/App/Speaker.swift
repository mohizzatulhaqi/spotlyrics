import AVFoundation

enum SpeakResult: Equatable {
    case started
    case stopped
    case noVoice(String)
    case empty
}

final class Speaker: NSObject {
    private let synth = AVSpeechSynthesizer()
    var rate: Float = 0.45

    var isSpeaking: Bool { synth.isSpeaking }

    @discardableResult
    func speak(_ text: String, language code: String) -> SpeakResult {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
            return .stopped
        }
        let t = Speech.prepare(text)
        guard !t.isEmpty else { return .empty }
        guard let lang = Speech.voiceLanguage(for: code), let voice = AVSpeechSynthesisVoice(language: lang) else {
            return .noVoice(code)
        }
        let u = AVSpeechUtterance(string: t)
        u.voice = voice
        u.rate = rate
        synth.speak(u)
        return .started
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }
}
