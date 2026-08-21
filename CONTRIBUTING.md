# Contributing to Voice Bank

Small fixes, documentation improvements, and carefully scoped feature proposals are welcome.

## Before opening an issue

1. Check the [Chinese troubleshooting guide](docs/TROUBLESHOOTING.zh-CN.md) or [English troubleshooting guide](docs/TROUBLESHOOTING.en.md).
2. Remove recordings, transcripts, access tokens, private addresses, usernames, and home-directory paths from screenshots and logs.
3. Include your macOS version, Mac chip, and the installation step where the problem occurred.

## Before submitting a change

Run the lightweight checks below from the repository root:

```bash
python3 -m unittest discover -s tests -v
python3 -m py_compile air_voice_client.py server/voice_input_server.py
bash -n menu_bar/build_menu_bar_app.sh menu_bar/install_voicebank_app.sh distribution/*.sh server/scripts/*.sh
plutil -lint distribution/VoiceBank.entitlements
plutil -lint server/deploy/com.voicebank.voice-input.plist.template
./menu_bar/build_menu_bar_app.sh
codesign --verify --deep --strict "build/Voice Bank.app"
```

Do not commit generated apps, model files, recordings, transcripts, `.env` files, logs, or local runtime data.

## Language

Issues and pull requests are welcome in Chinese or English.

---

# 参与 Voice Bank

欢迎提交小型修复、文档改进，以及范围清晰的功能建议。

## 提交问题前

1. 先查看[中文故障排查](docs/TROUBLESHOOTING.zh-CN.md)或[英文故障排查](docs/TROUBLESHOOTING.en.md)。
2. 从截图和日志中删除录音、转写文字、访问令牌、私人地址、用户名及本机目录路径。
3. 请注明 macOS 版本、Mac 芯片，以及问题出现在哪一步。

## 提交改动前

请在项目根目录运行上面的轻量检查。不要提交生成的 App、模型文件、录音、转写文字、`.env`、日志或本地运行数据。

问题和改动说明均可使用中文或英文。
