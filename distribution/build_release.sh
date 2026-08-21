#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VOICEBANK_VERSION:-0.2.0}"
BUILD_NUMBER="${VOICEBANK_BUILD_NUMBER:-2}"
DIST_DIR="$ROOT/dist"
APP="$ROOT/build/Voice Bank.app"
RELEASE_NAME="Voice-Bank-$VERSION"
DMG="$DIST_DIR/$RELEASE_NAME.dmg"
PKG_UNSIGNED="$DIST_DIR/$RELEASE_NAME-unsigned.pkg"
PKG="$DIST_DIR/$RELEASE_NAME.pkg"
ZIP="$DIST_DIR/$RELEASE_NAME.zip"
INSTALLER_IDENTITY="${VOICEBANK_INSTALLER_IDENTITY:-}"
PREVIOUS_SUFFIX="previous-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$DIST_DIR" "$ROOT/build"

for artifact in "$DMG" "$PKG_UNSIGNED" "$PKG" "$ZIP"; do
  if [[ -e "$artifact" ]]; then
    mv "$artifact" "$artifact.$PREVIOUS_SUFFIX"
  fi
done

VOICEBANK_VERSION="$VERSION" \
VOICEBANK_BUILD_NUMBER="$BUILD_NUMBER" \
"$ROOT/menu_bar/build_menu_bar_app.sh" >/dev/null

codesign --verify --deep --strict "$APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

pkgbuild \
  --component "$APP" \
  --install-location /Applications \
  --identifier "local.voicebank.installer" \
  --version "$VERSION" \
  "$PKG_UNSIGNED"

if [[ -n "$INSTALLER_IDENTITY" ]]; then
  productsign --sign "$INSTALLER_IDENTITY" --timestamp "$PKG_UNSIGNED" "$PKG"
else
  /usr/bin/ditto "$PKG_UNSIGNED" "$PKG"
fi

STAGING="$(mktemp -d "$ROOT/build/voicebank-dmg.XXXXXX")"
/usr/bin/ditto "$APP" "$STAGING/Voice Bank.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
  -volname "Voice Bank" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null

shasum -a 256 "$DMG" "$PKG" "$ZIP" > "$DIST_DIR/SHA256SUMS.txt"

echo "$DMG"
echo "$PKG"
echo "$ZIP"
echo "$DIST_DIR/SHA256SUMS.txt"
