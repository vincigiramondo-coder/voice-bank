#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="${VOICE_BANK_VOICE_INPUT_URL:-http://localhost:8767}"
TOKEN="${VOICE_INPUT_SERVER_TOKEN:-${VOICE_BANK_API_TOKEN:-}}"
AUTH_ARGS=()
if [[ -n "$TOKEN" ]]; then
  AUTH_ARGS=(-H "Authorization: Bearer $TOKEN")
fi
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/sample.wav" >&2
  exit 2
fi
SAMPLE="$1"
OUT_DIR="$APP_DIR/test-output"

mkdir -p "$OUT_DIR"
curl -sS "${AUTH_ARGS[@]}" "$BASE_URL/healthz" | tee "$OUT_DIR/healthz.json"
printf '\n'
curl -sS "${AUTH_ARGS[@]}" -X POST "$BASE_URL/transcribe" -F "file=@${SAMPLE}" | tee "$OUT_DIR/transcribe.json"
printf '\n'
