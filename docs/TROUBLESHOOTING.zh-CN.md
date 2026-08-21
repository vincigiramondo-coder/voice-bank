# Voice Bank 故障排查

[English](TROUBLESHOOTING.en.md) · [中文安装教程](../README.zh-CN.md) · [返回首页](../README.md)

## 先做这三项检查

在项目根目录执行：

```bash
"$(brew --prefix python@3.13)/bin/python3.13" --version
ffprobe -version
curl http://127.0.0.1:8767/healthz
```

预期结果：Python 为 `3.13.x`，`ffprobe` 能显示版本，健康检查包含 `"ok":true` 和 `"status":"ready"`。

## 找不到 `brew`

说明尚未安装 Homebrew，或终端还没有载入 Homebrew 环境。请按 [Homebrew 官方网站](https://brew.sh/) 的说明安装；安装结束后关闭并重新打开终端，再运行：

```bash
brew --version
brew install python@3.13 ffmpeg
```

## 提示需要 Python 3.13

服务端安装脚本只接受 Python 3.13。不要直接依赖系统中的 `python3`，请明确指定 Homebrew 版本：

```bash
VOICE_BANK_VOICE_INPUT_PYTHON="$(brew --prefix python@3.13)/bin/python3.13" \
  ./server/scripts/setup_runtime.sh
```

## `Permission denied` 或脚本无法执行

先确认终端已经进入 Voice Bank 项目根目录，然后恢复脚本的执行权限：

```bash
chmod +x menu_bar/*.sh server/scripts/*.sh
```

如果源码位于只读磁盘、临时解压目录或受管理位置，请把整个文件夹移动到自己的主目录后重试。

## 服务连接失败

查看后台服务状态：

```bash
launchctl print "gui/$(id -u)/com.voicebank.voice-input"
```

重新安装并启动：

```bash
./server/scripts/install_launchd.sh
```

查看最近的服务输出：

```bash
tail -n 80 server/logs/launchd.out.log
tail -n 80 server/logs/launchd.err.log
```

如果日志显示找不到 Python 或服务端项目文件，通常是服务端源码目录被移动或删除了。回到新的项目目录，重新运行服务端安装脚本。客户端 App 不依赖源码目录。

## 健康检查显示 `starting_or_unavailable`

首次运行需要下载并载入 FunASR 模型，可能需要一段时间。保持网络连接并查看：

```bash
tail -f server/logs/launchd.out.log
```

模型准备完成后会出现 `voice_input_asr_loaded`。按 `Control+C` 退出日志查看不会停止后台服务。

如果日志明确显示模型下载失败，请确认磁盘空间和网络后重新启动服务：

```bash
launchctl kickstart -k "gui/$(id -u)/com.voicebank.voice-input"
```

## 端口 `8767` 已被占用

检查占用端口的程序：

```bash
lsof -nP -iTCP:8767 -sTCP:LISTEN
```

如果是旧的 Voice Bank 服务，重新运行 `./server/scripts/install_launchd.sh`。如果是其他应用，可为 Voice Bank 选择新端口，但服务端、客户端转写地址和健康检查地址必须保持一致。

## App 无法打开或提示无法验证开发者

当前没有正式签名的公开安装包。正式 Release 应经过 Developer ID 签名和 Apple 公证。如果你自行从可信源码构建了临时签名版本：

1. 尝试打开一次 App。
2. 前往 **系统设置 > 隐私与安全性**。
3. 找到被阻止的 Voice Bank，选择“仍要打开”。

如果 App 一打开就退出，请从项目根目录重新构建并安装：

```bash
./menu_bar/install_voicebank_app.sh
open "/Applications/Voice Bank.app"
```

## 右侧 `Option` 没反应

1. 确认按的是键盘右侧的 `Option`，左侧不会触发。
2. 前往 **系统设置 > 隐私与安全性 > 输入监控**，允许 Voice Bank。
3. 同时检查 **辅助功能** 权限。
4. 完全退出 Voice Bank 后重新打开。

如果权限列表中出现多个 Voice Bank，删除旧条目，只保留当前 `/Applications/Voice Bank.app`，再重新授权。

## 能录音，但没有识别结果

检查麦克风权限和服务状态：

```bash
curl http://127.0.0.1:8767/healthz
```

前往 **系统设置 > 隐私与安全性 > 麦克风**，确认 Voice Bank 已开启。录音不要短于约半秒，并确认系统选择了正确的输入设备。

## 有识别结果，但没有自动粘贴

- 检查 **系统设置 > 隐私与安全性 > 辅助功能** 是否允许 Voice Bank。
- Voice Bank 会向识别完成时的前台应用发送粘贴；如果处理中切换了应用，请检查当前光标位置。
- 某些密码框、安全输入框或受管应用会拒绝模拟粘贴，此时也请手动粘贴。

## App 显示服务连接失败

客户端不依赖源码目录、Python 或虚拟环境。请在 Voice Bank 首页的 **Mini 服务** 一行点击 **设置**，确认 `/transcribe` 地址正确，再点击 **测试**。本机服务通常使用：

```text
http://127.0.0.1:8767/transcribe
```

## 双机模式返回 `401 Unauthorized`

服务端和客户端的 `server-token` 内容必须完全一致，且文件权限必须为 `0600`：

```bash
ls -l "$HOME/Library/Application Support/Voice Bank/server-token"
```

修改令牌后要重启服务端，并重新打开客户端 App。不要在聊天、截图、公开 Issue 或日志中粘贴真实令牌。

## 双机模式连接超时

- 确认两台 Mac 已连接到同一个 Tailscale/VPN 网络。
- 确认客户端使用的是 VPN 地址，而不是会变化的局域网地址。
- 确认服务端使用 `VOICE_BANK_VOICE_INPUT_HOST=0.0.0.0` 重新安装了后台服务。
- 检查 macOS 防火墙是否允许该连接。
- 不要在路由器上把 `8767` 直接映射到互联网。

## 磁盘空间不足

检查项目和模型缓存大小：

```bash
du -sh . server/.venv ~/.cache/modelscope 2>/dev/null
df -h "$HOME"
```

不再使用 Voice Bank 时，先卸载后台服务，再删除源码目录和 `~/.cache/modelscope` 中不再需要的模型。注意：ModelScope 缓存可能同时被其他 AI 项目使用，不要在不确定时整目录删除。

## 如何彻底重装

1. 退出菜单栏 App。
2. 执行 `./server/scripts/uninstall_launchd.sh`。
3. 在 Finder 中删除 `/Applications/Voice Bank.app`。
4. 如需重装服务端，将项目中的 `server/.venv` 移到废纸篓。
5. 按[中文安装教程](../README.zh-CN.md)重新安装。

重装客户端不会自动删除文字 History。请先决定是否保留 `~/Documents/Voice Bank/History`。
