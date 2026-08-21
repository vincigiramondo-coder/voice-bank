# Voice Bank English Guide

[中文](README.zh-CN.md) · [Home](README.md) · [Troubleshooting](docs/TROUBLESHOOTING.en.md)

Voice Bank is a local-first, self-hosted voice input tool for macOS. Press the right `Option` key once to record and again to stop. The client sends audio to the Voice Bank server you configure, then copies and pastes the returned text at the current input position.

## Product Architecture

- **Voice Bank.app** is a native macOS client containing the dashboard, menu bar, recording HUD, hotkey, recorder, upload client, History, and paste behavior.
- **Voice Bank Server** is a separate transcription service. It can run on the same Mac or another Mac reachable through your LAN or Tailscale.
- The client does not depend on Python, a virtual environment, a source directory, or an external launch script. The downloaded installer can be removed after installation.

## Features

- Global right `Option` recording hotkey; the left `Option` key is ignored.
- Native SwiftUI dashboard, recording HUD, and live audio level display.
- FunASR transcription and conservative text cleanup through your self-hosted server.
- Clipboard copy followed by `Command+V` paste.
- Local text History under `~/Documents/Voice Bank/History`.
- Private, randomly named temporary recording directories removed after processing.
- Editable and testable server endpoint in the Voice Bank dashboard.

## Requirements

Client:

- Apple Silicon Mac (currently tested; Intel is untested)
- macOS 14 or later
- A reachable Voice Bank `/transcribe` service

Server:

- Apple Silicon Mac
- Python 3.13, FFmpeg, and space for the models
- 16GB RAM and at least 8GB of free disk space are recommended

## Install the Client

Official Releases provide two installation choices:

1. Double-click `Voice-Bank-<version>.pkg` and follow the macOS installer; or
2. Open the DMG and drag `Voice Bank.app` into `Applications`.

After the first launch, click **Change** beside **Mini Server** and enter the service endpoint, for example:

```text
http://127.0.0.1:8767/transcribe
```

For a server on another Mac, use its LAN- or Tailscale-reachable address. Never expose port `8767` directly to the internet.

## Grant Permissions

Voice Bank needs:

1. **Microphone** to record audio.
2. **Input Monitoring** to listen for the right `Option` key.
3. **Accessibility** to send `Command+V` for automatic paste.

These controls are normally under **System Settings > Privacy & Security**. Quit and reopen Voice Bank after changing a permission.

## Use Voice Bank

1. Place the cursor in a text field.
2. Press the right `Option` key once and wait for the recording HUD.
3. Speak.
4. Press the right `Option` key again, then wait for transcription and paste.
5. Press `Escape` during recording or processing to cancel.

When transcription finishes, Voice Bank pastes into the app that is currently in front. If you switch apps while it is processing, verify the current cursor position to avoid pasting into the wrong window.

## Install the Local Server

To install the server from source, prepare Python 3.13 and FFmpeg, then run from the repository root:

```bash
VOICE_BANK_VOICE_INPUT_PYTHON="$(brew --prefix python@3.13)/bin/python3.13" \
  ./server/scripts/setup_runtime.sh
./server/scripts/install_launchd.sh
```

Check readiness:

```bash
curl http://127.0.0.1:8767/healthz
```

The service is ready when the response contains `"ok":true` and `"status":"ready"`. The first launch may need to download the FunASR model.

## Two-Mac Mode and Tokens

When the server listens beyond loopback, it requires a bearer token. The client reads the same token from this owner-only file:

```text
~/Library/Application Support/Voice Bank/server-token
```

Set its permissions to `600`. Plain HTTP does not encrypt content, so use Tailscale/VPN or TLS for two-Mac mode.

## Privacy

- Temporary recordings are deleted after processing and are never included in the repository or installer.
- History, tokens, and local settings stay under the user's account.
- Public source and Releases must not include private addresses, personal paths, recordings, transcripts, logs, or credentials.
- When a remote server is configured, audio is sent to that server.

See [SECURITY.md](SECURITY.md) for the complete boundary.

## Build the Client from Source

The client build does not require Python:

```bash
VOICEBANK_CODESIGN_IDENTITY=- ./menu_bar/build_menu_bar_app.sh
open "build/Voice Bank.app"
```

Create DMG, PKG, and ZIP artifacts:

```bash
./distribution/build_release.sh
```

Public distribution requires Developer ID signing and Apple notarization. See [Productization](docs/PRODUCTIZATION.md).

## Uninstall

1. Quit Voice Bank from its menu bar menu.
2. Delete `/Applications/Voice Bank.app`.
3. If the server is no longer needed, run `./server/scripts/uninstall_launchd.sh`.
4. Delete `~/Documents/Voice Bank/History` to remove local text History.
5. Delete `~/Library/Application Support/Voice Bank/server-token` if a token was configured.

## License

Voice Bank is released under the [MIT License](LICENSE). Models and dependencies keep their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). See [ASSETS.md](ASSETS.md) for the icon declaration.
