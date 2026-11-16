import AVFoundation

private final class SynthRun: @unchecked Sendable {
    let synth = AVSpeechSynthesizer()
    var file: AVAudioFile?
    var failed = false
    private let lock = NSLock()
    private var done = false

    func finishOnce() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

enum AudioSynth {
    static func write(text: String, language code: String, to url: URL, rate: Float = 0.45) async -> Bool {
        let t = Speech.prepare(text)
        guard !t.isEmpty, let lang = Speech.voiceLanguage(for: code), let voice = AVSpeechSynthesisVoice(language: lang) else { return false }
        try? FileManager.default.removeItem(at: url)
        let run = SynthRun()
        let u = AVSpeechUtterance(string: t)
        u.voice = voice
        u.rate = rate
        return await withCheckedContinuation { cont in
            run.synth.write(u) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    run.file = nil
                    if run.finishOnce() { cont.resume(returning: FileManager.default.fileExists(atPath: url.path) && !run.failed) }
                    return
                }
                do {
                    if run.file == nil {
                        run.file = try AVAudioFile(forWriting: url, settings: [
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVSampleRateKey: pcm.format.sampleRate,
                            AVNumberOfChannelsKey: pcm.format.channelCount,
                            AVEncoderBitRateKey: 64000
                        ], commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
                    }
                    try run.file?.write(from: pcm)
                } catch {
                    run.failed = true
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 25) {
                if run.finishOnce() {
                    run.file = nil
                    cont.resume(returning: false)
                }
            }
        }
    }
}
