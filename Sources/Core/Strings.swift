import Foundation

enum S: String, CaseIterable {
    case spotifyInactive, learnMode, thisSong, reloadLyrics, settingsMenu, settingsTitle
    case songLanguage, songLanguageValue, followSettings, quit
    case adTitle, adSubtitle, adWaiting, adLearn, adMenuBar
    case noSong, nothingPlaying, nothingPlayingLearn, openSpotifyHint, spotifyInactiveLearn
    case automationInfo, automationNeeded, automationPath, automationLearn
    case automationAlertTitle, automationAlertBody, openSystemSettings, later
    case lyricsUnavailable, lyricsLoading, lyricsNoneForSong
    case floatOnMsg, floatOffMsg, modeOriginal, modeTranslation, modeBoth, displayModeMsg
    case menuBarLyricsHidden, menuBarLyricsShown, offsetMsg, hotkeyTaken
    case hkFloat, hkMode, hkHide, hkSlower, hkFaster
    case tsNoSong, tsWaiting, tsNoLyrics, tsFailed, tsBusy, tsSame, tsReady, tsQueued, transFailedLearn
    case tabGeneral, tabTranslation, tabAppearance, tabShortcuts
    case loginToggle, floatToggle, aboutText, appLanguage, appLangSystem
    case casualToggle, casualNote, romajiToggle, romajiNote, accentToggle, hotkeysToggle
    case loginFailed, loginNeedsBundle, loginApprove
    case downloadLanguage, tryAgain, pillOriginal, pillTranslation, pillBoth
    case cancelled, notInstalled, targetLanguage, downloadingTime, cancel, noPercent
    case installed, download, unsupported, hintLimited, hintFixed, hintAuto
    case translateTo, lyricsLanguage, srcAuto, srcLimited, srcFixed, searchLanguage
    case downloadChecked, onDeviceNote, failedWith
    case learnWindow, learnWindowSong, learnHint, btnTranslate, btnSaveWord, btnExportAnki, vocabCount
    case lineSelected, lookingUp, dictEnglish, meaningNotFoundWith, meaningNotFound
    case translationFailedNote, translatingLine, lineNoNeed, exportNone, exportDone
    case langJaRom, langKoRom, audioOutput
    case firstRunTitle, firstRunBody, firstRunContinue
}

enum L10n {
    nonisolated(unsafe) static var forced: String?
    nonisolated(unsafe) private static var cached: String?

    static func resolve(_ setting: String, preferred: [String] = Locale.preferredLanguages) -> String {
        if setting == "id" || setting == "en" { return setting }
        return (preferred.first ?? "en").lowercased().hasPrefix("id") ? "id" : "en"
    }

    static var current: String {
        if let f = forced { return f }
        if let c = cached { return c }
        let r = resolve(Prefs.appLanguage)
        cached = r
        return r
    }

    static func refresh() { cached = nil }

    static var locale: Locale { Locale(identifier: current) }

    static func text(_ k: S) -> String {
        let table = current == "id" ? indonesian : english
        return table[k] ?? indonesian[k] ?? k.rawValue
    }
}

func L(_ k: S, _ args: CVarArg...) -> String {
    let t = L10n.text(k)
    return args.isEmpty ? t : String(format: t, locale: L10n.locale, arguments: args)
}

extension L10n {
    static let indonesian: [S: String] = [
        .spotifyInactive: "Spotify tidak aktif",
        .learnMode: "Mode belajar",
        .thisSong: "Lagu ini",
        .reloadLyrics: "Muat ulang lirik dari LRCLIB",
        .settingsMenu: "Pengaturan…",
        .settingsTitle: "Pengaturan",
        .songLanguage: "Bahasa lagu ini",
        .songLanguageValue: "Bahasa lagu ini: %@",
        .followSettings: "Ikuti pengaturan",
        .quit: "Keluar",
        .adTitle: "Iklan Spotify",
        .adSubtitle: "Lirik kembali setelah iklan selesai",
        .adWaiting: "Menunggu iklan selesai",
        .adLearn: "Iklan sedang diputar. Lirik kembali setelah iklan selesai.",
        .adMenuBar: "📢 Iklan · %d:%02d",
        .noSong: "Tidak ada lagu",
        .nothingPlaying: "Tidak ada lagu yang diputar",
        .nothingPlayingLearn: "Tidak ada lagu yang diputar.",
        .openSpotifyHint: "Buka Spotify dan putar lagu",
        .spotifyInactiveLearn: "Spotify tidak aktif. Buka Spotify dan putar lagu.",
        .automationInfo: "Izinkan Automation ke Spotify di System Settings",
        .automationNeeded: "Izin Automation diperlukan",
        .automationPath: "System Settings > Privacy & Security > Automation",
        .automationLearn: "SpotLyrics belum diizinkan mengontrol Spotify (System Settings > Privacy & Security > Automation).",
        .automationAlertTitle: "SpotLyrics belum diizinkan mengontrol Spotify",
        .automationAlertBody: "Buka System Settings > Privacy & Security > Automation, lalu nyalakan Spotify di bawah SpotLyrics. Setelah itu lirik akan muncul otomatis.",
        .openSystemSettings: "Buka System Settings",
        .later: "Nanti",
        .lyricsUnavailable: "Lirik tidak tersedia",
        .lyricsLoading: "Memuat lirik...",
        .lyricsNoneForSong: "Lirik belum tersedia untuk lagu ini.",
        .floatOnMsg: "Lirik melayang: aktif",
        .floatOffMsg: "Lirik melayang: mati",
        .modeOriginal: "Lirik asli",
        .modeTranslation: "Terjemahan",
        .modeBoth: "Asli + terjemahan",
        .displayModeMsg: "Tampilan: %@",
        .menuBarLyricsHidden: "Lirik di menu bar: disembunyikan",
        .menuBarLyricsShown: "Lirik di menu bar: tampil",
        .offsetMsg: "Offset lirik %+.2fs",
        .hotkeyTaken: "(dipakai app lain)",
        .hkFloat: "Lirik melayang",
        .hkMode: "Ganti tampilan: Asli / Terjemahan / Keduanya",
        .hkHide: "Sembunyikan lirik di menu bar",
        .hkSlower: "Lirik lebih lambat (-0.1s)",
        .hkFaster: "Lirik lebih cepat (+0.1s)",
        .tsNoSong: "Terjemahan: tidak ada lagu",
        .tsWaiting: "Terjemahan: menunggu lirik...",
        .tsNoLyrics: "Terjemahan: lirik lagu ini tidak ada",
        .tsFailed: "Terjemahan gagal (%@)",
        .tsBusy: "Terjemahan: memproses...",
        .tsSame: "Terjemahan: lirik sudah di bahasa tujuan",
        .tsReady: "Terjemahan: siap (%@ ke %@)",
        .tsQueued: "Terjemahan: antre...",
        .transFailedLearn: "Terjemahan gagal: %@\n\nPastikan bahasa lirik dan bahasa tujuan sudah diunduh lewat Pengaturan > Terjemahan.",
        .tabGeneral: "Umum",
        .tabTranslation: "Terjemahan",
        .tabAppearance: "Tampilan",
        .tabShortcuts: "Pintasan",
        .loginToggle: "Mulai saat login",
        .floatToggle: "Lirik melayang",
        .aboutText: "SpotLyrics membaca lagu yang sedang diputar di Spotify lewat izin Automation, lalu mengambil lirik dari LRCLIB. Terjemahan berjalan di perangkat.",
        .appLanguage: "Bahasa aplikasi",
        .appLangSystem: "Ikuti sistem",
        .casualToggle: "Gaya santai (bahasa sehari-hari)",
        .casualNote: "Merapikan hasil terjemahan ke Indonesia dan Inggris agar tidak terlalu baku.",
        .romajiToggle: "Tampilkan cara baca (romaji)",
        .romajiNote: "Hanya muncul untuk lagu berbahasa Jepang atau Korea.",
        .accentToggle: "Warna aksen sesuai cover album",
        .hotkeysToggle: "Aktifkan pintasan global",
        .loginFailed: "Gagal mengatur mulai saat login",
        .loginNeedsBundle: "Butuh SpotLyrics.app. Jalankan ./build.sh lalu buka app-nya.",
        .loginApprove: "Setujui SpotLyrics di System Settings > Login Items.",
        .downloadLanguage: "Unduh bahasa",
        .tryAgain: "Coba lagi",
        .pillOriginal: "Asli",
        .pillTranslation: "Terjemahan",
        .pillBoth: "Keduanya",
        .cancelled: "Dibatalkan",
        .notInstalled: "Belum terpasang",
        .targetLanguage: "Bahasa tujuan",
        .downloadingTime: "Mengunduh %d:%02d",
        .cancel: "Batal",
        .noPercent: "macOS tidak memberi persentase, lihat dialog unduhan",
        .installed: "Terpasang",
        .download: "Unduh",
        .unsupported: "Tidak didukung",
        .hintLimited: "Centang bahasa yang ada di lagu, mis. Korea + Inggris.",
        .hintFixed: "Semua baris dianggap satu bahasa.",
        .hintAuto: "Dideteksi per baris, jadi lagu campuran tertangani. Romanisasi Korea terbaca sebagai Inggris.",
        .translateTo: "Terjemahkan ke",
        .lyricsLanguage: "Bahasa lirik",
        .srcAuto: "Otomatis (semua bahasa)",
        .srcLimited: "Otomatis, terbatas pada bahasa tercentang",
        .srcFixed: "Satu bahasa tetap",
        .searchLanguage: "Cari bahasa",
        .downloadChecked: "Unduh yang tercentang (%d)",
        .onDeviceNote: "Terjemahan berjalan di perangkat. Setiap bahasa diunduh sekali; dialog unduhan muncul dari macOS.",
        .failedWith: "Gagal: %@",
        .learnWindow: "Belajar",
        .learnWindowSong: "Belajar: %@",
        .learnHint: "Klik kata di lirik untuk lihat arti. Klik baris lalu \"Terjemahkan\" untuk terjemahan baris itu.",
        .btnTranslate: "Terjemahkan",
        .btnSaveWord: "Simpan kata",
        .btnExportAnki: "Ekspor Anki",
        .vocabCount: "Kosakata tersimpan: %d",
        .lineSelected: "Baris dipilih. Klik \"Terjemahkan\" untuk terjemahan baris itu.",
        .lookingUp: "Mencari arti \"%@\"...",
        .dictEnglish: "Kamus (Inggris):",
        .meaningNotFoundWith: "Arti tidak ditemukan (%@).",
        .meaningNotFound: "Arti tidak ditemukan.",
        .translationFailedNote: "(Terjemahan gagal: %@)",
        .translatingLine: "Menerjemahkan baris...",
        .lineNoNeed: "Baris ini tidak perlu diterjemahkan.",
        .exportNone: "Belum ada kosakata tersimpan, atau gagal menulis file ke Downloads.",
        .exportDone: "Diekspor ke Downloads: %@\n\nDi Anki: File > Import, pilih file ini. Field pertama jadi depan kartu, field kedua jadi belakang.",
        .langJaRom: "Jepang (romaji)",
        .langKoRom: "Korea (romanisasi)",
        .audioOutput: "Output",
        .firstRunTitle: "Terjemahkan lirik ke bahasa apa?",
        .firstRunBody: "Lirik berbahasa lain akan diterjemahkan ke bahasa ini. Kamu bisa mengubahnya kapan saja di Pengaturan > Terjemahan, tempat bahasa juga diunduh.",
        .firstRunContinue: "Lanjut"
    ]

    static let english: [S: String] = [
        .spotifyInactive: "Spotify isn't running",
        .learnMode: "Study mode",
        .thisSong: "This song",
        .reloadLyrics: "Reload lyrics from LRCLIB",
        .settingsMenu: "Settings…",
        .settingsTitle: "Settings",
        .songLanguage: "Song language",
        .songLanguageValue: "Song language: %@",
        .followSettings: "Follow settings",
        .quit: "Quit",
        .adTitle: "Spotify ad",
        .adSubtitle: "Lyrics return after the ad",
        .adWaiting: "Waiting for the ad to finish",
        .adLearn: "An ad is playing. Lyrics return after it finishes.",
        .adMenuBar: "📢 Ad · %d:%02d",
        .noSong: "No song",
        .nothingPlaying: "Nothing is playing",
        .nothingPlayingLearn: "Nothing is playing.",
        .openSpotifyHint: "Open Spotify and play a song",
        .spotifyInactiveLearn: "Spotify isn't running. Open it and play a song.",
        .automationInfo: "Allow Automation for Spotify in System Settings",
        .automationNeeded: "Automation permission needed",
        .automationPath: "System Settings > Privacy & Security > Automation",
        .automationLearn: "SpotLyrics isn't allowed to control Spotify (System Settings > Privacy & Security > Automation).",
        .automationAlertTitle: "SpotLyrics isn't allowed to control Spotify",
        .automationAlertBody: "Open System Settings > Privacy & Security > Automation and turn on Spotify under SpotLyrics. Lyrics will then appear automatically.",
        .openSystemSettings: "Open System Settings",
        .later: "Later",
        .lyricsUnavailable: "Lyrics unavailable",
        .lyricsLoading: "Loading lyrics...",
        .lyricsNoneForSong: "No lyrics available for this song yet.",
        .floatOnMsg: "Floating lyrics: on",
        .floatOffMsg: "Floating lyrics: off",
        .modeOriginal: "Original lyrics",
        .modeTranslation: "Translation",
        .modeBoth: "Original + translation",
        .displayModeMsg: "Display: %@",
        .menuBarLyricsHidden: "Menu bar lyrics: hidden",
        .menuBarLyricsShown: "Menu bar lyrics: shown",
        .offsetMsg: "Lyrics offset %+.2fs",
        .hotkeyTaken: "(used by another app)",
        .hkFloat: "Floating lyrics",
        .hkMode: "Switch display: Original / Translation / Both",
        .hkHide: "Hide menu bar lyrics",
        .hkSlower: "Lyrics slower (-0.1s)",
        .hkFaster: "Lyrics faster (+0.1s)",
        .tsNoSong: "Translation: no song",
        .tsWaiting: "Translation: waiting for lyrics...",
        .tsNoLyrics: "Translation: this song has no lyrics",
        .tsFailed: "Translation failed (%@)",
        .tsBusy: "Translation: working...",
        .tsSame: "Translation: lyrics are already in the target language",
        .tsReady: "Translation: ready (%@ to %@)",
        .tsQueued: "Translation: queued...",
        .transFailedLearn: "Translation failed: %@\n\nMake sure the lyrics language and the target language are downloaded in Settings > Translation.",
        .tabGeneral: "General",
        .tabTranslation: "Translation",
        .tabAppearance: "Appearance",
        .tabShortcuts: "Shortcuts",
        .loginToggle: "Launch at login",
        .floatToggle: "Floating lyrics",
        .aboutText: "SpotLyrics reads the song playing in Spotify through the Automation permission, then fetches lyrics from LRCLIB. Translation runs on your device.",
        .appLanguage: "App language",
        .appLangSystem: "Follow system",
        .casualToggle: "Casual style (everyday language)",
        .casualNote: "Smooths translations into Indonesian and English so they sound less formal.",
        .romajiToggle: "Show readings (romaji)",
        .romajiNote: "Only shown for Japanese or Korean songs.",
        .accentToggle: "Accent color from the album cover",
        .hotkeysToggle: "Enable global shortcuts",
        .loginFailed: "Couldn't change launch at login",
        .loginNeedsBundle: "Requires SpotLyrics.app. Run ./build.sh and open the app.",
        .loginApprove: "Approve SpotLyrics in System Settings > Login Items.",
        .downloadLanguage: "Download language",
        .tryAgain: "Try again",
        .pillOriginal: "Original",
        .pillTranslation: "Translation",
        .pillBoth: "Both",
        .cancelled: "Cancelled",
        .notInstalled: "Not installed",
        .targetLanguage: "Target language",
        .downloadingTime: "Downloading %d:%02d",
        .cancel: "Cancel",
        .noPercent: "macOS doesn't report a percentage; see the download dialog",
        .installed: "Installed",
        .download: "Download",
        .unsupported: "Not supported",
        .hintLimited: "Check the languages that appear in the song, e.g. Korean + English.",
        .hintFixed: "All lines are treated as one language.",
        .hintAuto: "Detected line by line, so mixed-language songs work. Romanized Korean is read as English.",
        .translateTo: "Translate to",
        .lyricsLanguage: "Lyrics language",
        .srcAuto: "Automatic (all languages)",
        .srcLimited: "Automatic, limited to checked languages",
        .srcFixed: "One fixed language",
        .searchLanguage: "Search languages",
        .downloadChecked: "Download checked (%d)",
        .onDeviceNote: "Translation runs on your device. Each language is downloaded once; the download dialog comes from macOS.",
        .failedWith: "Failed: %@",
        .learnWindow: "Study",
        .learnWindowSong: "Study: %@",
        .learnHint: "Click a word in the lyrics to see its meaning. Click a line, then \"Translate\", to translate that line.",
        .btnTranslate: "Translate",
        .btnSaveWord: "Save word",
        .btnExportAnki: "Export to Anki",
        .vocabCount: "Saved words: %d",
        .lineSelected: "Line selected. Click \"Translate\" to translate it.",
        .lookingUp: "Looking up \"%@\"...",
        .dictEnglish: "Dictionary (English):",
        .meaningNotFoundWith: "No meaning found (%@).",
        .meaningNotFound: "No meaning found.",
        .translationFailedNote: "(Translation failed: %@)",
        .translatingLine: "Translating line...",
        .lineNoNeed: "This line doesn't need translating.",
        .exportNone: "No saved words yet, or the file couldn't be written to Downloads.",
        .exportDone: "Exported to Downloads: %@\n\nIn Anki: File > Import, choose this file. The first field becomes the front of the card, the second field the back.",
        .langJaRom: "Japanese (romaji)",
        .langKoRom: "Korean (romanization)",
        .audioOutput: "Output",
        .firstRunTitle: "Translate lyrics into which language?",
        .firstRunBody: "Lyrics in other languages will be translated into this language. You can change it any time in Settings > Translation, where languages are also downloaded.",
        .firstRunContinue: "Continue"
    ]
}

enum TransStatus: Equatable {
    case noSong, waiting, noLyrics, failed(String), busy, same, ready(String, String), queued

    var kind: Int {
        switch self {
        case .failed: return 3
        case .busy, .waiting, .queued: return 2
        case .same, .ready: return 1
        case .noSong, .noLyrics: return 0
        }
    }

    var text: String {
        switch self {
        case .noSong: return L(.tsNoSong)
        case .waiting: return L(.tsWaiting)
        case .noLyrics: return L(.tsNoLyrics)
        case .failed(let e): return L(.tsFailed, e)
        case .busy: return L(.tsBusy)
        case .same: return L(.tsSame)
        case .ready(let a, let b): return L(.tsReady, a, b)
        case .queued: return L(.tsQueued)
        }
    }
}
