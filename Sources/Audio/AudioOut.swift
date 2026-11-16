import Foundation
import CoreAudio

// MARK: - Audio output + per-device offset

enum AudioOut {
    static func current() -> (uid: String, name: String, bt: Bool)? {
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr
        else { return nil }

        func str(_ sel: AudioObjectPropertySelector) -> String? {
            var a = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal,
                                               mElement: kAudioObjectPropertyElementMain)
            var cf: Unmanaged<CFString>?
            var sz = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(dev, &a, 0, nil, &sz, &cf) == noErr, let c = cf else { return nil }
            return c.takeRetainedValue() as String
        }

        var tt: UInt32 = 0
        var tsz = UInt32(MemoryLayout<UInt32>.size)
        var ta = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                                            mScope: kAudioObjectPropertyScopeGlobal,
                                            mElement: kAudioObjectPropertyElementMain)
        _ = AudioObjectGetPropertyData(dev, &ta, 0, nil, &tsz, &tt)
        let bt = tt == UInt32(kAudioDeviceTransportTypeBluetooth) || tt == UInt32(kAudioDeviceTransportTypeBluetoothLE)

        let uid = str(kAudioDevicePropertyDeviceUID) ?? "device-\(dev)"
        let name = str(kAudioObjectPropertyName) ?? L(.audioOutput)
        return (uid, name, bt)
    }
}

enum Offsets {
    static let key = "deviceOffsets"
    static func get(_ uid: String) -> Double? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Double])?[uid]
    }
    static func set(_ uid: String, _ v: Double) {
        var d = (UserDefaults.standard.dictionary(forKey: key) as? [String: Double]) ?? [:]
        d[uid] = v
        UserDefaults.standard.set(d, forKey: key)
    }
}
