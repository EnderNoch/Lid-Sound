#!/bin/bash
# Builds "Lid Sound.app" from Sources/ and installs it in /Applications.
# Also refreshes Lid-Sound.zip, the download linked from the README.
set -euo pipefail
cd "$(dirname "$0")"

APP="Lid Sound.app"
ID="atyp.makers.lidsound"
# The About window's signature, like the system's own "Copyright © … Apple Inc. All rights
# reserved.", with the author in place of Apple.
AUTHOR="EnderNoch (Atypical Maker)"
SINCE=2026
YEARS="$SINCE"; [ "$(date +%Y)" != "$SINCE" ] && YEARS="$SINCE–$(date +%Y)"
COPYRIGHT="Copyright © $YEARS $AUTHOR. All rights reserved."

echo "› compiling"
rm -rf "$APP" Lid-Sound.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -default-isolation MainActor \
	-target arm64-apple-macos26.0 \
	Sources/*.swift -o "$APP/Contents/MacOS/LidSound"

# The icon is layered like the system's own (LidSound.icon, from Icon Composer): macOS
# lays its glass over it and follows the icon style set in System Settings → Appearance.
# actool builds Assets.car from it, plus LidSound.icns for older places. It remembers
# icons by file path and misses edited layers at the same path, so it gets a fresh copy.
echo "› icon"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R LidSound.icon "$TMP/LidSound.icon"
xcrun actool "$TMP/LidSound.icon" --compile "$PWD/$APP/Contents/Resources" \
	--platform macosx --minimum-deployment-target 26.0 --app-icon LidSound \
	--output-partial-info-plist "$TMP/icon.plist" >/dev/null

echo "› Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Lid Sound</string>
	<key>CFBundleDisplayName</key><string>Lid Sound</string>
	<key>LSHasLocalizedDisplayName</key><true/>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>LidSound</string>
	<key>CFBundleIconFile</key><string>LidSound</string>
	<key>CFBundleIconName</key><string>LidSound</string>
	<key>CFBundleIdentifier</key><string>$ID</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>26.0</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
	<key>NSHighResolutionCapable</key><true/>
	<!-- menu bar only: no Dock icon, no window -->
	<key>LSUIElement</key><true/>
	<key>NSHumanReadableCopyright</key><string>$COPYRIGHT</string>
</dict>
</plist>
PLIST

# The app's name in each language, like the system's own apps: Finder, the Dock, the menu
# bar and the window title all follow the system language. The app reads its name back from
# here, so this list is the only place it is spelled out.
# The copyright line in each language comes from Photo Booth, with the author and years
# swapped in; languages macOS doesn't ship keep the English one.
BOOTH="/System/Applications/Photo Booth.app/Contents/Resources/InfoPlist.loctable"
echo "› localized names and copyright"
while IFS='|' read -r code name; do
	mkdir -p "$APP/Contents/Resources/$code.lproj"
	case "$code" in nb) sys=no;; pt) sys=pt_PT;; zh-Hans) sys=zh_CN;; zh-Hant) sys=zh_TW;; *) sys="$code";; esac
	line="$(plutil -extract "$sys.NSHumanReadableCopyright" raw -o - "$BOOTH" 2>/dev/null)" || line="$COPYRIGHT"
	# Apple writes "Apple Inc." with a no-break space in some languages and wraps it in
	# direction marks in Hebrew; perl understands both, the marks stay where they are.
	line="$(printf '%s' "$line" | YEARS="$YEARS" AUTHOR="$AUTHOR" perl -CSDA -pe \
		's/\d{4}(?:\x{2013}\d{4})?([\s\x{200F}\x{2068}]*)Apple[\s\x{00A0}]Inc\./$ENV{YEARS}$1$ENV{AUTHOR}./; s/\.(\x{2069})\./$1./')"
	line="${line//\"/\\\"}"
	printf '"CFBundleName" = "%s";\n"CFBundleDisplayName" = "%s";\n"NSHumanReadableCopyright" = "%s";\n' \
		"$name" "$name" "$line" > "$APP/Contents/Resources/$code.lproj/InfoPlist.strings"
done <<'NAMES'
en|Lid Sound
pl|Dźwięk klapy
de|Deckelklang
fr|Son de l’écran
es|Sonido de la tapa
pt|Som da tampa
it|Suono del coperchio
nl|Klepgeluid
sv|Lockljud
da|Lågets lyd
nb|Lokklyd
fi|Kannen ääni
is|Lokshljóð
cs|Zvuk víka
sk|Zvuk veka
sl|Zvok pokrova
hr|Zvuk poklopca
sr|Звук поклопца
bg|Звук на капака
ro|Sunetul capacului
hu|Fedélhang
el|Ήχος καπακιού
tr|Kapak Sesi
uk|Звук кришки
ru|Звук крышки
be|Гук вечка
lt|Dangčio garsas
lv|Vāka skaņa
et|Kaane heli
ca|So de la tapa
ar|صوت الغطاء
he|צליל המכסה
fa|صدای درب
hi|ढक्कन की आवाज़
bn|ঢাকনার শব্দ
th|เสียงฝาพับ
vi|Âm thanh nắp
id|Suara Penutup
ms|Bunyi Penutup
zh-Hans|开合声
zh-Hant|開合聲
ja|ふたの音
ko|덮개 소리
NAMES

echo "› signing ad-hoc"
codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" Lid-Sound.zip

RUNNING=0
if pgrep -x LidSound >/dev/null; then
	RUNNING=1
	echo "› quitting the running copy"
	osascript -e "if application id \"$ID\" is running then tell application id \"$ID\" to quit" 2>/dev/null || true
	sleep 1
fi

echo "› installing in /Applications"
rm -rf "/Applications/$APP"
ditto "$APP" "/Applications/$APP"
# refresh the icon cache, otherwise Finder keeps the old one
touch "/Applications/$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$APP" || true
# a copy that was running comes back as the new version, like a restart
if [ "$RUNNING" = 1 ]; then
	echo "› reopening"
	open "/Applications/$APP"
fi
echo "› done: /Applications/$APP"
