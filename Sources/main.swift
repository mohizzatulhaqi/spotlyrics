// SpotLyrics: synced Spotify lyrics in the macOS menu bar.
// Features: lyrics from LRCLIB, on-device multi-language translation (per-line detection),
//           study mode, automatic lyrics offset per audio output (AirPods, speakers, etc.).
// Build:  ./build.sh   (produces SpotLyrics.app)
// Run:    open SpotLyrics.app   (allow Automation for Spotify when prompted)

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
