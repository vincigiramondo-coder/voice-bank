#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

export VOICE_BANK_VOICE_INPUT_PORT="${VOICE_BANK_VOICE_INPUT_PORT:-8767}"
export VOICE_BANK_VOICE_INPUT_HOST="${VOICE_BANK_VOICE_INPUT_HOST:-127.0.0.1}"
export VOICE_BANK_VOICE_INPUT_LOG_DIR="${VOICE_BANK_VOICE_INPUT_LOG_DIR:-$APP_DIR/logs}"
PYTHON_BIN="${VOICE_BANK_VOICE_INPUT_PYTHON:-$APP_DIR/.venv/bin/python}"

mkdir -p "$VOICE_BANK_VOICE_INPUT_LOG_DIR"
exec "$PYTHON_BIN" voice_input_server.py
