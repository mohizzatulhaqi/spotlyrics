#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP=SpotLyrics.app
TMP=$(mktemp -d)
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O $(find Sources -name "*.swift") -o "$APP/Contents/MacOS/SpotLyrics"
cp Info.plist "$APP/Contents/Info.plist"
swiftc make_icon.swift -o "$TMP/make_icon"
"$TMP/make_icon" "$TMP/icon.png"
mkdir "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
rm -rf "$TMP"
echo "Done: $(pwd)/$APP"
