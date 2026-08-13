#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/build/VoiceBankMenuBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$MACOS_DIR/VoiceBankMenuBar"
PLIST="$CONTENTS_DIR/Info.plist"
SIGN_IDENTITY="${VOICEBANK_CODESIGN_IDENTITY:-}"
SERVER_URL="${VOICEBANK_SERVER_URL:-http://127.0.0.1:8767/transcribe}"
HEALTH_URL="${VOICEBANK_HEALTH_URL:-${SERVER_URL%/transcribe}/healthz}"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc \
  "$ROOT/menu_bar/VoiceBankConfig.swift" \
  "$ROOT/menu_bar/VoiceBankPreferences.swift" \
  "$ROOT/menu_bar/VoiceBankTheme.swift" \
  "$ROOT/menu_bar/VoiceBankText.swift" \
  "$ROOT/menu_bar/VoiceBankStatus.swift" \
  "$ROOT/menu_bar/HistoryStore.swift" \
  "$ROOT/menu_bar/AudioLevelService.swift" \
  "$ROOT/menu_bar/VoiceInputClient.swift" \
  "$ROOT/menu_bar/RecordingCoordinator.swift" \
  "$ROOT/menu_bar/HotkeyService.swift" \
  "$ROOT/menu_bar/PermissionsService.swift" \
  "$ROOT/menu_bar/PasteService.swift" \
  "$ROOT/menu_bar/DashboardComponents.swift" \
  "$ROOT/menu_bar/DashboardPages.swift" \
  "$ROOT/menu_bar/VoiceBankMenuBar.swift" \
  "$ROOT/menu_bar/VoiceBankApp.swift" \
  -framework AppKit \
  -framework CoreGraphics \
  -framework Foundation \
  -o "$EXECUTABLE"

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
  <key>CFBundleIconFile</key>
  <string>VoiceBankIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
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
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Add :VoiceBankProjectDirectory string $ROOT" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :VoiceBankServerURL string $SERVER_URL" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :VoiceBankHealthURL string $HEALTH_URL" "$PLIST"

chmod +x "$EXECUTABLE"
if [[ -f "$ROOT/menu_bar/assets/VoiceBankIcon.png" ]]; then
  cp "$ROOT/menu_bar/assets/VoiceBankIcon.png" "$RESOURCES_DIR/VoiceBankIcon.png"
fi
if [[ -f "$ROOT/menu_bar/assets/VoiceBankIcon.icns" ]]; then
  cp "$ROOT/menu_bar/assets/VoiceBankIcon.icns" "$RESOURCES_DIR/VoiceBankIcon.icns"
fi
if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
else
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi
echo "$APP_DIR"
