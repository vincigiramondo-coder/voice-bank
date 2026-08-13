# Voice Bank Voice Input Server

[中文](README.md) · [English user guide](../README.en.md)

This is the self-hosted Voice Bank server. Version `v1.2` keeps a FunASR model resident for Chinese transcription, applies conservative local cleanup to ordinary short dictation, and can optionally ask a local Ollama model to polish longer text.

## Install

Python 3.13.13 is the recommended runtime:

```bash
VOICE_BANK_VOICE_INPUT_PYTHON="$(brew --prefix python@3.13)/bin/python3.13" \
  ./scripts/setup_runtime.sh
```

`requirements.txt` lists top-level dependencies. `requirements.lock` is the fully pinned and hashed Apple Silicon/Python 3.13 lock. FFmpeg and `ffprobe` must also be installed:

```bash
brew install ffmpeg
```

## Run

Foreground, loopback-only mode:

```bash
./scripts/run_local.sh
```

Install as a per-user background service:

```bash
./scripts/install_launchd.sh
```

The default address is `http://127.0.0.1:8767`.

## API

- `GET /healthz` returns minimal service readiness without local paths or raw startup errors.
- `POST /transcribe` accepts a multipart upload in the `file` field.

The transcription response includes `raw`, `polished`/`text`, `segments`, `duration`, `timings`, `polish_mode`, and `polish_guarded`.

## Privacy and Limits

Text history and transcript-body logs are off by default:

```text
VOICE_BANK_SAVE_HISTORY=0
VOICE_BANK_DEBUG_TEXT_LOGS=0
```

Temporary audio uses a private per-request directory and is deleted after the request. Defaults are a 50MB upload ceiling, 300-second audio limit, and one concurrent transcription. Configure them with:

```text
VOICE_BANK_MAX_UPLOAD_MB=50
VOICE_BANK_MAX_AUDIO_SECONDS=300
VOICE_BANK_MAX_CONCURRENT_TRANSCRIPTIONS=1
```

## Non-Loopback Mode

Binding to a non-loopback address requires a bearer token unless the operator explicitly enables the insecure override. Prefer an owner-only token file at `~/Library/Application Support/Voice Bank/server-token` with mode `0600`.

```bash
VOICE_BANK_VOICE_INPUT_HOST=0.0.0.0 ./scripts/install_launchd.sh
```

Bearer authentication does not encrypt plain HTTP. Use this mode only through Tailscale/VPN or a TLS reverse proxy, and never expose port `8767` directly to the internet. API documentation routes are disabled off-loopback.

## Text Polishing

The default `smart` mode keeps short dictation local and only tries Ollama beyond the configured threshold:

```text
VOICE_BANK_SMART_POLISH_MODE=smart
VOICE_BANK_MODEL_POLISH_MIN_CHARS=120
VOICE_BANK_POLISH_MODEL=gemma4@sha256:c6eb396dbd5992bbe3f5cdb947e8bbc0ee413d7c17e2beaae69f5d569cf982eb
VOICE_BANK_PREWARM_POLISH_MODEL=0
```

Modes:

- `local`: always use conservative local punctuation and cleanup.
- `smart`: local for short text; try Ollama for long text with an over-rewrite guard.
- `model`: try Ollama for all non-empty text, then fall back locally on errors or excessive rewriting.

Ollama is optional. Voice Bank continues with local cleanup if it is unavailable.

## Service Management

Reinstall/restart the LaunchAgent:

```bash
./scripts/install_launchd.sh
```

Uninstall it:

```bash
./scripts/uninstall_launchd.sh
```

Run a smoke test with your own audio after the server is ready:

```bash
./scripts/smoke_test.sh /path/to/sample.wav
```
