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
eq(untranslated, ["audioOutput", "automationPath"], "L10n: hanya teks yang memang sama yang identik")

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

print("\(total - failures)/\(total) passed")
exit(failures == 0 ? 0 : 1)
