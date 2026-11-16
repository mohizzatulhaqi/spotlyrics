import Foundation

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var total = 0

func check(_ cond: Bool, _ name: String) {
    total += 1
    if !cond { failures += 1; print("FAILED: \(name)") }
}

func eq<T: Equatable>(_ got: T, _ want: T, _ name: String) {
    total += 1
    if got != want { failures += 1; print("FAILED: \(name)\n   got:      \(got)\n   expected: \(want)") }
}

func resetPrefs() {
    for k in ["sourceMode", "fixedSource", "candidateLangs", "targetLang", "songLang", "showRomaji"] {
        UserDefaults.standard.removeObject(forKey: k)
    }
}

resetPrefs()
L10n.forced = "id"

let lrc = """
[ar: Seseorang]
[00:12.50] Baris satu
[00:20.00]
[01:05] Tanpa desimal
[00:30.10][01:30.20] Ulang dua kali
teks tanpa waktu
"""
let parsed = Lyrics.parse(lrc)
eq(parsed.count, 5, "parse: jumlah baris termasuk timestamp ganda")
eq(parsed.map { $0.time }, [12.5, 20.0, 30.1, 65.0, 90.2], "parse: urut waktu")
eq(parsed[0].text, "Baris satu", "parse: teks dipangkas")
eq(parsed[1].text, "", "parse: baris kosong tetap ada")
eq(parsed[2].text, "Ulang dua kali", "parse: timestamp ganda memakai teks yang sama")
eq(Lyrics.parse("tanpa timestamp sama sekali").count, 0, "parse: tanpa timestamp")
eq(Lyrics.parse("").count, 0, "parse: kosong")

let ko = ["[00:01.00] 사랑해 너무 사랑해", "[00:05.00] 이제는 땅만 보고 걷잖아"].joined(separator: "\n")
let en = ["[00:01.00] I wanna be your baby", "[00:05.00] Take me to the place"].joined(separator: "\n")
let mix = ["[00:01.00] 사랑해", "[00:02.00] I love you", "[00:03.00] Take me there", "[00:04.00] Oh baby"].joined(separator: "\n")
check(Lyrics.hasNative(Lyrics.parse(ko)), "hasNative: Korea")
check(!Lyrics.hasNative(Lyrics.parse(en)), "hasNative: Inggris")
check(!Lyrics.hasNative(Lyrics.parse(mix)), "hasNative: di bawah 30 persen")
let half = ["[00:01.00] 사랑해", "[00:02.00] 너무 좋아", "[00:03.00] Take me there", "[00:04.00] Oh baby"].joined(separator: "\n")
let third = ["[00:01.00] 사랑해", "[00:02.00] I love you", "[00:03.00] Take me there"].joined(separator: "\n")
check(Lyrics.hasNative(Lyrics.parse(half)), "hasNative: 50 persen")
check(Lyrics.hasNative(Lyrics.parse(third)), "hasNative: sepertiga di atas ambang")
check(!Lyrics.hasNative([]), "hasNative: kosong")
check(!Lyrics.hasNative(Lyrics.parse("[00:01.00] ♪\n[00:02.00]")), "hasNative: hanya baris kosong")

eq(Detect.script("사랑해"), "ko", "script: Hangul")
eq(Detect.script("ぼくは"), "ja", "script: Kana")
eq(Detect.script("今日"), nil, "script: kanji saja tidak pasti")
eq(Detect.script("hello"), nil, "script: Latin")
eq(Detect.script("きみ 사"), "ja", "script: Kana lebih banyak")
check(Detect.skippable(""), "skippable: kosong")
check(Detect.skippable("  ♪ "), "skippable: not")
check(!Detect.skippable("halo"), "skippable: teks")

resetPrefs()
let sample = ["I wanna be your baby tonight", "너를 처음 본 순간", "oh oh oh", "♪", "Take me to the place where we belong", "내 맘을 모두 가져가", "yeah"]
let auto = Detect.perLine(sample)
eq(auto.count, sample.count, "perLine: sejajar")
eq(auto[0], "en", "perLine: Inggris")
eq(auto[1], "ko", "perLine: Korea")
eq(auto[3], "", "perLine: not kosong")
eq(auto[2], "ko", "perLine: baris pendek ikut tetangga")
eq(auto[4], "en", "perLine: Inggris kalimat panjang")
eq(auto[5], "ko", "perLine: Korea kedua")
eq(auto[6], "ko", "perLine: kata tunggal ikut tetangga")
eq(Detect.perLine(sample, override: "ja-rom".isEmpty ? nil : "ja"), sample.map { Detect.skippable($0) ? "" : "ja" }, "perLine: override")

UserDefaults.standard.set("fixed", forKey: "sourceMode")
UserDefaults.standard.set("ko", forKey: "fixedSource")
eq(Detect.perLine(sample), sample.map { Detect.skippable($0) ? "" : "ko" }, "perLine: mode tetap")
UserDefaults.standard.set("limited", forKey: "sourceMode")
UserDefaults.standard.set(["en", "ko"], forKey: "candidateLangs")
let limited = Detect.perLine(sample)
check(limited.allSatisfy { ["", "en", "ko"].contains($0) }, "perLine: mode terbatas hanya bahasa kandidat")
resetPrefs()
eq(Detect.perLine([]).count, 0, "perLine: kosong")
eq(Detect.perLine(["♪", ""]), ["", ""], "perLine: semua dilewati")

eq(Romaji.base("ja-rom"), "ja", "Romaji.base ja")
eq(Romaji.base("ko-rom"), "ko", "Romaji.base ko")
eq(Romaji.base("en"), nil, "Romaji.base bukan romanisasi")
let kana = Romaji.convert("Boku wa kimi ga suki da yo", "ja-rom")
check(kana.contains("は") && !kana.contains("わ"), "Romaji ja: partikel wa menjadi は")
check(Romaji.convert("Sore demo ashita wo shinjite", "ja-rom").contains("を"), "Romaji ja: wo menjadi を")
check(Romaji.convert("Kimi e", "ja-rom").contains("へ"), "Romaji ja: e menjadi へ")
eq(Romaji.convert("Saranghae neomu saranghae", "ko-rom"), "사랑해 너무 사랑해", "Romaji ko")
eq(Romaji.convert("halo", "en"), "halo", "Romaji: tag lain tidak diubah")

let koCases: [(String, String)] = [
    ("사랑해", "saranghae"), ("좋아해", "joahae"), ("같이", "gachi"), ("굳이", "guji"),
    ("있어서", "isseoseo"), ("걷잖아", "geotjana"), ("많아", "mana"), ("값이", "gapsi"),
    ("한국말", "hangungmal"), ("밥먹어", "bammeogeo"), ("신라", "silla"),
    ("이제는 땅만 보고 걷잖아", "ijeneun ttangman bogo geotjana"),
    ("I'm 괜찮아 baby", "I'm gwaenchana baby")
]
for (a, b) in koCases { eq(Readings.romanize(a, lang: "ko"), b, "korea: \(a)") }

let jaCases: [(String, String)] = [
    ("諦めたものと賢いものだけが", "akirame ta mono to kashikoi mono dake ga"),
    ("君の名前を呼んだ", "kimi no namae o yon da"),
    ("今日も明日も", "kyou mo asu mo"),
    ("待って行って", "matte itte"),
    ("ぼくは君が好きだよ", "boku wa kimi ga suki da yo")
]
for (a, b) in jaCases { eq(Readings.romanize(a, lang: "ja"), b, "jepang: \(a)") }
eq(Readings.romanize("hello world", lang: "ja"), "", "romanize: tanpa aksara asli")
eq(Readings.romanize("한국", lang: "en"), "", "romanize: bahasa lain")
check(Readings.hasCJK("a 한 b"), "hasCJK Hangul")
check(!Readings.hasCJK("abc 123"), "hasCJK Latin")

let long = "Diam-diam aku menunggu kamu datang di sini malam ini"
eq(Marquee.window("Pendek", width: 20, elapsed: 5), "Pendek", "marquee: teks pendek tetap")
eq(Marquee.window(long, width: 20, elapsed: 0), String(long.prefix(20)), "marquee: awal berhenti di awal")
eq(Marquee.window(long, width: 20, elapsed: 1.3), String(long.prefix(20)), "marquee: masih jeda")
check(Marquee.window(long, width: 20, elapsed: 3) != String(long.prefix(20)), "marquee: sudah bergeser")
for e in stride(from: 0.0, to: 20.0, by: 0.37) {
    eq(Marquee.window(long, width: 20, elapsed: e).count, 20, "marquee: lebar tetap di \(e)")
}
var sawGap = false
for e in stride(from: 0.0, to: 12.0, by: 0.13) where Marquee.window(long, width: 20, elapsed: e).contains("•") { sawGap = true }
check(sawGap, "marquee: pemisah muncul saat menyambung")
let cycle = Marquee.pause + Double((long + Marquee.gap).count) * Marquee.step
eq(Marquee.window(long, width: 20, elapsed: 3.0), Marquee.window(long, width: 20, elapsed: 3.0 + cycle), "marquee: berulang per siklus")

let t0 = Date(timeIntervalSince1970: 1000)
eq(Playback.position(posMs: 5000, durMs: 200000, playing: true, at: t0, now: t0.addingTimeInterval(2.5)), 7500, "playback: maju saat memutar")
eq(Playback.position(posMs: 5000, durMs: 200000, playing: false, at: t0, now: t0.addingTimeInterval(9)), 5000, "playback: diam saat jeda")
eq(Playback.position(posMs: 199000, durMs: 200000, playing: true, at: t0, now: t0.addingTimeInterval(30)), 200000, "playback: tidak melewati durasi")
eq(Playback.position(posMs: 1000, durMs: 0, playing: true, at: t0, now: t0.addingTimeInterval(1)), 2000, "playback: durasi nol tidak membatasi")
eq(Playback.position(posMs: 1000, durMs: 1000, playing: true, at: t0, now: t0.addingTimeInterval(-3)), 1000, "playback: jam mundur tidak mengurangi")

check(Lang.same("en", "en-US"), "Lang.same: en dan en-US")
check(!Lang.same("en", "id"), "Lang.same: beda bahasa")
check(Lang.same("zh", "zh-Hans"), "Lang.same: zh")
eq(Lang.name("ja-rom"), "Jepang (romaji)", "Lang.name romaji")
eq(Lang.name("ko-rom"), "Korea (romanisasi)", "Lang.name romanisasi")

resetPrefs()
UserDefaults.standard.set("id", forKey: "appLanguage")
L10n.refresh()
eq(Prefs.target, "id", "Prefs: target bawaan mengikuti bahasa app")
check(!Prefs.hasChosenTarget, "Prefs: target belum dipilih")
Prefs.target = "ko"
eq(Prefs.target, "ko", "Prefs: pilihan eksplisit menang")
check(Prefs.hasChosenTarget, "Prefs: target sudah dipilih")
UserDefaults.standard.removeObject(forKey: "targetLang")
UserDefaults.standard.removeObject(forKey: "appLanguage")
L10n.refresh()
eq(Prefs.sourceMode, "auto", "Prefs: mode bawaan")
eq(Prefs.signature, "auto", "Prefs: signature auto")
check(Prefs.showRomaji, "Prefs: romaji aktif bawaan")
Prefs.sourceMode = "fixed"; Prefs.fixedSource = "ja"
eq(Prefs.signature, "f-ja", "Prefs: signature tetap")
Prefs.sourceMode = "limited"; Prefs.candidates = ["ko", "en"]
eq(Prefs.signature, "l-en-ko", "Prefs: signature terbatas terurut")
eq(Prefs.songOverride("a|b"), nil, "override: belum ada")
Prefs.setSongOverride("a|b", "ko-rom")
eq(Prefs.songOverride("a|b"), "ko-rom", "override: tersimpan")
Prefs.setSongOverride("a|b", nil)
eq(Prefs.songOverride("a|b"), nil, "override: dihapus")
Prefs.showRomaji = false
check(!Prefs.showRomaji, "Prefs: romaji dimatikan")
resetPrefs()

let f = Store.lyricsFile("Artis/Ber:Nama|Judul?*|200")
check(!f.lastPathComponent.contains("/") && f.pathExtension == "json", "Store: nama file aman")
let longKey = String(repeating: "a", count: 400)
check(Store.lyricsFile(longKey).lastPathComponent.count <= 160, "Store: nama file dibatasi")
let testKey = "__tes__|lirik|1"
Store.writeLyrics(testKey, [Line(time: 1.5, text: "satu"), Line(time: 3, text: "dua")])
let back = Store.readLyrics(testKey)
eq(back?.lines.map { $0.text } ?? [], ["satu", "dua"], "Store: tulis lalu baca")
eq(back?.lines.map { $0.time } ?? [], [1.5, 3], "Store: waktu terbaca")
check(back.map { abs($0.saved.timeIntervalSinceNow) < 5 } ?? false, "Store: waktu simpan terisi")
try? FileManager.default.removeItem(at: Store.lyricsFile(testKey))
eq(Store.readLyrics(testKey)?.lines.count, nil, "Store: terhapus")

func px(_ r: Double, _ g: Double, _ b: Double, _ n: Int) -> [RGB] { Array(repeating: RGB(r: r, g: g, b: b), count: n) }
func hueOf(_ c: RGB?) -> Double { c.map { Palette.hsv($0).h } ?? -1 }

let red = Palette.accent(from: px(0.8, 0.1, 0.1, 50))
check(red != nil && (hueOf(red) < 10 || hueOf(red) > 350), "palette: merah dominan")
let blue = Palette.accent(from: px(0.1, 0.2, 0.9, 80) + px(0.9, 0.1, 0.1, 10))
check(blue != nil && abs(hueOf(blue) - 225) < 15, "palette: biru lebih banyak dari merah")
eq(Palette.accent(from: px(0.5, 0.5, 0.5, 100)), nil, "palette: abu-abu tidak punya aksen")
eq(Palette.accent(from: px(0.05, 0.02, 0.02, 100)), nil, "palette: terlalu gelap")
eq(Palette.accent(from: []), nil, "palette: kosong")
eq(Palette.accent(from: px(0.9, 0.1, 0.1, 2) + px(0.5, 0.5, 0.5, 100)), nil, "palette: warna terlalu sedikit")
let dim = Palette.accent(from: px(0.1, 0.1, 0.5, 40))!
check(Palette.hsv(dim).v >= 0.78, "palette: kecerahan dinaikkan agar terbaca")
let pale = Palette.accent(from: px(0.6, 0.5, 0.45, 40))
check(pale == nil || Palette.hsv(pale!).s >= 0.45, "palette: saturasi dinaikkan")
let vivid = Palette.accent(from: px(1, 0, 0, 40))!
check(Palette.hsv(vivid).s <= 0.9, "palette: saturasi dibatasi")
let edge = Palette.accent(from: px(0.9, 0.1, 0.12, 30) + px(0.9, 0.12, 0.1, 30) + px(0.1, 0.8, 0.1, 40))
check(edge != nil && (hueOf(edge) < 15 || hueOf(edge) > 345), "palette: merah yang terbelah dua sisi hue menang atas hijau")
let c0 = RGB(r: 0.2, g: 0.6, b: 0.9)
let roundTrip = Palette.rgb(h: Palette.hsv(c0).h, s: Palette.hsv(c0).s, v: Palette.hsv(c0).v)
check(abs(roundTrip.r - c0.r) < 1e-9 && abs(roundTrip.g - c0.g) < 1e-9 && abs(roundTrip.b - c0.b) < 1e-9, "palette: hsv dan rgb bolak-balik")

eq(Seek.position(x: 50, width: 200, duration: 180), 45, "seek: seperempat")
eq(Seek.position(x: -20, width: 200, duration: 180), 0, "seek: sebelum awal")
eq(Seek.position(x: 999, width: 200, duration: 180), 180, "seek: melewati ujung")
eq(Seek.position(x: 100, width: 0, duration: 180), 0, "seek: lebar nol")
eq(Seek.position(x: 100, width: 200, duration: 0), 0, "seek: durasi nol")

eq(Casual.apply("Saya tidak tahu apa yang Anda inginkan", target: "id"), "Aku nggak tahu apa yang kamu inginkan", "casual id: kata ganti dan negasi")
eq(Casual.apply("Anda sangat cantik", target: "id"), "Kamu cantik banget", "casual id: sangat dipindah ke belakang")
eq(Casual.apply("Sangat indah", target: "id"), "Indah banget", "casual id: awal kalimat tetap kapital")
eq(Casual.apply("Mengapa Anda sedang menangis?", target: "id"), "Kenapa kamu lagi menangis?", "casual id: kata tanya")
eq(Casual.apply("Jika hanya sekali saja", target: "id"), "Kalau cuma sekali aja", "casual id: konjungsi")
eq(Casual.apply("Aku sayang kamu", target: "id"), "Aku sayang kamu", "casual id: sudah santai tidak berubah")
eq(Casual.apply("Rumahnya tidaklah jauh", target: "id"), "Rumahnya tidaklah jauh", "casual id: tidak memotong di dalam kata")
eq(Casual.apply("I am not sure you are ready", target: "en"), "I'm not sure you're ready", "casual en: kontraksi")
eq(Casual.apply("Do not go, I cannot stay", target: "en"), "Don't go, I can't stay", "casual en: kapital awal dan cannot")
eq(Casual.apply("Je ne sais pas", target: "fr"), "Je ne sais pas", "casual: bahasa lain tidak diubah")
eq(Casual.apply(["", "Saya tidak"], target: "id"), ["", "Aku nggak"], "casual: baris kosong dilewati")
eq(Casual.apply("Anda", target: "id-ID"), "Kamu", "casual: kode wilayah")

eq(Casual.apply("Aku tidak bisa mengatakan bahwa aku mencintaimu.", target: "id"), "Aku nggak bisa bilang aku mencintaimu.", "casual id: bilang bahwa")

func specifiers(_ s: String) -> [String] {
    var out: [String] = []
    let ns = s as NSString
    let re = try! NSRegularExpression(pattern: "%[+\\-]?[0-9.]*[@dfs]")
    for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) { out.append(ns.substring(with: m.range)) }
    return out
}
for k in S.allCases {
    check(L10n.indonesian[k] != nil, "L10n: kunci \(k.rawValue) ada di Indonesia")
    check(L10n.english[k] != nil, "L10n: kunci \(k.rawValue) ada di Inggris")
    if let a = L10n.indonesian[k], let b = L10n.english[k] {
        eq(specifiers(a), specifiers(b), "L10n: placeholder sama untuk \(k.rawValue)")
        check(!a.isEmpty && !b.isEmpty, "L10n: tidak kosong \(k.rawValue)")
    }
}
eq(L10n.indonesian.count, S.allCases.count, "L10n: tidak ada kunci berlebih di Indonesia")
eq(L10n.english.count, S.allCases.count, "L10n: tidak ada kunci berlebih di Inggris")
let untranslated = S.allCases.filter { L10n.indonesian[$0] == L10n.english[$0] }.map { $0.rawValue }.sorted()
eq(untranslated, ["audioOutput", "automationPath", "exportCsvItem", "playerMusic", "playerSpotify", "readingFurigana", "readingRomaji"], "L10n: hanya teks yang memang sama yang identik")

eq(L10n.resolve("id", preferred: ["en-US"]), "id", "resolve: dipaksa Indonesia")
eq(L10n.resolve("en", preferred: ["id-ID"]), "en", "resolve: dipaksa Inggris")
eq(L10n.resolve("system", preferred: ["id-ID", "en-US"]), "id", "resolve: sistem Indonesia")
eq(L10n.resolve("system", preferred: ["en-GB"]), "en", "resolve: sistem Inggris")
eq(L10n.resolve("system", preferred: ["fr-FR"]), "en", "resolve: bahasa lain jatuh ke Inggris")
eq(L10n.resolve("system", preferred: []), "en", "resolve: tanpa bahasa")

L10n.forced = "id"
eq(L(.quit), "Keluar", "L: Indonesia")
eq(L(.songLanguageValue, "Korea"), "Bahasa lagu ini: Korea", "L: format dengan argumen")
eq(L(.adMenuBar, 0, 5), "📢 Iklan · 0:05", "L: format angka")
eq(Lang.name("ja-rom"), "Jepang (romaji)", "Lang.name Indonesia")
L10n.forced = "en"
eq(L(.quit), "Quit", "L: Inggris")
eq(L(.songLanguageValue, "Korean"), "Song language: Korean", "L: format Inggris")
eq(Lang.name("ja-rom"), "Japanese (romaji)", "Lang.name Inggris")
eq(Lang.name("id"), "Indonesian", "Lang.name memakai bahasa aplikasi")
L10n.forced = "id"
eq(Lang.name("en"), "Inggris", "Lang.name Indonesia: Inggris")
L10n.forced = nil

for (st, kind) in [(TransStatus.noSong, 0), (.noLyrics, 0), (.waiting, 2), (.busy, 2), (.queued, 2), (.same, 1), (.ready("ko", "id"), 1), (.failed("x"), 3)] {
    eq(st.kind, kind, "TransStatus kind: \(st)")
    for lg in ["id", "en"] {
        L10n.forced = lg
        check(!st.text.isEmpty, "TransStatus teks \(lg): \(st)")
    }
}
L10n.forced = "en"
eq(TransStatus.ready("ko+en", "id").text, "Translation: ready (ko+en to id)", "TransStatus: teks Inggris")
L10n.forced = "id"
eq(TransStatus.ready("ko+en", "id").text, "Terjemahan: siap (ko+en ke id)", "TransStatus: teks Indonesia")
L10n.forced = nil
Prefs.appLanguage = "en"
eq(L10n.current, "en", "Prefs.appLanguage menyegarkan bahasa aktif")
Prefs.appLanguage = "id"
eq(L10n.current, "id", "Prefs.appLanguage ganti lagi")
UserDefaults.standard.removeObject(forKey: "appLanguage")
L10n.refresh()

eq(Prefs.defaultTarget(appLanguage: "id", preferred: ["en-US"]), "id", "defaultTarget: bahasa app Indonesia menang")
eq(Prefs.defaultTarget(appLanguage: "en", preferred: ["id-ID"]), "en", "defaultTarget: bahasa app Inggris menang")
eq(Prefs.defaultTarget(appLanguage: "system", preferred: ["id-ID", "en-US"]), "id", "defaultTarget: sistem Indonesia")
eq(Prefs.defaultTarget(appLanguage: "system", preferred: ["fr-FR"]), "fr", "defaultTarget: sistem Prancis")
eq(Prefs.defaultTarget(appLanguage: "system", preferred: ["ja-JP"]), "ja", "defaultTarget: sistem Jepang")
eq(Prefs.defaultTarget(appLanguage: "system", preferred: ["zh-Hans-CN"]), "zh", "defaultTarget: Mandarin sederhana")
eq(Prefs.defaultTarget(appLanguage: "system", preferred: ["zh-Hant-TW"]), "zh-TW", "defaultTarget: Mandarin tradisional")
eq(Prefs.defaultTarget(appLanguage: "system", preferred: ["zh-HK"]), "zh-TW", "defaultTarget: Hong Kong")
eq(Prefs.defaultTarget(appLanguage: "system", preferred: ["sw-KE", "pt-BR"]), "pt", "defaultTarget: lewati bahasa tak didukung")
eq(Prefs.defaultTarget(appLanguage: "system", preferred: ["sw-KE"]), "en", "defaultTarget: tak ada yang didukung")
eq(Prefs.defaultTarget(appLanguage: "system", preferred: []), "en", "defaultTarget: kosong")
check(Prefs.supportedTargets.contains("id") && Prefs.supportedTargets.contains("en"), "supportedTargets memuat id dan en")

eq(Playback.effective(posMs: 10000, offset: 0), 10.25, "effective: tanpa offset")
eq(Playback.effective(posMs: 10000, offset: -0.2), 10.05, "effective: offset negatif")
for off in [0.0, -0.2, 0.3] {
    let raw = Playback.rawPosition(forLineTime: 42.0, offset: off)
    let eff = Playback.effective(posMs: Int((raw * 1000).rounded()), offset: off)
    check(eff >= 42.0 && eff < 42.1, "rawPosition: baris langsung aktif setelah loncat (offset \(off))")
}
eq(Playback.rawPosition(forLineTime: 0.1, offset: 0), 0, "rawPosition: tidak negatif")

let jaRomaji = ["kimi no koe ga suki da yo", "boku wa itsumo kimi wo omotte iru", "sayonara to ienai mama de",
    "kokoro no naka de yume wo miteru", "mou ichido aitai yo kimi ni", "namida ga tomaranai yoru ni", "hikari no naka e aruite iku",
    "sekai ga owaranai you ni to", "zutto zutto kimi no soba ni itai", "ima demo kimi wo omotteru yo", "tsuki ga kirei da ne to itta",
    "motto motto tsuyoku naritai"]
let koRomaja = ["naneun neol saranghae haeyo", "geudaega isseoseo haengbokhae", "nae maeumeun neoreul gidaryeo",
    "wae geureoke eotteoke haneun geonde", "jigeum geu sunganeul gidaryeo", "uri hamkke haneul bwa", "neomu bogosipeo jeongmal",
    "oneul bamdo neoui norae", "naega neol saranghaneun geol", "mianhae gomawo saranghae", "nunmuri meomchuji anha", "geunyang geureoke hajiman"]
let english = ["I wanna be your baby tonight", "Take me to the place where we belong", "Oh baby baby don't you leave me now",
    "We could dance until the morning light", "You and I against the world", "Tell me what you want to do", "I can feel it in my heart",
    "Hold me close and never let go", "The night is young and so are we", "Say you'll stay with me tonight", "Nothing else matters to me",
    "Running through the rain with you"]
let spanish = ["te quiero mucho mi amor", "no puedo vivir sin ti", "la noche es larga sin tu voz", "bailemos juntos esta noche",
    "dime que me quieres otra vez", "tu mirada me da la vida", "yo sin ti no soy nada", "vamos a cantar toda la noche",
    "me gusta cuando tu me besas", "el corazon no sabe mentir", "todo lo que quiero eres tu", "contigo quiero estar siempre"]
let indonesian = ["aku tidak bisa hidup tanpamu", "kamu selalu ada di hatiku", "ayo kita pergi ke pantai malam ini", "jangan pernah tinggalkan aku sendiri",
    "kita berdua akan selalu bersama", "hujan turun di kota yang sepi", "sampai kapan kau membuatku menunggu", "semua yang kuinginkan hanya dirimu",
    "bintang di langit menjadi saksi", "ga mau pergi dari sini", "ku nyanyikan lagu ini untukmu", "waktu berjalan begitu cepat"]
let nativeJa = ["君の声が好きだよ", "ぼくはいつも君を想ってる", "さよならと言えないまま", "心の中で夢を見てる", "もう一度会いたいよ", "涙が止まらない夜に", "光の中へ歩いていく"]

eq(Romanized.guess(jaRomaji), "ja-rom", "romanized: romaji Jepang")
eq(Romanized.guess(koRomaja), "ko-rom", "romanized: romanisasi Korea")
eq(Romanized.guess(english), nil, "romanized: Inggris bukan romanisasi")
eq(Romanized.guess(spanish), nil, "romanized: Spanyol bukan romanisasi")
eq(Romanized.guess(indonesian), nil, "romanized: Indonesia bukan romanisasi")
eq(Romanized.guess(nativeJa), nil, "romanized: aksara asli tidak perlu saran")
eq(Romanized.guess(Array(jaRomaji.prefix(3))), nil, "romanized: terlalu sedikit baris")
eq(Romanized.guess([]), nil, "romanized: kosong")
eq(Romanized.guess(jaRomaji + english), "ja-rom", "romanized: campuran Jepang dominan")
eq(Romanized.guess(english + english + Array(jaRomaji.prefix(2))), nil, "romanized: sedikit romaji di lagu Inggris diabaikan")
eq(Romanized.guess(jaRomaji.map { $0.uppercased() }), "ja-rom", "romanized: huruf besar")

check(!Prefs.isRomanizedDismissed("a|b"), "dismiss: belum diabaikan")
Prefs.dismissRomanized("a|b")
check(Prefs.isRomanizedDismissed("a|b"), "dismiss: tersimpan")
check(!Prefs.isRomanizedDismissed("c|d"), "dismiss: lagu lain tidak terpengaruh")
Prefs.dismissRomanized("a|b")
eq((UserDefaults.standard.stringArray(forKey: "romDismissed") ?? []).count, 1, "dismiss: tanpa duplikat")
for i in 0..<600 { Prefs.dismissRomanized("lagu\(i)") }
check((UserDefaults.standard.stringArray(forKey: "romDismissed") ?? []).count <= 500, "dismiss: daftar dibatasi")
UserDefaults.standard.removeObject(forKey: "romDismissed")

Diagnostics.reset()
eq(Diagnostics.recent.count, 0, "diagnostics: awal kosong")
Diagnostics.log("satu", now: Date(timeIntervalSince1970: 0))
Diagnostics.log("dua")
eq(Diagnostics.recent.count, 2, "diagnostics: dua entri")
check(Diagnostics.recent[1].hasSuffix("dua"), "diagnostics: urutan terjaga")
for i in 0..<100 { Diagnostics.log("e\(i)") }
eq(Diagnostics.recent.count, Diagnostics.capacity, "diagnostics: dibatasi kapasitas")
check(Diagnostics.recent.last?.hasSuffix("e99") ?? false, "diagnostics: entri terbaru dipertahankan")
check(!Diagnostics.recent.contains { $0.hasSuffix("satu") }, "diagnostics: entri tertua dibuang")
Diagnostics.reset()
eq(Diagnostics.redact("/Users/siapa/Library/x", home: "/Users/siapa"), "~/Library/x", "redact: jalur rumah disamarkan")
eq(Diagnostics.redact("tanpa jalur", home: "/Users/siapa"), "tanpa jalur", "redact: teks lain tetap")
eq(Diagnostics.redact("abc", home: "/"), "abc", "redact: root tidak mengubah apa pun")
let rep = Diagnostics.report(sections: [("App", [("Version", "1.0"), ("Path", "/Users/siapa/x")])], recent: ["12:00:00  hello"], home: "/Users/siapa")
check(rep.contains("[App]") && rep.contains("Version: 1.0"), "report: bagian dan baris")
check(rep.contains("Path: ~/x") && !rep.contains("/Users/siapa"), "report: jalur rumah tidak bocor")
check(rep.contains("[Recent events]") && rep.contains("12:00:00  hello"), "report: kejadian terakhir")
check(Diagnostics.report(sections: [], recent: [], home: "/x").contains("(none)"), "report: tanpa kejadian")
eq(Diagnostics.size(500), "500 B", "size: byte")
eq(Diagnostics.size(2048), "2.0 KB", "size: kilobyte")
eq(Diagnostics.size(3 * 1024 * 1024), "3.0 MB", "size: megabyte")
let statsBefore = Store.cacheStats()
Store.writeLyrics("__tes_stats__|x|1", [Line(time: 1, text: "a")])
let statsAfter = Store.cacheStats()
check(statsAfter.lyricsCount == statsBefore.lyricsCount + 1, "cacheStats: menghitung berkas lirik baru")
check(statsAfter.lyricsBytes > statsBefore.lyricsBytes, "cacheStats: ukuran bertambah")
try? FileManager.default.removeItem(at: Store.lyricsFile("__tes_stats__|x|1"))

final class FakePlayer: PlayerSource {
    let id = PlayerID.spotify
    var isRunning = true
    var reading: PlayerReading? = PlayerReading(title: "T", artist: "A", album: "B", durMs: 200000, posMs: 5000, state: "playing", artURL: "u", adURL: "spotify:track:x")
    var commands: [PlayerCommand] = []
    var seeks: [Int] = []
    func fetch() -> PlayerReading? { reading }
    func send(_ command: PlayerCommand) { commands.append(command) }
    func seek(toMs ms: Int) { seeks.append(ms) }
}

let t0f = Date(timeIntervalSince1970: 5000)
func at(_ s: Double) -> Date { t0f.addingTimeInterval(s) }

let fp = FakePlayer()
let tr = PlaybackTracker(source: fp)
eq(tr.fetchCount, 0, "tracker: belum mengambil sebelum refresh")
tr.refresh(now: at(0))
eq(tr.fetchCount, 1, "tracker: refresh pertama mengambil data")
check(tr.snap != nil && !tr.failed, "tracker: snap terisi")
tr.refresh(now: at(1)); tr.refresh(now: at(5)); tr.refresh(now: at(9.9))
eq(tr.fetchCount, 1, "tracker: tidak mengambil lagi sebelum 10 detik saat memutar")
tr.refresh(now: at(10.5))
eq(tr.fetchCount, 2, "tracker: sinkron ulang setelah 10 detik")
eq(tr.positionMs(now: at(12.5)), 5000 + 2000, "tracker: posisi diinterpolasi dari pengambilan terakhir")
tr.notify()
tr.refresh(now: at(11))
eq(tr.fetchCount, 3, "tracker: notifikasi memaksa pengambilan")
tr.markStale()
tr.refresh(now: at(11.1))
eq(tr.fetchCount, 4, "tracker: markStale memaksa pengambilan")
tr.didSeek(toMs: 90000, now: at(20))
eq(tr.positionMs(now: at(20)), 90000, "tracker: posisi segera setelah seek")
eq(tr.positionMs(now: at(21)), 91000, "tracker: posisi maju setelah seek")
tr.refresh(now: at(20.1))
eq(tr.fetchCount, 5, "tracker: seek memicu pengambilan data baru")

let fp2 = FakePlayer()
let tr2 = PlaybackTracker(source: fp2)
var simNow = 0.0
while simNow <= 25 {
    tr2.refresh(now: at(simNow))
    simNow += 0.3
}
eq(tr2.fetchCount, 3, "tracker: 25 detik tick 0,3 detik hanya 3 pengambilan data")

let fp3 = FakePlayer()
fp3.reading?.state = "paused"
let tr3 = PlaybackTracker(source: fp3)
tr3.refresh(now: at(0))
tr3.refresh(now: at(29))
eq(tr3.fetchCount, 1, "tracker: jeda menunggu 30 detik")
tr3.refresh(now: at(30.5))
eq(tr3.fetchCount, 2, "tracker: jeda sinkron setelah 30 detik")
eq(tr3.positionMs(now: at(40)), 5000, "tracker: posisi diam saat jeda")

let fp4 = FakePlayer()
fp4.reading = nil
let tr4 = PlaybackTracker(source: fp4)
tr4.refresh(now: at(0))
check(tr4.failed && tr4.snap == nil, "tracker: gagal bila pemutar tidak membaca")
tr4.refresh(now: at(1)); tr4.refresh(now: at(2.9))
eq(tr4.fetchCount, 1, "tracker: percobaan ulang ditahan 3 detik")
tr4.refresh(now: at(3.1))
eq(tr4.fetchCount, 2, "tracker: mencoba lagi setelah 3 detik")
fp4.reading = PlayerReading(title: "X", durMs: 1000, posMs: 0, state: "playing")
tr4.notify()
tr4.refresh(now: at(3.2))
check(!tr4.failed && tr4.snap?.title == "X", "tracker: pulih setelah pemutar kembali membaca")
tr4.reset()
check(tr4.snap == nil && !tr4.failed, "tracker: reset mengosongkan")
eq(tr4.positionMs(now: at(5)), nil, "tracker: tanpa snap tidak ada posisi")
check(tr4.lastFetchAge(now: at(10)) != nil, "tracker: umur pengambilan terakhir")
eq(PlaybackTracker(source: fp4).lastFetchAge(now: at(0)), nil, "tracker: belum pernah mengambil")

check(PlayerReading(title: "Advertisement", artist: "", adURL: "").isAd, "isAd: judul Advertisement tanpa artis")
check(PlayerReading(title: "x", artist: "y", adURL: "spotify:ad:123").isAd, "isAd: url iklan")
check(!PlayerReading(title: "Advertisement", artist: "Band", adURL: "spotify:track:1").isAd, "isAd: lagu bernama Advertisement dengan artis bukan iklan")
check(!PlayerReading(title: "Lagu", artist: "Artis", adURL: "spotify:track:1").isAd, "isAd: lagu biasa")
eq(Snap(reading: PlayerReading(title: "a", artist: "b", durMs: 9), at: at(0)).durMs, 9, "Snap: dibuat dari pembacaan")

eq(TickRate.interval(running: false, playing: true, isAd: false, menuOpen: true), 2.0, "tickRate: Spotify tidak jalan")
eq(TickRate.interval(running: true, playing: true, isAd: false, menuOpen: false), 0.3, "tickRate: memutar")
eq(TickRate.interval(running: true, playing: false, isAd: false, menuOpen: false), 1.0, "tickRate: jeda melambat")
eq(TickRate.interval(running: true, playing: false, isAd: false, menuOpen: true), 0.3, "tickRate: menu terbuka tetap cepat")
eq(TickRate.interval(running: true, playing: true, isAd: true, menuOpen: false), 0.5, "tickRate: iklan")

let loopLines = [Line(time: 10, text: "a"), Line(time: 20, text: "b"), Line(time: 30, text: "c"), Line(time: 45, text: "d")]
eq(LoopRange.make(lines: loopLines, a: 1, b: 2, duration: 200), LoopRange(startTime: 20, endTime: 45), "loop: akhir = waktu baris setelah B")
eq(LoopRange.make(lines: loopLines, a: 2, b: 1, duration: 200), LoopRange(startTime: 20, endTime: 45), "loop: A dan B tertukar diperbaiki")
eq(LoopRange.make(lines: loopLines, a: 0, b: 0, duration: 200), LoopRange(startTime: 10, endTime: 20), "loop: satu baris")
eq(LoopRange.make(lines: loopLines, a: 2, b: 3, duration: 200), LoopRange(startTime: 30, endTime: 200), "loop: baris terakhir memakai durasi lagu")
eq(LoopRange.make(lines: loopLines, a: 3, b: 3, duration: 0), LoopRange(startTime: 45, endTime: 50), "loop: tanpa durasi memberi 5 detik")
eq(LoopRange.make(lines: loopLines, a: 0, b: 9, duration: 200), nil, "loop: indeks di luar jangkauan")
eq(LoopRange.make(lines: [], a: 0, b: 0, duration: 200), nil, "loop: tanpa lirik")
let lr = LoopRange(startTime: 20, endTime: 45)
check(!lr.shouldWrap(effectivePos: 44.9) && lr.shouldWrap(effectivePos: 45) && lr.shouldWrap(effectivePos: 60), "loop: membungkus tepat di akhir")

let cz = Cloze.make(line: "We could dance until the morning light", lineIndex: 3, pick: { _ in 2 })
check(cz != nil && cz!.prompt.contains(Cloze.blank) && !cz!.prompt.contains(cz!.answer), "cloze: kata diganti kotak isian")
eq(cz?.lineIndex, 3, "cloze: indeks baris terbawa")
eq(Cloze.make(line: "We could dance until the morning light", lineIndex: 0, pick: { _ in 0 })?.answer, "could", "cloze: kata pertama yang cukup panjang (min 3 huruf)")
eq(Cloze.make(line: "We could dance until the morning light", lineIndex: 0, pick: { $0 - 1 })?.answer, "light", "cloze: kata terakhir")
eq(Cloze.make(line: "We could dance until the morning light", lineIndex: 0, pick: { _ in 999 })?.answer, "light", "cloze: pilihan dibatasi ke jangkauan")
eq(Cloze.make(line: "a to be", lineIndex: 0, pick: { _ in 0 }), nil, "cloze: kata pendek tidak jadi soal")
eq(Cloze.make(line: "", lineIndex: 0, pick: { _ in 0 }), nil, "cloze: baris kosong")
let kz = Cloze.make(line: "이제는 땅만 보고 걷잖아", lineIndex: 0, pick: { _ in 1 })
check(kz != nil && kz!.answer.contains(where: { $0.isLetter }) && kz!.prompt.contains(Cloze.blank), "cloze: Korea")
let jz = Cloze.make(line: "君の名前を呼んだ", lineIndex: 0, pick: { _ in 0 })
check(jz != nil && jz!.prompt.contains(Cloze.blank) && jz!.prompt.count < "君の名前を呼んだ".count + 6, "cloze: Jepang (tanpa spasi) tetap bisa")
check(Cloze.matches(answer: "Café", input: "cafe"), "matches: abaikan aksen dan huruf besar")
check(Cloze.matches(answer: "light", input: " Light! "), "matches: abaikan spasi dan tanda baca")
check(Cloze.matches(answer: "abc", input: "ＡＢＣ"), "matches: abaikan lebar huruf")
check(!Cloze.matches(answer: "light", input: "night"), "matches: jawaban salah")
check(!Cloze.matches(answer: "light", input: ""), "matches: kosong salah")
check(!Cloze.matches(answer: "light", input: "  !! "), "matches: hanya tanda baca salah")
let elig = Cloze.eligible(lines: ["♪", "", "Oh", "We could dance until the morning light", "so so", "Take me to the place where we belong"])
eq(elig, [3, 5], "cloze: hanya baris yang cukup panjang yang layak")

eq(LyricsExport.clock(0), "00:00:00,000", "clock: nol")
eq(LyricsExport.clock(61.5), "00:01:01,500", "clock: menit dan milidetik")
eq(LyricsExport.clock(3723.042), "01:02:03,042", "clock: jam")
eq(LyricsExport.clock(-5), "00:00:00,000", "clock: negatif jadi nol")
let exLines = [Line(time: 1, text: "Satu"), Line(time: 4, text: "♪"), Line(time: 6, text: "Dua"), Line(time: 30, text: "Tiga")]
let srtOut = LyricsExport.srt(lines: exLines, duration: 40)
check(srtOut.hasPrefix("1\n00:00:01,000 --> 00:00:04,000\nSatu\n"), "srt: cue pertama berakhir di baris berikutnya")
check(srtOut.contains("2\n00:00:06,000 --> 00:00:14,000\nDua"), "srt: cue dibatasi 8 detik saat jeda panjang")
check(srtOut.contains("3\n00:00:30,000 --> 00:00:38,000\nTiga"), "srt: cue terakhir dibatasi 8 detik dari durasi")
check(!srtOut.contains("♪"), "srt: baris instrumental dilewati")
eq(srtOut.components(separatedBy: " --> ").count - 1, 3, "srt: tiga cue, penomoran berurutan")
check(srtOut.hasSuffix("\n"), "srt: diakhiri baris baru")
let srtTr = LyricsExport.srt(lines: [Line(time: 1, text: "Hi"), Line(time: 3, text: "Bye")], translations: ["Halo", ""], romaji: ["hai", ""], duration: 10)
check(srtTr.contains("Hi\nhai\nHalo"), "srt: asli, cara baca, lalu terjemahan")
check(srtTr.contains("2\n00:00:03,000 --> 00:00:10,000\nBye\n") || srtTr.contains("Bye"), "srt: baris tanpa terjemahan tetap ada")
eq(LyricsExport.srt(lines: [], duration: 10), "", "srt: tanpa lirik")
eq(LyricsExport.srt(lines: [Line(time: 1, text: "x"), Line(time: 1.1, text: "y")], duration: 0).components(separatedBy: " --> ")[1].prefix(12), "00:00:01,300", "srt: durasi cue minimal 0,3 detik")
eq(LyricsExport.text(lines: [Line(time: 1, text: "A"), Line(time: 2, text: "B")]), "A\nB", "text: polos tanpa tambahan")
eq(LyricsExport.text(lines: [Line(time: 1, text: "A"), Line(time: 2, text: "B")], translations: ["a", "b"]), "A\na\n\nB\nb", "text: pasangan dipisah baris kosong")
eq(LyricsExport.text(lines: [Line(time: 1, text: "A"), Line(time: 2, text: "♪"), Line(time: 3, text: "B")], translations: ["a", "", "b"]), "A\na\n\nB\nb", "text: instrumental dilewati saat ada terjemahan")
eq(LyricsExport.block(text: "T", romaji: "r", translation: "x"), "T\nr\nx", "block: tiga baris")
eq(LyricsExport.block(text: "T"), "T", "block: hanya asli")
check(LyricsExport.isBlank("  ♪ ") && LyricsExport.isBlank("") && !LyricsExport.isBlank("a"), "isBlank")
eq(LyricsExport.fileName(artist: "AC/DC", title: "Back: In Black?", ext: "srt"), "AC_DC - Back_ In Black_.srt", "fileName: karakter terlarang diganti")
eq(LyricsExport.fileName(artist: "", title: "", ext: "txt"), "lyrics.txt", "fileName: kosong")
eq(LyricsExport.fileName(artist: "", title: "Solo", ext: "txt"), "Solo.txt", "fileName: tanpa artis")
check(LyricsExport.fileName(artist: String(repeating: "a", count: 300), title: "b", ext: "srt").count <= 124, "fileName: dibatasi panjangnya")
check(Prefs.menuBarCover, "Prefs: cover menu bar aktif bawaan")
UserDefaults.standard.set(false, forKey: "menuBarCover")
check(!Prefs.menuBarCover, "Prefs: cover menu bar bisa dimatikan")
UserDefaults.standard.removeObject(forKey: "menuBarCover")

let kc = KeyCombo(code: 37, modifiers: KeyCombo.control | KeyCombo.option)
eq(kc.display, "⌃⌥L", "keycombo: tampilan ⌃⌥L")
eq(KeyCombo(code: 33, modifiers: KeyCombo.control | KeyCombo.option).display, "⌃⌥[", "keycombo: tanda baca")
eq(KeyCombo(code: 49, modifiers: KeyCombo.command | KeyCombo.shift).display, "⇧⌘Space", "keycombo: urutan ⌃⌥⇧⌘")
eq(KeyCombo(code: 123, modifiers: KeyCombo.control | KeyCombo.option | KeyCombo.shift | KeyCombo.command).display, "⌃⌥⇧⌘←", "keycombo: semua pengubah")
eq(KeyCombo(code: 200, modifiers: KeyCombo.command).display, "⌘#200", "keycombo: kode tak dikenal")
check(kc.hasRequiredModifier, "keycombo: ⌃⌥ cukup")
check(!KeyCombo(code: 37, modifiers: 0).hasRequiredModifier, "keycombo: tanpa pengubah ditolak")
check(!KeyCombo(code: 37, modifiers: KeyCombo.shift).hasRequiredModifier, "keycombo: hanya shift ditolak")
check(KeyCombo(code: 37, modifiers: KeyCombo.command).hasRequiredModifier, "keycombo: ⌘ saja cukup")
eq(KeyCombo(storage: kc.storage), kc, "keycombo: simpan lalu baca")
check(KeyCombo(storage: [1]) == nil && KeyCombo(storage: [-1, 5]) == nil && KeyCombo(storage: []) == nil, "keycombo: data rusak ditolak")
for code: UInt32 in [0, 11, 37, 49, 53, 122, 126] { check(KeyCombo.keyName(code) != nil, "keycombo: nama untuk kode \(code)") }
let cur: [Int: KeyCombo] = [1: kc, 2: KeyCombo(code: 17, modifiers: KeyCombo.control | KeyCombo.option)]
eq(HotKeyRules.conflict(for: KeyCombo(code: 17, modifiers: KeyCombo.control | KeyCombo.option), excluding: 1, current: cur), 2, "bentrok: dengan aksi lain")
eq(HotKeyRules.conflict(for: kc, excluding: 1, current: cur), nil, "bentrok: dengan dirinya sendiri tidak dihitung")
eq(HotKeyRules.conflict(for: KeyCombo(code: 5, modifiers: KeyCombo.command), excluding: 1, current: cur), nil, "bentrok: kombinasi bebas")
let dflt = KeyCombo(code: 37, modifiers: KeyCombo.control | KeyCombo.option)
eq(Prefs.hotKeyCombo(id: 99, default: dflt), dflt, "prefs hotkey: bawaan")
check(!Prefs.hasCustomHotKey(id: 99), "prefs hotkey: belum diubah")
Prefs.setHotKeyCombo(id: 99, KeyCombo(code: 8, modifiers: KeyCombo.command))
eq(Prefs.hotKeyCombo(id: 99, default: dflt), KeyCombo(code: 8, modifiers: KeyCombo.command), "prefs hotkey: pilihan tersimpan")
check(Prefs.hasCustomHotKey(id: 99), "prefs hotkey: ditandai diubah")
Prefs.setHotKeyCombo(id: 99, nil)
eq(Prefs.hotKeyCombo(id: 99, default: dflt), dflt, "prefs hotkey: kembali ke bawaan")
Prefs.setHotKeyCombo(id: 1, KeyCombo(code: 1, modifiers: KeyCombo.command))
Prefs.resetHotKeys()
check(!Prefs.hasCustomHotKey(id: 1), "prefs hotkey: atur ulang semua")
eq(AutomationState(osStatus: 0), .granted, "automasi: 0 diizinkan")
eq(AutomationState(osStatus: -1743), .denied, "automasi: -1743 ditolak")
eq(AutomationState(osStatus: -1744), .notAsked, "automasi: -1744 belum diminta")
eq(AutomationState(osStatus: -600), .appNotRunning, "automasi: -600 app tidak jalan")
eq(AutomationState(osStatus: -50), .unknown(-50), "automasi: lainnya")
eq(AutomationState.granted.label, "granted", "automasi: label")
eq(AutomationState.unknown(-50).label, "unknown (-50)", "automasi: label tak dikenal")
check(Setup.isComplete(spotifyRunning: true, automation: .granted, targetChosen: true), "setup: lengkap")
check(!Setup.isComplete(spotifyRunning: true, automation: .denied, targetChosen: true), "setup: izin ditolak tidak lengkap")
eq(Setup.completed(spotifyRunning: false, automation: .appNotRunning, targetChosen: true), 1, "setup: hanya bahasa tujuan")
eq(Setup.completed(spotifyRunning: false, automation: .notAsked, targetChosen: false), 0, "setup: belum ada yang selesai")
check(!Prefs.setupDone, "prefs: setup belum selesai")
Prefs.setupDone = true
check(Prefs.setupDone, "prefs: setup selesai tersimpan")
UserDefaults.standard.removeObject(forKey: "setupDone")

eq(Lyrics.plainLines("a\nb\n\n\n\nc\n").map { $0.text }, ["a", "b", "", "c"], "plain: baris kosong beruntun diringkas, ekor dibuang")
eq(Lyrics.plainLines("\n\n  x  \n").map { $0.text }, ["x"], "plain: kosong di awal dibuang dan spasi dipangkas")
eq(Lyrics.plainLines("").count, 0, "plain: kosong")
check(Lyrics.plainLines("a\nb").allSatisfy { $0.time == 0 }, "plain: tanpa waktu")
let cSyncNative = Lyrics.Candidate(lines: [Line(time: 1, text: "s1")], native: true, synced: true)
let cSyncLatin = Lyrics.Candidate(lines: [Line(time: 1, text: "s2")], native: false, synced: true)
let cPlainNative = Lyrics.Candidate(lines: [Line(time: 0, text: "p1")], native: true, synced: false)
let cPlainLatin = Lyrics.Candidate(lines: [Line(time: 0, text: "p2")], native: false, synced: false)
eq(Lyrics.choose(strict: [cPlainNative, cSyncLatin], loose: []), cSyncLatin, "choose: tersinkron mengalahkan tanpa timestamp walau tidak beraksara asli")
eq(Lyrics.choose(strict: [cSyncLatin, cSyncNative], loose: []), cSyncNative, "choose: tersinkron beraksara asli diutamakan")
eq(Lyrics.choose(strict: [cPlainLatin], loose: [cSyncLatin]), cSyncLatin, "choose: tersinkron durasi lain mengalahkan tanpa timestamp durasi cocok")
eq(Lyrics.choose(strict: [], loose: [cPlainLatin, cPlainNative]), cPlainNative, "choose: tanpa timestamp beraksara asli diutamakan")
eq(Lyrics.choose(strict: [cPlainLatin], loose: []), cPlainLatin, "choose: hanya tanpa timestamp")
eq(Lyrics.choose(strict: [], loose: []), nil, "choose: tidak ada kandidat")
let oldJSON = "{\"saved\": 0, \"lines\": [{\"time\": 1, \"text\": \"x\"}]}".data(using: .utf8)!
let oldCache = try? JSONDecoder().decode(CachedLyrics.self, from: oldJSON)
check(oldCache != nil && oldCache!.isSynced, "cache lama tanpa kolom synced dianggap tersinkron")
Store.writeLyrics("__tes_plain__|x|1", [Line(time: 0, text: "p")], synced: false)
check(Store.readLyrics("__tes_plain__|x|1")?.isSynced == false, "cache: tanpa timestamp tersimpan")
Store.writeLyrics("__tes_plain__|x|1", [Line(time: 0, text: "p")])
check(Store.readLyrics("__tes_plain__|x|1")?.isSynced == true, "cache: bawaan tersinkron")
try? FileManager.default.removeItem(at: Store.lyricsFile("__tes_plain__|x|1"))
eq(LyricsResult.empty.lines.count, 0, "LyricsResult.empty")

eq(Speech.voiceLanguage(for: "ko"), "ko-KR", "speech: Korea")
eq(Speech.voiceLanguage(for: "ja"), "ja-JP", "speech: Jepang")
eq(Speech.voiceLanguage(for: "en"), "en-US", "speech: Inggris")
eq(Speech.voiceLanguage(for: "id"), "id-ID", "speech: Indonesia")
eq(Speech.voiceLanguage(for: "pt-BR"), "pt-BR", "speech: kode dengan wilayah memakai bahasa dasarnya")
eq(Speech.voiceLanguage(for: "en-GB"), "en-US", "speech: variasi Inggris")
eq(Speech.voiceLanguage(for: "zh"), "zh-CN", "speech: Mandarin sederhana")
eq(Speech.voiceLanguage(for: "zh-TW"), "zh-TW", "speech: Mandarin tradisional")
eq(Speech.voiceLanguage(for: "zh-Hant"), "zh-TW", "speech: aksara tradisional")
eq(Speech.voiceLanguage(for: "xx"), nil, "speech: bahasa tak dikenal")
eq(Speech.voiceLanguage(for: ""), nil, "speech: kosong")
for id in Prefs.supportedTargets { check(Speech.voiceLanguage(for: id) != nil, "speech: semua bahasa tujuan punya peta suara (\(id))") }
eq(Speech.prepare("  halo   dunia \n kamu "), "halo dunia kamu", "speech: spasi dirapikan")
eq(Speech.prepare("♪"), "", "speech: not tidak diucapkan")
eq(Speech.prepare("   "), "", "speech: kosong")

let sp: PlayerID = .spotify, mu: PlayerID = .music
eq(PlayerChoice.pick(setting: "spotify", current: mu, running: [sp: false, mu: true], playing: [:]), sp, "pemutar: dipaksa Spotify walau tidak jalan")
eq(PlayerChoice.pick(setting: "music", current: sp, running: [sp: true, mu: false], playing: [:]), mu, "pemutar: dipaksa Music")
eq(PlayerChoice.pick(setting: "auto", current: sp, running: [sp: false, mu: true], playing: [:]), mu, "pemutar auto: hanya Music berjalan")
eq(PlayerChoice.pick(setting: "auto", current: mu, running: [sp: true, mu: false], playing: [:]), sp, "pemutar auto: hanya Spotify berjalan")
eq(PlayerChoice.pick(setting: "auto", current: mu, running: [sp: false, mu: false], playing: [:]), mu, "pemutar auto: tidak ada yang jalan mempertahankan yang aktif")
eq(PlayerChoice.pick(setting: "auto", current: sp, running: [sp: true, mu: true], playing: [sp: true, mu: true]), sp, "pemutar auto: keduanya memutar, tetap yang aktif")
eq(PlayerChoice.pick(setting: "auto", current: sp, running: [sp: true, mu: true], playing: [sp: false, mu: true]), mu, "pemutar auto: pindah ke yang sedang memutar")
eq(PlayerChoice.pick(setting: "auto", current: mu, running: [sp: true, mu: true], playing: [sp: true, mu: false]), sp, "pemutar auto: pindah balik ke Spotify")
eq(PlayerChoice.pick(setting: "auto", current: sp, running: [sp: true, mu: true], playing: [sp: false, mu: false]), sp, "pemutar auto: keduanya jeda, tetap")
eq(PlayerChoice.pick(setting: "auto", current: sp, running: [sp: true, mu: true], playing: [:]), sp, "pemutar auto: status tak diketahui, tetap")
eq(PlayerChoice.pick(setting: "xyz", current: mu, running: [sp: true, mu: true], playing: [mu: true]), mu, "pemutar: pengaturan tak dikenal dianggap auto")
eq(PlayerID.spotify.bundleID, "com.spotify.client", "PlayerID: bundle Spotify")
eq(PlayerID.music.bundleID, "com.apple.Music", "PlayerID: bundle Music")
eq(PlayerID.music.displayName, "Apple Music", "PlayerID: nama Music")
let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
eq(ImageData.trimmed(png), png, "gambar: PNG polos tidak diubah")
eq(ImageData.trimmed(Data([0, 0, 0, 0, 0x89, 0x50, 0x4E, 0x47, 9])), Data([0x89, 0x50, 0x4E, 0x47, 9]), "gambar: header sebelum PNG dibuang")
eq(ImageData.trimmed(Data(repeating: 7, count: 22) + Data([0xFF, 0xD8, 0xFF, 0xE0, 5])), Data([0xFF, 0xD8, 0xFF, 0xE0, 5]), "gambar: header sebelum JPEG dibuang")
eq(ImageData.trimmed(Data([0x49, 0x49, 0x2A, 0x00, 1])), Data([0x49, 0x49, 0x2A, 0x00, 1]), "gambar: TIFF dikenali")
eq(ImageData.trimmed(Data([1, 2, 3, 4])), Data([1, 2, 3, 4]), "gambar: tanda tak dikenal dibiarkan")
eq(ImageData.trimmed(Data()), Data(), "gambar: kosong")
UserDefaults.standard.removeObject(forKey: "playerChoice")
eq(Prefs.playerChoice, "auto", "Prefs: pemutar bawaan auto")
Prefs.playerChoice = "music"
eq(Prefs.playerChoice, "music", "Prefs: pemutar tersimpan")
UserDefaults.standard.removeObject(forKey: "playerChoice")

let cleanCases: [(String, String)] = [
    ("Bohemian Rhapsody - Remastered 2011", "Bohemian Rhapsody"),
    ("Don't Stop Believin' (2022 Remaster)", "Don't Stop Believin'"),
    ("Yesterday - Remastered 2009", "Yesterday"),
    ("Hold Me Closer (feat. Elton John)", "Hold Me Closer"),
    ("Stay (with Justin Bieber)", "Stay"),
    ("Levitating (feat. DaBaby)", "Levitating"),
    ("Song Name feat. Someone", "Song Name"),
    ("Song Name ft. Someone Else", "Song Name"),
    ("Blinding Lights - Radio Edit", "Blinding Lights"),
    ("Let It Go - From \"Frozen\"", "Let It Go"),
    ("Hotel California - Live at the Forum", "Hotel California"),
    ("Hello [Remastered]", "Hello"),
    ("Title (Live)", "Title"),
    ("Title (Radio Edit)", "Title"),
    ("Title (Explicit)", "Title"),
    ("Judul – Single Version", "Judul"),
    ("  Spasi   Ganda  ", "Spasi Ganda")
]
for (a, b2) in cleanCases { eq(TrackName.cleanTitle(a), b2, "cleanTitle: \(a)") }
let keepCases = ["Love Story (Taylor's Version)", "봄날 (Korean Ver.)", "Dynamite (Japanese Version)", "Stay With Me", "With or Without You", "Live Forever", "Mono", "Song (Acoustic)", "Heaven (Remix)", "Bad Guy", "Everything U Are"]
for k in keepCases { eq(TrackName.cleanTitle(k), k, "cleanTitle: dipertahankan \(k)") }
eq(TrackName.cleanTitle("(Live)"), "(Live)", "cleanTitle: tidak boleh jadi kosong")
eq(TrackName.cleanTitle("It’s Time"), "It's Time", "cleanTitle: tanda kutip lengkung diluruskan")
eq(TrackName.firstArtist("The Weeknd, Daft Punk", separators: [","]), "The Weeknd", "firstArtist: koma")
eq(TrackName.firstArtist("A; B", separators: [";"]), "A", "firstArtist: titik koma")
eq(TrackName.firstArtist("Solo", separators: [","]), "Solo", "firstArtist: satu artis")
eq(TrackName.firstArtist("Ayu & Budi", separators: [" & "]), "Ayu", "firstArtist: ampersand")
let vs = TrackName.variants(title: "Closer - Remastered 2016", artist: "The Chainsmokers, Halsey")
eq(vs.first, TrackName.Variant(title: "Closer", artist: "The Chainsmokers, Halsey"), "variants: judul bersih dengan artis asli dulu")
check(vs.contains(TrackName.Variant(title: "Closer", artist: "The Chainsmokers")), "variants: judul bersih dengan artis pertama")
check(vs.contains(TrackName.Variant(title: "Closer - Remastered 2016", artist: "The Chainsmokers")), "variants: judul asli dengan artis pertama")
check(!vs.contains(TrackName.Variant(title: "Closer - Remastered 2016", artist: "The Chainsmokers, Halsey")), "variants: tidak memuat pasangan asli")
eq(TrackName.variants(title: "Shape of You", artist: "Ed Sheeran").count, 0, "variants: judul dan artis bersih tidak punya variasi")
check(TrackName.variants(title: "A (feat. B)", artist: "X, Y & Z", limit: 2).count <= 2, "variants: dibatasi")
eq(Set(TrackName.variants(title: "A (feat. B)", artist: "X, Y").map { $0.title + "|" + $0.artist }).count, TrackName.variants(title: "A (feat. B)", artist: "X, Y").count, "variants: tanpa duplikat")
check(TrackName.similar("Bohemian Rhapsody - Remastered 2011", "Bohemian Rhapsody"), "similar: abaikan embel-embel")
check(TrackName.similar("HELLO", "hello (live)"), "similar: huruf besar dan embel-embel")
check(TrackName.similar("Café del Mar", "cafe del mar"), "similar: aksen")
check(TrackName.similar("Love Story", "Love Story (Taylor's Version)"), "similar: mengandung")
check(!TrackName.similar("Bohemian Rhapsody", "Another One Bites the Dust"), "similar: lagu berbeda")
check(!TrackName.similar("A", "A"), "similar: terlalu pendek tidak dianggap")
check(TrackName.similar("봄날", "봄날"), "similar: Hangul")

eq(Lyrics.reply(for: 200), .found, "reply: 200 ditemukan")
eq(Lyrics.reply(for: 404), .notFound, "reply: 404 tidak ada (jawaban pasti)")
eq(Lyrics.reply(for: 429), .retry, "reply: 429 dicoba ulang, bukan 'tidak ada'")
eq(Lyrics.reply(for: 500), .retry, "reply: 500 dicoba ulang")
eq(Lyrics.reply(for: 503), .retry, "reply: 503 dicoba ulang")
eq(Lyrics.reply(for: 403), .failed, "reply: 403 gagal")
eq(Lyrics.reply(for: 301), .failed, "reply: pengalihan tidak dianggap jawaban")

check(PlayerReading(title: "Ep 12", artist: "Show", adURL: "spotify:episode:abc").isEpisode, "episode: url episode")
check(!PlayerReading(title: "Lagu", artist: "A", adURL: "spotify:track:abc").isEpisode, "episode: lagu biasa bukan episode")
check(!PlayerReading(title: "File", artist: "A", adURL: "spotify:local:a:b:c:1").isEpisode, "episode: berkas lokal tetap dicari liriknya")
check(!PlayerReading(title: "x", artist: "y", adURL: "spotify:ad:1").isEpisode, "episode: iklan bukan episode")
check(PlayerReading(title: "x", artist: "y", adURL: "spotify:ad:1").isAd, "episode: iklan tetap terdeteksi")
check(Snap(reading: PlayerReading(title: "Ep", artist: "S", adURL: "spotify:episode:z"), at: Date()).isEpisode, "episode: Snap meneruskan")
check(!PlayerReading(title: "Ep", artist: "S", adURL: "").isEpisode, "episode: tanpa url bukan episode (Apple Music)")

func optJSON(id: Int, track: String = "T", artist: String = "A", album: String = "B", duration: Double? = 200, synced: String? = nil, plain: String? = nil, instrumental: Bool = false) -> [String: Any] {
    var j: [String: Any] = ["id": id, "trackName": track, "artistName": artist, "albumName": album, "instrumental": instrumental]
    if let d = duration { j["duration"] = d }
    if let s = synced { j["syncedLyrics"] = s }
    if let p = plain { j["plainLyrics"] = p }
    return j
}
let oSync = LyricsOption.from(json: optJSON(id: 1, synced: "[00:01.00] satu\n[00:05.00] dua"))
check(oSync != nil && oSync!.synced && oSync!.lines.count == 2, "option: tersinkron")
let oPlain = LyricsOption.from(json: optJSON(id: 2, plain: "satu\ndua\ntiga"))
check(oPlain != nil && !oPlain!.synced && oPlain!.lines.count == 3, "option: teks polos")
eq(LyricsOption.from(json: optJSON(id: 3, instrumental: true)), nil, "option: instrumental dilewati")
eq(LyricsOption.from(json: optJSON(id: 4)), nil, "option: tanpa lirik dilewati")
eq(LyricsOption.from(json: optJSON(id: 5, plain: "\n\n")), nil, "option: hanya baris kosong dilewati")
eq(LyricsOption.from(json: optJSON(id: 6, synced: "bukan lrc", plain: "satu\ndua"))?.synced, false, "option: LRC rusak jatuh ke teks polos")
check(LyricsOption.from(json: optJSON(id: 7, synced: "[00:01.00] 사랑해\n[00:02.00] 너무 좋아"))?.native == true, "option: aksara asli terdeteksi")
check(LyricsOption.from(json: ["trackName": "X", "plainLyrics": "a\nb"])?.id == -1, "option: tanpa id memakai -1")
eq(oSync?.durationDiff(from: 198), 2.0, "option: selisih durasi")
eq(oSync?.durationDiff(from: 0), nil, "option: tanpa durasi target")
eq(LyricsOption.from(json: optJSON(id: 8, duration: nil, plain: "a\nb"))?.durationDiff(from: 200), nil, "option: tanpa durasi opsi")
eq(LyricsOption.from(json: optJSON(id: 9, synced: "[00:01.00] a\n[00:02.00] b\n[00:03.00] c\n[00:04.00] d\n[00:05.00] e\n[00:06.00] f\n[00:07.00] g"))?.preview.components(separatedBy: "\n").count, 6, "option: pratinjau enam baris")
let r1 = LyricsOption.from(json: optJSON(id: 10, duration: 230, synced: "[00:01.00] x"))!
let r2 = LyricsOption.from(json: optJSON(id: 11, duration: 201, synced: "[00:01.00] x"))!
let r3 = LyricsOption.from(json: optJSON(id: 12, duration: 200, plain: "a\nb"))!
let r4 = LyricsOption.from(json: optJSON(id: 13, duration: nil, synced: "[00:01.00] x"))!
eq(LyricsOption.ranked([r3, r1, r4, r2], target: 200).map { $0.id }, [11, 10, 13, 12], "ranked: tersinkron dulu, lalu selisih durasi, tanpa durasi terakhir, teks polos di akhir")
eq(LyricsOption.ranked([r2, r2, r1], target: 200).map { $0.id }, [11, 10], "ranked: id ganda dibuang")
eq(LyricsOption.ranked([], target: 200).count, 0, "ranked: kosong")
check(r2.matches(current: r2.lines) && !r2.matches(current: r1.lines + r1.lines) && !r2.matches(current: []), "option: cocok dengan lirik yang dipakai")
eq(Lyrics.cacheKey(artist: "A", title: "T", duration: 200), "A|T|200", "cacheKey")
Store.writeLyrics("__tes_pin__|x|1", [Line(time: 1, text: "p")], synced: true, pinned: true)
check(Store.readLyrics("__tes_pin__|x|1")?.isPinned == true, "cache: sematan tersimpan")
Store.writeLyrics("__tes_pin__|x|1", [Line(time: 1, text: "p")])
check(Store.readLyrics("__tes_pin__|x|1")?.isPinned == false, "cache: bawaan tidak disematkan")
Lyrics.pin("__tes_pin__|x|1", r2)
check(Store.readLyrics("__tes_pin__|x|1")?.isPinned == true && Store.readLyrics("__tes_pin__|x|1")?.lines.count == r2.lines.count, "pin: menyimpan lirik pilihan")
Lyrics.unpin("__tes_pin__|x|1")
check(Store.readLyrics("__tes_pin__|x|1") == nil, "unpin: menghapus cache")

let kanaCases: [(String, String)] = [
    ("君の名前を呼んだ", "きみのなまえをよんだ"), ("諦めたものと賢いものだけが", "あきらめたものとかしこいものだけが"),
    ("今日も明日も", "きょうもあすも"), ("お金がない", "おかねがない"), ("永遠の隙間でのたうち回ってる", "えいえんのすきまでのたうちまわってる"),
    ("ぼくは君が好きだよ", "ぼくはきみがすきだよ")
]
for (a, k) in kanaCases { eq(Readings.japaneseKana(a), k, "kana: \(a)") }
func rubyText(_ s: String) -> String { Readings.japaneseRuby(s).map { "\($0.base)\($0.reading.map { "[\($0)]" } ?? "")" }.joined(separator: " ") }
eq(rubyText("君の名前を呼んだ"), "君[きみ] の 名前[なまえ] を 呼[よ] ん だ", "ruby: okurigana dipotong (呼ん)")
eq(rubyText("諦めたものと賢いものだけが"), "諦[あきら] め た もの と 賢[かしこ] い もの だけ が", "ruby: 諦め dan 賢い")
eq(rubyText("お金がない"), "お 金[かね] が ない", "ruby: awalan kana dipotong (お金)")
eq(rubyText("今日も明日も"), "今日[きょう] も 明日[あす] も", "ruby: kata kanji murni utuh")
check(rubyText("永遠の隙間でのたうち回ってる").contains("回[まわ] っ"), "ruby: っ kecil tidak berubah jadi つ")
check(Readings.japaneseRuby("ぼくはきみがすき").allSatisfy { $0.reading == nil }, "ruby: lirik kana murni tanpa furigana")
eq(Readings.japaneseRuby("").count, 0, "ruby: kosong")
eq(Readings.japaneseKana("Hello 君"), "Hello きみ", "kana: teks Latin dibiarkan")
check(Readings.japaneseRuby("君 の").contains(where: { $0.base == " " }), "ruby: spasi dipertahankan sebagai token")
let sp1 = Readings.splitOkurigana(base: "賢い", reading: "かしこい")
eq(sp1.base, "賢", "okurigana: pangkal"); eq(sp1.reading, "かしこ", "okurigana: bacaan pangkal"); eq(sp1.suffix, "い", "okurigana: akhiran")
let sp2 = Readings.splitOkurigana(base: "お金", reading: "おかね")
eq(sp2.prefix, "お", "okurigana: awalan"); eq(sp2.base, "金", "okurigana: pangkal setelah awalan")
let sp3 = Readings.splitOkurigana(base: "今日", reading: "きょう")
check(sp3.prefix.isEmpty && sp3.suffix.isEmpty && sp3.base == "今日", "okurigana: tanpa kana tidak berubah")
let sp4 = Readings.splitOkurigana(base: "い", reading: "い")
eq(sp4.base, "い", "okurigana: satu huruf tidak dipotong habis")
eq(Readings.romanize("你好吗 我爱你", lang: "zh-Hans"), "nǐ hǎo ma wǒ ài nǐ", "pinyin: sederhana")
eq(Readings.romanize("我愛你到永遠", lang: "zh-Hant"), "wǒ ài nǐ dào yǒng yuǎn", "pinyin: tradisional")
eq(Readings.romanize("你好", lang: "zh"), "nǐ hǎo", "pinyin: kode zh")
eq(Readings.romanize("Я тебя люблю", lang: "ru"), "Ya tebya lyublyu", "Rusia")
eq(Readings.romanize("Щи и борщ", lang: "ru"), "Shchi i borshch", "Rusia: щ dan huruf besar")
eq(Readings.romanize("Привіт, як справи", lang: "uk"), "Pryvit, yak spravy", "Ukraina")
eq(Readings.romanize("Гарний ґанок", lang: "uk"), "Harnyy ganok", "Ukraina: г dan ґ")
eq(Readings.romanize("Γειά σου κόσμε", lang: "el"), "Geia sou kosme", "Yunani")
eq(Readings.romanize("مرحبا", lang: "ar"), "", "Arab sengaja tidak didukung")
eq(Readings.romanize("สวัสดี", lang: "th"), "", "Thai sengaja tidak didukung")
eq(Readings.romanize("hello world", lang: "ru"), "", "Rusia: teks Latin tidak diubah")
eq(Readings.romanize("hello", lang: "zh"), "", "Mandarin: teks Latin tidak diubah")
eq(Readings.romanize("hello", lang: "en"), "", "bahasa tanpa cara baca")
eq(Readings.reading("君の名前を呼んだ", lang: "ja", style: "furigana"), "きみのなまえをよんだ", "reading: furigana Jepang")
eq(Readings.reading("ぼくはきみ", lang: "ja", style: "furigana"), "", "reading: furigana kosong bila tanpa kanji")
eq(Readings.reading("君の名前を呼んだ", lang: "ja", style: "romaji"), "kimi no namae o yon da", "reading: romaji Jepang")
eq(Readings.reading("사랑해", lang: "ko", style: "furigana"), "saranghae", "reading: Korea tidak terpengaruh gaya")
eq(Readings.reading("你好", lang: "zh-Hans", style: "furigana"), "nǐ hǎo", "reading: Mandarin tidak terpengaruh gaya")
check(Readings.hasHan("今日") && !Readings.hasHan("きょう") && !Readings.hasHan("abc"), "hasHan")
check(Readings.hasCyrillic("Привет") && !Readings.hasCyrillic("Privet"), "hasCyrillic")
eq(Prefs.readingStyle, "romaji", "Prefs: gaya bacaan bawaan romaji")
Prefs.readingStyle = "furigana"
eq(Prefs.readingStyle, "furigana", "Prefs: gaya bacaan tersimpan")
UserDefaults.standard.removeObject(forKey: "readingStyle")

eq(AnkiPackage.checksum("abc"), Int(0xa9993e36), "anki: checksum = 8 hex pertama SHA1")
eq(AnkiPackage.sha1Hex("abc"), "a9993e364706816aba3e25717850c26c9cd0d89d", "anki: SHA1 benar")
eq(AnkiPackage.htmlEscape("a & <b>\nz"), "a &amp; &lt;b&gt;<br>z", "anki: HTML di-escape dan baris baru jadi <br>")
eq(AnkiPackage.htmlEscape("x\r\ny"), "x<br>y", "anki: CRLF")
let nA = AnkiNote(word: "Light", meaning: "cahaya", line: "the light", song: "A - B", wordAudio: "w.m4a", lineAudio: nil)
eq(AnkiPackage.guid(for: nA), AnkiPackage.guid(for: AnkiNote(word: "light", meaning: "lain", line: "x", song: "A - B", wordAudio: nil, lineAudio: nil)), "anki: guid stabil (abaikan huruf besar dan arti)")
check(AnkiPackage.guid(for: nA) != AnkiPackage.guid(for: AnkiNote(word: "Light", meaning: "", line: "", song: "C - D", wordAudio: nil, lineAudio: nil)), "anki: guid berbeda untuk lagu lain")
eq(AnkiPackage.guid(for: nA).count, 10, "anki: guid 10 karakter")
eq(AnkiPackage.fields(nA), ["Light", "cahaya", "the light", "A - B", "[sound:w.m4a]", ""], "anki: enam bidang dengan referensi suara")
eq(AnkiPackage.fieldNames.count, 6, "anki: nama bidang")
let modelObj = AnkiPackage.modelObject(modelID: 5, deckID: 6, now: 7)
check((modelObj["flds"] as? [Any])?.count == 6 && (modelObj["tmpls"] as? [Any])?.count == 1 && modelObj["did"] as? Int == 6, "anki: model memuat 6 bidang, 1 templat, dek")
let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("spotlyrics-test-\(UUID().uuidString)", isDirectory: true)
try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
let fakeAudio = tmpDir.appendingPathComponent("a.m4a")
try? Data(repeating: 1, count: 300).write(to: fakeAudio)
let apkg = tmpDir.appendingPathComponent("t.apkg")
var apkgOK = true
do {
    try AnkiPackage.write(notes: [nA, AnkiNote(word: "gelap", meaning: "dark\nsatu", line: "", song: "C - D", wordAudio: nil, lineAudio: nil)],
                          media: [AnkiMedia(name: "w.m4a", url: fakeAudio)], to: apkg, now: Date(timeIntervalSince1970: 1_700_000_000))
} catch { apkgOK = false }
check(apkgOK && FileManager.default.fileExists(atPath: apkg.path), "anki: paket dibuat")
let unz = tmpDir.appendingPathComponent("x", isDirectory: true)
let uz = Process()
uz.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
uz.arguments = ["-q", apkg.path, "-d", unz.path]
try? uz.run()
uz.waitUntilExit()
eq(uz.terminationStatus, 0, "anki: arsip bisa dibuka unzip")
let listing = (try? FileManager.default.contentsOfDirectory(atPath: unz.path).sorted()) ?? []
eq(listing, ["0", "collection.anki2", "media"], "anki: isi arsip (database, peta media, satu berkas media)")
let mediaMap = ((try? JSONSerialization.jsonObject(with: Data(contentsOf: unz.appendingPathComponent("media")))) as? [String: String]) ?? [:]
eq(mediaMap, ["0": "w.m4a"], "anki: peta media")
eq((try? Data(contentsOf: unz.appendingPathComponent("0")))?.count, 300, "anki: isi berkas media tersalin")
let sum = AnkiPackage.summary(ofCollection: unz.appendingPathComponent("collection.anki2").path)
eq(sum?.notes, 2, "anki: dua catatan")
eq(sum?.cards, 2, "anki: dua kartu")
eq(sum?.version, "11", "anki: versi skema 11")
eq(sum?.modelFieldCount, 6, "anki: model enam bidang")
eq(sum?.noteFieldCounts ?? [], [6, 6], "anki: tiap catatan enam bidang")
eq(sum?.deckNames ?? [], ["Default", "SpotLyrics"], "anki: dek bawaan dan dek SpotLyrics")
do {
    try AnkiPackage.write(notes: [], media: [AnkiMedia(name: "x", url: tmpDir.appendingPathComponent("tidak-ada"))], to: tmpDir.appendingPathComponent("e.apkg"))
    check(false, "anki: media hilang harus gagal")
} catch { check(true, "anki: media hilang melempar error") }
let emptyApkg = tmpDir.appendingPathComponent("kosong.apkg")
check((try? AnkiPackage.write(notes: [], media: [], to: emptyApkg)) != nil && FileManager.default.fileExists(atPath: emptyApkg.path), "anki: paket tanpa catatan tetap valid")
try? FileManager.default.removeItem(at: tmpDir)
eq(AnkiPackage.summary(ofCollection: "/tidak/ada.anki2"), nil, "anki: ringkasan berkas tak ada")

eq(Vocab.csvField("biasa"), "biasa", "csv: teks biasa")
eq(Vocab.csvField("a,b"), "\"a,b\"", "csv: koma dikutip")
eq(Vocab.csvField("ia berkata \"halo\""), "\"ia berkata \"\"halo\"\"\"", "csv: tanda kutip digandakan")
eq(Vocab.csvField("baris\nbaru"), "\"baris\nbaru\"", "csv: baris baru dikutip")
let ve = VocabEntry(word: "kata", meaning: "arti, dua", line: "baris \"x\"", song: "A - B", date: Date(timeIntervalSince1970: 0), lang: "id")
let csv = Vocab.csv([ve])
check(csv.hasPrefix("word,meaning,line,song,date\n"), "csv: header")
check(csv.contains("kata,\"arti, dua\",\"baris \"\"x\"\"\",A - B,1970-01-01T00:00:00Z"), "csv: baris data")
eq(Vocab.csv([]), "word,meaning,line,song,date\n", "csv: kosong hanya header")
let oldVocab = "[{\"word\":\"a\",\"meaning\":\"b\",\"line\":\"c\",\"song\":\"d\",\"date\":0}]".data(using: .utf8)!
let decodedOld = try? JSONDecoder().decode([VocabEntry].self, from: oldVocab)
check(decodedOld?.count == 1 && decodedOld?.first?.lang == nil, "vocab: data lama tanpa bahasa tetap terbaca")
let encodedNew = (try? JSONEncoder().encode(ve)).flatMap { try? JSONDecoder().decode(VocabEntry.self, from: $0) }
eq(encodedNew?.lang, "id", "vocab: bahasa tersimpan dan terbaca")

print("\(total - failures)/\(total) passed")
exit(failures == 0 ? 0 : 1)
