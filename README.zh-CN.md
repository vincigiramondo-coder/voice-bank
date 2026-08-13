# Voice Bank 中文说明

[English](README.en.md) · [返回首页](README.md) · [故障排查](docs/TROUBLESHOOTING.zh-CN.md)

Voice Bank 是一套本地优先、可自托管的 macOS 中文语音输入工具。按一下右侧 `Option` 开始录音，再按一下结束；音频由本机或你自己的另一台 Mac 转写，结果随后粘贴到原来的输入位置。

> 当前是源码版本，不是 Apple 签名、公证后的 DMG。安装过程需要使用终端，但日常使用只需要菜单栏 App 和右侧 `Option`。

## 为什么做它

这个语音输入法是在 Codex 5.5、5.6 的帮助下完成的。我完全不懂代码，Mac 自带的语音输入又不太好用。之前我用过一位大神做的语音输入法，开开心心用了几周，没想到它就下架了……于是我参照记忆中的使用体验，让 Codex 重新做了一个。感兴趣的话，可以把这个项目交给你自己的 AI，让它按照这份说明书协助安装。

语音识别使用本地 FunASR 模型，首次启动时会自动下载；文案优化也可以选装本地模型，我用的是很基础的 Gemma 4。主打一个能用。

## 功能

- 右侧 `Option` 全局录音快捷键，不响应左侧 `Option`。
- FunASR 本地中文转写，无需云端 API Key。
- 短文本使用本地保守标点和口语清理。
- 可选 Ollama 本地模型，用于较长、较乱的口语整理。
- 自动粘贴；如果识别期间切换了应用，只复制到剪贴板，防止贴错窗口。
- 文字历史默认关闭，可主动开启、选择保留 7/30/90/365 天并一键清空。

## 运行要求

- Apple Silicon Mac（当前验证平台；Intel Mac 尚未验证）
- macOS 14 或更高版本
- Python 3.13（验证版本为 3.13.13）
- Xcode Command Line Tools
- Homebrew、FFmpeg
- 建议至少 16GB 内存，并预留 8GB 以上磁盘空间

菜单栏客户端很轻，空间主要由 Python 环境、PyTorch 和首次启动时下载的 FunASR 模型占用。

## 一、准备系统工具

打开“终端”，安装 Apple 命令行开发工具：

```bash
xcode-select --install
```

如果尚未安装 Homebrew，请先按 [Homebrew 官方网站](https://brew.sh/) 的说明安装。然后执行：

```bash
brew install python@3.13 ffmpeg
```

确认版本：

```bash
"$(brew --prefix python@3.13)/bin/python3.13" --version
ffprobe -version
```

## 二、下载源码

在 GitHub 项目页面选择 **Code > Download ZIP**，解压后把文件夹放在一个长期保留的位置，例如 `~/VoiceBank`。也可以使用 Git 克隆。

在终端进入项目根目录。下面只是示例，请替换成你的实际位置：

```bash
cd ~/VoiceBank
```

安装后的 App 会记住这个源码目录，因此安装完成后不要移动或删除它。若移动了目录，重新运行客户端安装脚本即可。

## 三、安装并启动本地语音服务

先建立服务端运行环境。首次安装需要下载较多 Python 依赖：

```bash
VOICE_BANK_VOICE_INPUT_PYTHON="$(brew --prefix python@3.13)/bin/python3.13" \
  ./server/scripts/setup_runtime.sh
```

安装为当前用户的后台服务：

```bash
./server/scripts/install_launchd.sh
```

首次启动还会下载 FunASR 模型，请耐心等待。可以反复运行下面的命令检查状态：

```bash
curl http://127.0.0.1:8767/healthz
```

看到 `"ok":true` 和 `"status":"ready"` 表示服务已经准备好。如果长时间没有准备好，请查看[故障排查](docs/TROUBLESHOOTING.zh-CN.md)。

## 四、安装菜单栏 App

回到项目根目录，创建客户端环境并按锁定版本安装依赖：

```bash
"$(brew --prefix python@3.13)/bin/python3.13" -m venv .venv
./.venv/bin/python -m pip install --require-hashes -r requirements-client.txt
./menu_bar/install_voicebank_app.sh
```

App 默认安装到当前用户的 `~/Applications/Voice Bank.app`，不需要管理员密码。打开它：

```bash
open "$HOME/Applications/Voice Bank.app"
```

如果 macOS 阻止首次打开，请进入 **系统设置 > 隐私与安全性**，确认这是你从源码构建的 App 后选择“仍要打开”。不要从不可信来源下载别人打包的 Voice Bank。

## 五、授予权限

首次使用需要允许：

1. **麦克风**：录制声音。
2. **输入监控**：监听右侧 `Option` 快捷键。
3. **辅助功能**：向当前应用发送 `Command+V` 完成粘贴。

对应位置通常在 **系统设置 > 隐私与安全性**。修改权限后，退出并重新打开 Voice Bank。

## 六、开始使用

1. 把光标放到文本输入框。
2. 按一下键盘右侧的 `Option`，看到“录音中”。
3. 说话。
4. 再按一下右侧 `Option`，等待识别和粘贴。

如果识别期间切换到了其他应用，Voice Bank 不会自动贴入新窗口，只会把结果放进剪贴板；回到目标位置按 `Command+V` 即可。

## 历史记录与隐私

- 客户端和服务端默认都不保存转写历史。
- 在 Voice Bank 首页“选项”中可主动开启本地历史、设置保留期和清空全部记录。
- 开启后，客户端历史默认位于 `~/Documents/Voice Bank/History`。
- 临时录音处理完成后会删除；下次启动也会清理异常退出留下的旧临时目录。
- 本机模式不把音频发送到互联网。
- Ollama 是可选的本地功能；未安装时会自动回退到本地规则整理。

完整安全边界见 [SECURITY.md](SECURITY.md)。

## 可选：命令行使用

交互式录音：

```bash
./.venv/bin/python air_voice_client.py
```

上传已有音频但不自动粘贴：

```bash
./.venv/bin/python air_voice_client.py --file /path/to/sample.wav --no-paste
```

命令行历史默认关闭。可使用 `--save-history` 开启、`--history-retention-days 30` 设置保留期、`--clear-history` 清空。

## 可选：两台 Mac 分工

可以让一台 Mac 运行模型，另一台只负责录音。此模式必须使用同一个 Bearer 令牌，并应放在 Tailscale/VPN 或 TLS 连接内。

在两台 Mac 上分别创建仅当前用户可读的同一令牌文件：

```bash
mkdir -p "$HOME/Library/Application Support/Voice Bank"
printf '%s\n' '在这里填写同一个强随机令牌' > "$HOME/Library/Application Support/Voice Bank/server-token"
chmod 600 "$HOME/Library/Application Support/Voice Bank/server-token"
```

令牌可在服务端 Mac 上用 `openssl rand -hex 32` 生成。然后在服务端 Mac 重新安装后台服务：

```bash
VOICE_BANK_VOICE_INPUT_HOST=0.0.0.0 ./server/scripts/install_launchd.sh
```

在客户端 Mac 安装菜单栏 App 时指定通过 VPN 可访问的服务地址：

```bash
VOICEBANK_SERVER_URL=http://YOUR_SERVER:8767/transcribe \
VOICEBANK_HEALTH_URL=http://YOUR_SERVER:8767/healthz \
./menu_bar/install_voicebank_app.sh
```

令牌只能验证身份，普通 HTTP 本身不加密内容。不要把 `8767` 端口直接暴露到互联网。

## 更新

更新源码后，在项目根目录重新执行：

```bash
./.venv/bin/python -m pip install --require-hashes -r requirements-client.txt
VOICE_BANK_VOICE_INPUT_PYTHON="$(brew --prefix python@3.13)/bin/python3.13" \
  ./server/scripts/setup_runtime.sh
./server/scripts/install_launchd.sh
./menu_bar/install_voicebank_app.sh
```

## 卸载

1. 从菜单栏退出 Voice Bank。
2. 执行 `./server/scripts/uninstall_launchd.sh` 停止并移除后台服务。
3. 在 Finder 中删除 `~/Applications/Voice Bank.app`。
4. 如果不再需要模型和运行环境，可以删除整个源码文件夹。
5. 如曾开启历史，可在 App 内先清空，或自行删除 `~/Documents/Voice Bank/History`。
6. 如曾配置双机令牌，可删除 `~/Library/Application Support/Voice Bank/server-token`。

## 开发与许可证

开发构建命令：

```bash
./menu_bar/build_menu_bar_app.sh
open build/VoiceBankMenuBar.app
```

Voice Bank 源码采用 [MIT License](LICENSE)。模型和第三方依赖保留各自许可证，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)；图标说明见 [ASSETS.md](ASSETS.md)。
