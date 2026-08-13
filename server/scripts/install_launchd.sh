#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.voicebank.voice-input"
PLIST_SRC="$APP_DIR/deploy/$LABEL.plist.template"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
PYTHON_BIN="$APP_DIR/.venv/bin/python"
SERVER_FILE="$APP_DIR/voice_input_server.py"
LOG_DIR="$APP_DIR/logs"
SERVER_HOST="${VOICE_BANK_VOICE_INPUT_HOST:-127.0.0.1}"
SERVER_PORT="${VOICE_BANK_VOICE_INPUT_PORT:-8767}"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "Missing runtime: run server/scripts/setup_runtime.sh first." >&2
  exit 2
fi

escape_replacement() {
  printf '%s' "$1" | sed 's/[&/]/\\&/g'
}

mkdir -p "$APP_DIR/logs" "$HOME/Library/LaunchAgents"
sed \
  -e "s/__APP_DIR__/$(escape_replacement "$APP_DIR")/g" \
  -e "s/__PYTHON_BIN__/$(escape_replacement "$PYTHON_BIN")/g" \
  -e "s/__SERVER_FILE__/$(escape_replacement "$SERVER_FILE")/g" \
  -e "s/__LOG_DIR__/$(escape_replacement "$LOG_DIR")/g" \
  -e "s/__SERVER_HOST__/$(escape_replacement "$SERVER_HOST")/g" \
  -e "s/__SERVER_PORT__/$(escape_replacement "$SERVER_PORT")/g" \
  "$PLIST_SRC" > "$PLIST_DST"
plutil -lint "$PLIST_DST" >/dev/null
launchctl bootout "gui/$(id -u)" "$PLIST_DST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl enable "gui/$(id -u)/$LABEL"
launchctl kickstart -k "gui/$(id -u)/$LABEL"
echo "$LABEL installed at $PLIST_DST"
