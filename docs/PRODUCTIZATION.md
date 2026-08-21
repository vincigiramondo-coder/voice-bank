# Voice Bank Productization

## Product baseline

The public product is based on the P16R SwiftUI interface from Control Center
task #121. The dashboard, History page, menu bar, recording HUD, Right Option
interaction, Escape cancellation, automatic paste, and Mini protocol are the
compatibility baseline.

## Runtime layout

The macOS client is self-contained. It records with AVFoundation and uploads
directly with URLSession. It does not launch Python, a virtual environment, or
source-tree scripts.

The transcription server remains a separate component. Users can set its
`/transcribe` endpoint from the Voice Bank Preferences screen. The default
public build points to `http://127.0.0.1:8767/transcribe`.

## Local candidate build

```bash
VOICEBANK_CODESIGN_IDENTITY=- ./menu_bar/build_menu_bar_app.sh
```

For a private LAN candidate, inject the endpoint into that build without
committing it to source:

```bash
VOICEBANK_SERVER_URL=http://mini-host:8767/transcribe \
VOICEBANK_CODESIGN_IDENTITY=- \
./menu_bar/build_menu_bar_app.sh
```

The result is `build/Voice Bank.app`.

## Release artifacts

```bash
./distribution/build_release.sh
```

This creates a DMG, installer PKG, ZIP archive, and SHA-256 checksums under
`dist/`. Test artifacts can use ad-hoc signing. Public artifacts must use a
Developer ID Application identity for the app, a Developer ID Installer
identity for the PKG, and Apple notarization.

## Public release signing

```bash
VOICEBANK_CODESIGN_IDENTITY="Developer ID Application: Example" \
VOICEBANK_INSTALLER_IDENTITY="Developer ID Installer: Example" \
./distribution/build_release.sh
```

After configuring a `notarytool` keychain profile:

```bash
VOICEBANK_NOTARY_PROFILE=voicebank-notary \
./distribution/notarize_release.sh
```

Never store signing credentials, notary credentials, server tokens, private
network addresses, transcript history, recordings, or build artifacts in the
repository.
