#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VOICEBANK_VERSION:-0.2.0}"
PROFILE="${VOICEBANK_NOTARY_PROFILE:-}"
DMG="$ROOT/dist/Voice-Bank-$VERSION.dmg"
PKG="$ROOT/dist/Voice-Bank-$VERSION.pkg"

if [[ -z "$PROFILE" ]]; then
  echo "Set VOICEBANK_NOTARY_PROFILE to an xcrun notarytool keychain profile." >&2
  exit 2
fi

for artifact in "$DMG" "$PKG"; do
  if [[ ! -f "$artifact" ]]; then
    echo "Missing release artifact: $artifact" >&2
    exit 2
  fi
  xcrun notarytool submit "$artifact" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$artifact"
  xcrun stapler validate "$artifact"
done

echo "Notarization complete."
