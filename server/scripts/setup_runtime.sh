#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${VOICE_BANK_VOICE_INPUT_PYTHON:-python3}"
VENV_DIR="${VOICE_BANK_VOICE_INPUT_VENV:-$APP_DIR/.venv}"

cd "$APP_DIR"

"$PYTHON_BIN" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 13) else "Voice Bank requires Python 3.13.x")'
"$PYTHON_BIN" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install -r "$APP_DIR/requirements.lock"
"$VENV_DIR/bin/python" -m pip freeze > "$APP_DIR/requirements.lock.local"
"$VENV_DIR/bin/python" -c "import fastapi, funasr, modelscope, requests, torch, torchaudio, uvicorn; print('voice_input_runtime_ok')"

echo "Voice Bank voice_input runtime ready: $VENV_DIR/bin/python"
