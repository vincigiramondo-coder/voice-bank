#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/build/Voice Bank.app"
APP_DST="/Applications/Voice Bank.app"
BACKUP_ROOT="${VOICEBANK_BACKUP_DIR:-$HOME/Library/Application Support/Voice Bank/Backups}"
CONTENTS_SRC="$APP_SRC/Contents"
CONTENTS_DST="$APP_DST/Contents"
CONTENTS_TMP="$APP_DST/Contents.tmp.$$"

cleanup() {
  rm -rf "$CONTENTS_TMP"
}
trap cleanup EXIT

"$ROOT/menu_bar/build_menu_bar_app.sh" >/dev/null

if [[ -d "$APP_DST" ]]; then
  mkdir -p "$BACKUP_ROOT"
  BACKUP_APP="$BACKUP_ROOT/Voice Bank-$(date +%Y%m%d-%H%M%S).app"
  /usr/bin/ditto "$APP_DST" "$BACKUP_APP"
  echo "Backup: $BACKUP_APP"
fi

pkill -f "/VoiceBankMenuBar.app/Contents/MacOS/VoiceBankMenuBar" 2>/dev/null || true
pkill -f "/Voice Bank.app/Contents/MacOS/VoiceBankMenuBar" 2>/dev/null || true

mkdir -p "$APP_DST"
rm -rf "$CONTENTS_TMP"
/usr/bin/ditto "$CONTENTS_SRC" "$CONTENTS_TMP"
rm -rf "$CONTENTS_DST"
mv "$CONTENTS_TMP" "$CONTENTS_DST"
trap - EXIT

codesign --verify --deep --strict "$APP_DST"

echo "$APP_DST"
