# Voice Bank Troubleshooting

[中文](TROUBLESHOOTING.zh-CN.md) · [English guide](../README.en.md) · [Home](../README.md)

## Start With These Three Checks

Run from the project root:

```bash
"$(brew --prefix python@3.13)/bin/python3.13" --version
ffprobe -version
curl http://127.0.0.1:8767/healthz
```

Python should report `3.13.x`, `ffprobe` should print a version, and the health response should contain `"ok":true` and `"status":"ready"`.

## `brew` Is Not Found

Homebrew is either not installed or not loaded by the current shell. Follow the instructions on the [official Homebrew website](https://brew.sh/), close and reopen Terminal, then run:

```bash
brew --version
brew install python@3.13 ffmpeg
```

## Voice Bank Requires Python 3.13

The server setup script only accepts Python 3.13. Explicitly select the Homebrew interpreter instead of relying on the system `python3`:

```bash
VOICE_BANK_VOICE_INPUT_PYTHON="$(brew --prefix python@3.13)/bin/python3.13" \
  ./server/scripts/setup_runtime.sh
```

## `Permission denied` or a Script Will Not Run

Confirm that Terminal is in the Voice Bank project root, then restore executable permissions:

```bash
chmod +x menu_bar/*.sh server/scripts/*.sh
```

If the source is on a read-only disk, in a temporary extraction location, or under a managed directory, move the whole project into your home folder and try again.

## The Voice Server Cannot Be Reached

Inspect the background service:

```bash
launchctl print "gui/$(id -u)/com.voicebank.voice-input"
```

Reinstall and start it:

```bash
./server/scripts/install_launchd.sh
```

Read recent output:

```bash
tail -n 80 server/logs/launchd.out.log
tail -n 80 server/logs/launchd.err.log
```

If the logs report a missing Python or server project file, the server source folder was probably moved or deleted. Enter its new location and reinstall the server. The client app does not depend on the source folder.

## Health Reports `starting_or_unavailable`

The first launch downloads and loads FunASR models, which can take some time. Keep the network connected and watch:

```bash
tail -f server/logs/launchd.out.log
```

The model is ready after `voice_input_asr_loaded` appears. Pressing `Control+C` stops the log view, not the background service.

If the log clearly reports a failed model download, check network access and disk space, then restart the service:

```bash
launchctl kickstart -k "gui/$(id -u)/com.voicebank.voice-input"
```

## Port `8767` Is Already in Use

Find the process listening on the port:

```bash
lsof -nP -iTCP:8767 -sTCP:LISTEN
```

If it is an older Voice Bank process, run `./server/scripts/install_launchd.sh` again. If another application owns the port, choose a different Voice Bank port and keep the server, transcription URL, and health URL consistent.

## macOS Blocks the App or Cannot Verify the Developer

There is currently no signed public installer. Official Releases should be Developer ID signed and notarized. If you built an ad-hoc version from trusted source:

1. Attempt to open the app once.
2. Open **System Settings > Privacy & Security**.
3. Find the blocked Voice Bank entry and choose **Open Anyway**.

If the app quits immediately, rebuild and reinstall from the project root:

```bash
./menu_bar/install_voicebank_app.sh
open "/Applications/Voice Bank.app"
```

## The Right `Option` Key Does Nothing

1. Confirm that you are pressing the right-side `Option`; the left key is intentionally ignored.
2. Allow Voice Bank under **System Settings > Privacy & Security > Input Monitoring**.
3. Check **Accessibility** permission too.
4. Quit Voice Bank completely and reopen it.

If the permission list contains multiple Voice Bank entries, remove old entries, keep the current `/Applications/Voice Bank.app`, and grant access again.

## Recording Works but No Text Is Returned

Check microphone permission and server readiness:

```bash
curl http://127.0.0.1:8767/healthz
```

Under **System Settings > Privacy & Security > Microphone**, confirm that Voice Bank is enabled. Record for longer than roughly half a second and verify that macOS is using the intended input device.

## Text Is Recognized but Not Pasted

- Allow Voice Bank under **System Settings > Privacy & Security > Accessibility**.
- Voice Bank sends paste to the frontmost app when transcription finishes. If you switch apps during processing, verify the current cursor position.
- Password fields, secure input controls, and some managed apps may reject simulated paste. Paste manually in those cases.

## The App Reports a Server Connection Failure

The client does not depend on the source directory, Python, or a virtual environment. Click **Change** beside **Mini Server**, verify the `/transcribe` endpoint, then click **Test**. A local server normally uses:

```text
http://127.0.0.1:8767/transcribe
```

## Two-Mac Mode Returns `401 Unauthorized`

The `server-token` files on both Macs must contain exactly the same value and use mode `0600`:

```bash
ls -l "$HOME/Library/Application Support/Voice Bank/server-token"
```

After changing a token, restart the server and reopen the client app. Never paste the real token into chats, screenshots, public issues, or logs.

## Two-Mac Mode Times Out

- Confirm that both Macs are connected to the same Tailscale/VPN network.
- Use the VPN address rather than a changing local-network address.
- Reinstall the server background service with `VOICE_BANK_VOICE_INPUT_HOST=0.0.0.0`.
- Check whether the macOS firewall allows the connection.
- Never forward port `8767` directly from a router to the internet.

## Low Disk Space

Inspect project and model-cache usage:

```bash
du -sh . server/.venv ~/.cache/modelscope 2>/dev/null
df -h "$HOME"
```

When Voice Bank is no longer needed, uninstall the service before deleting the source directory and unused models under `~/.cache/modelscope`. Other AI projects may share that cache, so do not remove the entire directory unless you know it is safe.

## Perform a Clean Reinstall

1. Quit the menu bar app.
2. Run `./server/scripts/uninstall_launchd.sh`.
3. Delete `/Applications/Voice Bank.app` in Finder.
4. To rebuild the server runtime, move `server/.venv` from the project to Trash.
5. Repeat the [English installation guide](../README.en.md).

Reinstalling the client does not automatically remove text History. Decide whether to keep `~/Documents/Voice Bank/History` first.
