# Voice Bank

<p align="center">
  <img src="menu_bar/assets/VoiceBankIcon.png" width="160" alt="Voice Bank icon">
</p>

<p align="center">
  Local-first, self-hosted voice input for macOS.<br>
  按右侧 Option 录音，在自己的 Mac 上完成转写并粘贴到光标处。
</p>

<p align="center">
  <a href="README.zh-CN.md"><strong>中文说明</strong></a>
  ·
  <a href="README.en.md"><strong>English</strong></a>
</p>

<p align="center">
  <a href="https://github.com/vincigiramondo-coder/voice-bank/actions/workflows/ci.yml"><img src="https://github.com/vincigiramondo-coder/voice-bank/actions/workflows/ci.yml/badge.svg" alt="Build and tests"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-5f8f7b.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-5b7fa3.svg" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/Apple%20Silicon-tested-d7845a.svg" alt="Tested on Apple Silicon">
</p>

## What It Does / 它能做什么

- Press the **right Option key** once to start recording and again to finish.
- Transcribe Chinese locally with FunASR; optionally polish longer text with a local Ollama model.
- Paste the result into the app where recording began. If focus changes, Voice Bank copies the text without pasting it into the wrong app.
- Keep audio and transcripts under your control. Transcript history is off by default.

- 按一次**右侧 Option** 开始录音，再按一次结束。
- 使用本地 FunASR 转写中文；长文本可选用本地 Ollama 模型整理。
- 结果自动粘贴到开始录音时的应用；如果中途切换窗口，只复制到剪贴板，避免贴错地方。
- 音频和文字由你控制，文字历史默认关闭。

## Why Voice Bank / 为什么做它

这个语音输入法是在 Codex 5.5、5.6 的帮助下完成的。我完全不懂代码，Mac 自带的语音输入又不太好用。之前我用过一位大神做的语音输入法，开开心心用了几周，没想到它就下架了……于是我参照记忆中的使用体验，让 Codex 重新做了一个。感兴趣的话，可以把这个项目交给你自己的 AI，让它按照说明书协助安装。语音识别使用本地 FunASR 模型，文案优化也可以选装本地模型；我用的是很基础的 Gemma 4。主打一个能用。

Voice Bank was built with help from Codex 5.5 and 5.6. I do not know how to code, and the built-in Mac dictation did not work well for me. I previously used a voice input app made by a talented independent developer and happily relied on it for a few weeks, only to see it disappear. So, guided by my memory of that experience, I asked Codex to make another one. If you are interested, you can give this repository to your own AI assistant and ask it to help install the project by following the guide. Speech recognition runs on a local FunASR model, and text polishing can optionally use a local model too. I use a basic Gemma 4 setup. The goal is simple: it works.

## Source Release / 源码版本

This repository currently provides a **source release**, not a signed and notarized DMG. Installation requires Terminal, Xcode Command Line Tools, Homebrew, and Python 3.13. The full walkthrough is available in both languages:

当前提供的是**源码版本**，不是经过 Apple 签名与公证的 DMG。安装需要使用终端，并准备 Xcode Command Line Tools、Homebrew 和 Python 3.13。完整步骤见：

- [中文安装与使用教程](README.zh-CN.md)
- [English installation and user guide](README.en.md)
- [中文故障排查](docs/TROUBLESHOOTING.zh-CN.md)
- [English troubleshooting](docs/TROUBLESHOOTING.en.md)

## Privacy / 隐私

The server listens on `127.0.0.1` by default. Client and server transcript history are both disabled by default. Temporary recordings use private per-session directories and are deleted after processing. No cloud API key is required.

服务默认只监听本机 `127.0.0.1`；客户端与服务端文字历史均默认关闭；临时录音使用独立私有目录并在处理后删除；不需要云端 API Key。

See [SECURITY.md](SECURITY.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and [ASSETS.md](ASSETS.md) for security boundaries and licensing details.

## Contributing / 参与改进

Bug reports and small improvements are welcome. Before sharing logs, please remove recordings, transcripts, tokens, private addresses, and local file paths. See [CONTRIBUTING.md](CONTRIBUTING.md) for the short checklist.

欢迎反馈问题和提交小改进。分享日志前，请先删除录音、转写文字、令牌、私人地址和本机文件路径。简要流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## License

[MIT](LICENSE)
