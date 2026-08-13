#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/build/VoiceBankMenuBar.app"
INSTALL_DIR="${VOICEBANK_APP_INSTALL_DIR:-$HOME/Applications}"
APP_DST="$INSTALL_DIR/Voice Bank.app"
CONTENTS_SRC="$APP_SRC/Contents"
CONTENTS_DST="$APP_DST/Contents"
CONTENTS_TMP="$APP_DST/Contents.tmp.$$"

cleanup() {
  rm -rf "$CONTENTS_TMP"
}
trap cleanup EXIT

"$ROOT/menu_bar/build_menu_bar_app.sh" >/dev/null

pkill -f "/VoiceBankMenuBar.app/Contents/MacOS/VoiceBankMenuBar" 2>/dev/null || true
pkill -f "/Voice Bank.app/Contents/MacOS/VoiceBankMenuBar" 2>/dev/null || true

mkdir -p "$INSTALL_DIR" "$APP_DST"
rm -rf "$CONTENTS_TMP"
/usr/bin/ditto "$CONTENTS_SRC" "$CONTENTS_TMP"
rm -rf "$CONTENTS_DST"
mv "$CONTENTS_TMP" "$CONTENTS_DST"
trap - EXIT

echo "$APP_DST"
