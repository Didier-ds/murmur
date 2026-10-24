#!/bin/zsh
# Builds Murmur.app from the Swift package (no Xcode needed).
#   ./scripts/build-app.sh          build into ./build/Murmur.app
#   ./scripts/build-app.sh --run    build, then (re)launch it
set -euo pipefail
cd "${0:A:h}/.."

APP=build/Murmur.app
BUNDLE_ID=dev.murmur.Murmur

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/Murmur"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Murmur"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>Murmur</string>
    <key>CFBundleDisplayName</key><string>Murmur</string>
    <key>CFBundleExecutable</key><string>Murmur</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>Murmur listens while you dictate so it can turn your voice into text.</string>
    <key>NSSpeechRecognitionUsageDescription</key><string>Murmur uses Apple's on-device speech model to transcribe what you say.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature. macOS ties Accessibility permission to the signature,
# so after each rebuild you may need to toggle Murmur off/on in Accessibility settings.
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--run" ]]; then
    pkill -x Murmur 2>/dev/null || true
    open "$APP"
fi
