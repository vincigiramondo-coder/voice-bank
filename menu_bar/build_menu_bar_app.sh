#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/build/Voice Bank.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/VoiceBankMenuBar"
PLIST="$CONTENTS_DIR/Info.plist"
SIGN_IDENTITY="${VOICEBANK_CODESIGN_IDENTITY:--}"
SERVER_URL="${VOICEBANK_SERVER_URL:-http://127.0.0.1:8767/transcribe}"
HEALTH_URL="${VOICEBANK_HEALTH_URL:-${SERVER_URL%/transcribe}/healthz}"
APP_VERSION="${VOICEBANK_VERSION:-0.2.0}"
BUILD_NUMBER="${VOICEBANK_BUILD_NUMBER:-2}"
BUNDLE_IDENTIFIER="${VOICEBANK_BUNDLE_IDENTIFIER:-local.voicebank.menubar}"
ENTITLEMENTS="$ROOT/distribution/VoiceBank.entitlements"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

(
  cd "$ROOT"
  swiftc \
    -file-prefix-map "$ROOT=." \
    "menu_bar/VoiceBankConfig.swift" \
    "menu_bar/VoiceBankTheme.swift" \
    "menu_bar/VoiceBankText.swift" \
    "menu_bar/VoiceBankStatus.swift" \
    "menu_bar/HistoryStore.swift" \
    "menu_bar/AudioLevelService.swift" \
    "menu_bar/VoiceInputClient.swift" \
    "menu_bar/RecordingCoordinator.swift" \
    "menu_bar/HotkeyService.swift" \
    "menu_bar/PermissionsService.swift" \
    "menu_bar/PasteService.swift" \
    "menu_bar/DashboardComponents.swift" \
    "menu_bar/DashboardSwiftUI.swift" \
    "menu_bar/RecordingOverlaySwiftUI.swift" \
    "menu_bar/DashboardPages.swift" \
    "menu_bar/VoiceBankMenuBar.swift" \
    "menu_bar/VoiceBankApp.swift" \
    -framework AppKit \
    -framework AVFoundation \
    -framework CoreGraphics \
    -framework Foundation \
    -framework SwiftUI \
    -o "$EXECUTABLE"
)

cat > "$PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>VoiceBankMenuBar</string>
  <key>CFBundleIdentifier</key>
  <string>local.voicebank.menubar</string>
  <key>CFBundleName</key>
  <string>Voice Bank</string>
  <key>CFBundleDisplayName</key>
  <string>Voice Bank</string>
  <key>CFBundleIconFile</key>
  <string>VoiceBankIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Voice Bank uses System Events to paste transcribed text into the active app.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Voice Bank needs microphone access to transcribe voice input.</string>
  <key>NSInputMonitoringUsageDescription</key>
  <string>Voice Bank listens for the right Option key to start and stop voice input.</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Add :VoiceBankServerURL string $SERVER_URL" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :VoiceBankHealthURL string $HEALTH_URL" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_IDENTIFIER" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"

chmod +x "$EXECUTABLE"
if [[ -f "$ROOT/menu_bar/assets/VoiceBankIcon.png" ]]; then
  cp "$ROOT/menu_bar/assets/VoiceBankIcon.png" "$RESOURCES_DIR/VoiceBankIcon.png"
fi
if [[ -f "$ROOT/menu_bar/assets/VoiceBankIcon.icns" ]]; then
  cp "$ROOT/menu_bar/assets/VoiceBankIcon.icns" "$RESOURCES_DIR/VoiceBankIcon.icns"
fi
xattr -cr "$APP_DIR"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" --sign - "$APP_DIR" >/dev/null
elif [[ "$SIGN_IDENTITY" == Developer\ ID\ Application:* ]]; then
  codesign --force --deep --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
else
  codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
fi
echo "$APP_DIR"
