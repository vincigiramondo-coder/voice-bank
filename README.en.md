# Voice Bank English Guide

[中文](README.zh-CN.md) · [Home](README.md) · [Troubleshooting](docs/TROUBLESHOOTING.en.md)

Voice Bank is a local-first, self-hosted Chinese voice input tool for macOS. Press the right `Option` key once to start recording and again to stop. Audio is transcribed on this Mac, or on another Mac you control, and the result is pasted back into the original input field.

> This is a source release, not an Apple-signed and notarized DMG. Installation uses Terminal; everyday use only requires the menu bar app and the right `Option` key.

## Why I Made It

Voice Bank was built with help from Codex 5.5 and 5.6. I do not know how to code, and the built-in Mac dictation did not work well for me. I previously used a voice input app made by a talented independent developer and happily relied on it for a few weeks, only to see it disappear. So, guided by my memory of that experience, I asked Codex to make another one. If you are interested, give this repository to your own AI assistant and ask it to help install the project by following this guide.

Speech recognition runs on a local FunASR model that is downloaded on first launch. Text polishing can optionally use another local model; I use a basic Gemma 4 setup. The goal is simple: it works.

## Features

- Global right `Option` recording hotkey; the left `Option` key is ignored.
- Local Chinese transcription with FunASR and no cloud API key.
- Conservative local punctuation and disfluency cleanup for short text.
- Optional local Ollama polishing for longer, less structured dictation.
- Automatic paste with focus protection. If you switch apps during transcription, the result is copied instead of pasted into the wrong window.
- Transcript history is off by default. If enabled, retention choices are 7, 30, 90, or 365 days, with a clear-all action.

## Requirements

- Apple Silicon Mac (the currently tested platform; Intel is untested)
- macOS 14 or later
- Python 3.13 (tested with 3.13.13)
- Xcode Command Line Tools
- Homebrew and FFmpeg
- 16GB RAM and at least 8GB of free disk space are recommended

The menu bar client is small. Most disk usage comes from the Python environments, PyTorch, and FunASR models downloaded on first launch.

## 1. Install System Tools

Open Terminal and install Apple's command line developer tools:

```bash
xcode-select --install
```

If Homebrew is not installed, follow the instructions on the [official Homebrew website](https://brew.sh/). Then run:

```bash
brew install python@3.13 ffmpeg
```

Verify the tools:

```bash
"$(brew --prefix python@3.13)/bin/python3.13" --version
ffprobe -version
```

## 2. Download the Source

On the GitHub project page, choose **Code > Download ZIP**, extract it, and move the folder to a location you intend to keep, such as `~/VoiceBank`. You can also clone it with Git.

In Terminal, enter the project root. Replace this example with your actual location:

```bash
cd ~/VoiceBank
```

The installed app remembers this source directory. Do not move or delete it after installation. If you move it, run the client installer again.

## 3. Install and Start the Local Voice Server

Create the server environment. The first install downloads a substantial set of Python packages:

```bash
VOICE_BANK_VOICE_INPUT_PYTHON="$(brew --prefix python@3.13)/bin/python3.13" \
  ./server/scripts/setup_runtime.sh
```

Install the server as a background service for the current user:

```bash
./server/scripts/install_launchd.sh
```

The first launch also downloads the FunASR models. Check readiness with:

```bash
curl http://127.0.0.1:8767/healthz
```

The server is ready when the response includes `"ok":true` and `"status":"ready"`. See [Troubleshooting](docs/TROUBLESHOOTING.en.md) if it does not become ready.

## 4. Install the Menu Bar App

From the project root, create the client environment and install the hash-locked dependencies:

```bash
"$(brew --prefix python@3.13)/bin/python3.13" -m venv .venv
./.venv/bin/python -m pip install --require-hashes -r requirements-client.txt
./menu_bar/install_voicebank_app.sh
```

The app is installed to `~/Applications/Voice Bank.app` by default, so no administrator password is required. Open it with:

```bash
open "$HOME/Applications/Voice Bank.app"
```

If macOS blocks the first launch, open **System Settings > Privacy & Security**, confirm that this is the app you built from source, and choose **Open Anyway**. Do not install prebuilt copies from sources you do not trust.

## 5. Grant Permissions

Voice Bank needs:

1. **Microphone** to record audio.
2. **Input Monitoring** to listen for the right `Option` hotkey.
3. **Accessibility** to send `Command+V` to the active app.

These controls are normally under **System Settings > Privacy & Security**. Quit and reopen Voice Bank after changing a permission.

## 6. Use Voice Bank

1. Place the cursor in a text field.
2. Press the right `Option` key once and wait for the recording indicator.
3. Speak.
4. Press the right `Option` key again, then wait for transcription and paste.

If you change apps while transcription is running, Voice Bank only copies the result. Return to the target field and press `Command+V`.

## History and Privacy

- Client and server transcript history are both disabled by default.
- Enable local history, choose retention, or clear all entries from Options on the Voice Bank home page.
- When enabled, client history defaults to `~/Documents/Voice Bank/History`.
- Temporary recordings are deleted after processing. A later launch also removes stale private recording directories left by a hard crash.
- In single-Mac mode, audio is not sent to the internet.
- Ollama is optional and local. If unavailable, Voice Bank falls back to conservative local cleanup.

See [SECURITY.md](SECURITY.md) for the complete security boundary.

## Optional: Command-Line Use

Interactive recording:

```bash
./.venv/bin/python air_voice_client.py
```

Upload an existing audio file without automatic paste:

```bash
./.venv/bin/python air_voice_client.py --file /path/to/sample.wav --no-paste
```

CLI history is also off by default. Use `--save-history` to enable it, `--history-retention-days 30` to set retention, and `--clear-history` to delete it.

## Optional: Two-Mac Setup

One Mac can run the models while another records audio. This mode requires a shared bearer token and should operate only through Tailscale/VPN or TLS.

Create the same owner-only token file on both Macs:

```bash
mkdir -p "$HOME/Library/Application Support/Voice Bank"
printf '%s\n' 'PASTE_THE_SAME_STRONG_RANDOM_TOKEN_HERE' > "$HOME/Library/Application Support/Voice Bank/server-token"
chmod 600 "$HOME/Library/Application Support/Voice Bank/server-token"
```

Generate the token on the server Mac with `openssl rand -hex 32`. Reinstall the background service on that Mac with LAN listening enabled:

```bash
VOICE_BANK_VOICE_INPUT_HOST=0.0.0.0 ./server/scripts/install_launchd.sh
```

Install the menu bar app on the client Mac with the server's VPN-reachable address:

```bash
VOICEBANK_SERVER_URL=http://YOUR_SERVER:8767/transcribe \
VOICEBANK_HEALTH_URL=http://YOUR_SERVER:8767/healthz \
./menu_bar/install_voicebank_app.sh
```

The token authenticates requests but plain HTTP does not encrypt them. Never expose port `8767` directly to the internet.

## Update

After updating the source, run from the project root:

```bash
./.venv/bin/python -m pip install --require-hashes -r requirements-client.txt
VOICE_BANK_VOICE_INPUT_PYTHON="$(brew --prefix python@3.13)/bin/python3.13" \
  ./server/scripts/setup_runtime.sh
./server/scripts/install_launchd.sh
./menu_bar/install_voicebank_app.sh
```

## Uninstall

1. Quit Voice Bank from its menu bar menu.
2. Run `./server/scripts/uninstall_launchd.sh` to stop and remove the background service.
3. Delete `~/Applications/Voice Bank.app` in Finder.
4. Delete the source folder if you also want to remove the models and Python environments.
5. If history was enabled, clear it in the app first or delete `~/Documents/Voice Bank/History` yourself.
6. If two-Mac mode was configured, delete `~/Library/Application Support/Voice Bank/server-token`.

## Development and Licenses

Development build:

```bash
./menu_bar/build_menu_bar_app.sh
open build/VoiceBankMenuBar.app
```

Voice Bank source is licensed under the [MIT License](LICENSE). Models and dependencies retain their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). See [ASSETS.md](ASSETS.md) for the app icon declaration.
