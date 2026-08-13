# Voice Bank Voice Input Server

[English](README.en.md) · [中文用户教程](../README.zh-CN.md)

这是 Voice Bank 的自托管语音服务端。`v1.2` 使用常驻 FunASR 模型完成中文转写，使用本地规则处理普通短文本，并可选择调用本机 Ollama 处理较长、较乱的口语。

## 安装

```bash
cd server
./scripts/setup_runtime.sh
```

推荐使用 Python 3.13.13。`requirements.txt` 是顶层依赖，`requirements.lock` 是 Apple Silicon 验证环境的完整快照。安装脚本会把当前机器的实际解析结果写入被 Git 忽略的 `requirements.lock.local`，不会修改仓库文件。

还需要系统中存在 `ffmpeg` 和 `ffprobe`。使用 Homebrew 时可以安装：

```bash
brew install ffmpeg
```

## 启动

只供本机使用：

```bash
./scripts/run_local.sh
```

允许可信局域网中的客户端访问前，必须配置 Bearer 令牌：

```bash
VOICE_BANK_API_TOKEN="$(openssl rand -hex 32)" \
VOICE_BANK_VOICE_INPUT_HOST=0.0.0.0 \
./scripts/run_local.sh
```

客户端使用同一值作为 `VOICE_INPUT_SERVER_TOKEN`。也可以把令牌放到 `~/Library/Application Support/Voice Bank/server-token`，文件必须属于当前用户且权限为 `0600`。非本机监听没有令牌时会拒绝启动。

服务地址默认为 `http://127.0.0.1:8767`。

## API

- `GET /healthz`：最小化服务状态，不返回本机路径或原始启动错误。
- `POST /transcribe`：multipart 上传，字段名为 `file`。

转写响应主要字段：

- `raw`：FunASR 原始转写。
- `polished` / `text`：保守整理后的文本。
- `segments`、`duration`、`timings`：识别分段和耗时。
- `polish_mode`、`polish_guarded`：整理路径和防过度改写状态。

## 隐私配置

服务默认不保存文字历史，也不把转写正文写入日志：

```text
VOICE_BANK_SAVE_HISTORY=0
VOICE_BANK_DEBUG_TEXT_LOGS=0
```

需要服务器保存文字历史时，可显式开启：

```bash
VOICE_BANK_SAVE_HISTORY=1 \
VOICE_BANK_MEMORY_DIR=/path/to/private/history \
./scripts/run_local.sh
```

临时音频使用每次请求独立的临时目录，并在请求结束后删除。上传会分块接收并在超过上限时立即停止；默认上限 50MB、最长 300 秒、同时处理 1 条，可分别通过 `VOICE_BANK_MAX_UPLOAD_MB`、`VOICE_BANK_MAX_AUDIO_SECONDS` 和 `VOICE_BANK_MAX_CONCURRENT_TRANSCRIPTIONS` 调整。

局域网令牌不提供传输加密。请只在 Tailscale/VPN 或 TLS 反向代理内使用；非本机模式会关闭 OpenAPI、Swagger 和 ReDoc。

## 文本整理

默认 `smart` 模式优先使用本地保守处理，超过阈值后才尝试 Ollama：

```text
VOICE_BANK_SMART_POLISH_MODE=smart
VOICE_BANK_MODEL_POLISH_MIN_CHARS=120
VOICE_BANK_POLISH_MODEL=gemma4@sha256:c6eb396dbd5992bbe3f5cdb947e8bbc0ee413d7c17e2beaae69f5d569cf982eb
VOICE_BANK_PREWARM_POLISH_MODEL=0
```

可选值：

- `local`：始终只用本地标点和轻度口语清理。
- `smart`：短文本走本地，长文本尝试 Ollama，并检测是否过度改写。
- `model`：所有非空文本尝试 Ollama，失败或过度改写时回退本地结果。

## 后台常驻

安装当前用户的 LaunchAgent：

```bash
./scripts/install_launchd.sh
```

卸载：

```bash
./scripts/uninstall_launchd.sh
```

安装脚本会根据当前项目目录生成实际 plist，仓库中的模板不包含任何用户名或本机绝对路径。LaunchAgent 默认仍只监听 `127.0.0.1`；双机部署时可明确指定：

```bash
VOICE_BANK_VOICE_INPUT_HOST=0.0.0.0 ./scripts/install_launchd.sh
```

## Smoke Test

服务启动后传入自己的测试音频：

```bash
./scripts/smoke_test.sh /path/to/sample.wav
```
