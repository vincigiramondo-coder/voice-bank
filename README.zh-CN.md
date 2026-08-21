# Voice Bank 中文说明

[English](README.en.md) · [返回首页](README.md) · [故障排查](docs/TROUBLESHOOTING.zh-CN.md)

Voice Bank 是一套本地优先、可自托管的 macOS 语音输入工具。按一下键盘右侧 `Option` 开始录音，再按一下结束；客户端把音频发送到你配置的 Voice Bank 服务，收到文字后复制并粘贴到当前输入位置。

## 当前产品结构

- **Voice Bank.app**：原生 macOS 客户端，包含界面、菜单栏、录音 HUD、快捷键、录音、上传、History 和自动粘贴。
- **Voice Bank Server**：独立运行的识别服务，可安装在同一台 Mac，也可以放在局域网或 Tailscale 中的另一台 Mac。
- 客户端不依赖 Python、虚拟环境、源码目录或外部启动脚本；安装后可以删除下载包。

## 功能

- 右侧 `Option` 全局录音快捷键，不响应左侧 `Option`。
- 原生 SwiftUI 控制台、录音 HUD 和实时音量波形。
- 通过自托管服务完成 FunASR 转写和保守文本整理。
- 识别结果复制到剪贴板并发送 `Command+V`。
- 在 `~/Documents/Voice Bank/History` 保存本机文字 History。
- 临时录音使用当前用户私有的随机目录，处理完成后自动删除。
- 服务地址可以在 Voice Bank 首页直接修改和测试。

## 运行要求

客户端：

- Apple Silicon Mac（当前验证平台；Intel Mac 尚未验证）
- macOS 14 或更高版本
- 一个可访问的 Voice Bank `/transcribe` 服务

服务端：

- Apple Silicon Mac
- Python 3.13、FFmpeg 和足够的模型空间
- 建议至少 16GB 内存、8GB 可用磁盘空间

## 安装客户端

正式 Release 提供两种安装方式：

1. 双击 `Voice-Bank-<版本>.pkg`，按照 macOS 安装向导完成安装；或
2. 打开 DMG，把 `Voice Bank.app` 拖入 `Applications`。

首次打开后，在首页的 **Mini 服务** 一行点击 **设置**，填写服务地址，例如：

```text
http://127.0.0.1:8767/transcribe
```

如果服务运行在另一台 Mac，请填写它在局域网或 Tailscale 中可访问的地址。不要把 `8767` 直接暴露到互联网。

## 授予权限

首次使用需要允许：

1. **麦克风**：录制声音。
2. **输入监控**：监听右侧 `Option`。
3. **辅助功能**：发送 `Command+V` 完成自动粘贴。

权限通常位于 **系统设置 > 隐私与安全性**。修改权限后，退出并重新打开 Voice Bank。

## 开始使用

1. 把光标放到文本输入框。
2. 按一下右侧 `Option`，看到录音 HUD。
3. 说话。
4. 再按一下右侧 `Option`，等待识别和粘贴。
5. 处理过程中按 `Esc` 可以取消。

识别完成时，Voice Bank 会向当时位于前台的应用发送粘贴操作。处理期间如果切换了应用，请确认当前光标位置，避免粘贴到错误窗口。

## 安装本地服务

从源码安装服务端时，需要先准备 Python 3.13 和 FFmpeg。项目根目录执行：

```bash
VOICE_BANK_VOICE_INPUT_PYTHON="$(brew --prefix python@3.13)/bin/python3.13" \
  ./server/scripts/setup_runtime.sh
./server/scripts/install_launchd.sh
```

检查服务：

```bash
curl http://127.0.0.1:8767/healthz
```

返回包含 `"ok":true` 和 `"status":"ready"` 时即可使用。首次启动可能需要下载 FunASR 模型。

## 双机模式与令牌

如果服务监听非本机地址，服务端要求 Bearer 令牌。客户端从下面的仅当前用户可读文件中读取同一令牌：

```text
~/Library/Application Support/Voice Bank/server-token
```

文件权限应为 `600`。普通 HTTP 不加密内容，双机模式应放在 Tailscale/VPN 或 TLS 内。

## 隐私

- 临时录音处理后删除，不放进 GitHub，也不进入安装包。
- History、服务令牌和本机配置只保存在用户目录。
- 公共源码和 Release 不应包含私人 IP、个人路径、录音、转写历史、日志或凭据。
- 使用远程服务时，音频会发送到你在设置中指定的服务器。

完整边界见 [SECURITY.md](SECURITY.md)。

## 从源码构建客户端

客户端构建不需要 Python：

```bash
VOICEBANK_CODESIGN_IDENTITY=- ./menu_bar/build_menu_bar_app.sh
open "build/Voice Bank.app"
```

生成 DMG、PKG 和 ZIP：

```bash
./distribution/build_release.sh
```

公开发行前必须使用 Developer ID 对 App/PKG 签名并完成 Apple 公证，详见 [产品化说明](docs/PRODUCTIZATION.md)。

## 卸载

1. 从菜单栏退出 Voice Bank。
2. 删除 `/Applications/Voice Bank.app`。
3. 如不再需要服务端，执行 `./server/scripts/uninstall_launchd.sh`。
4. 如需删除文字 History，删除 `~/Documents/Voice Bank/History`。
5. 如配置过令牌，删除 `~/Library/Application Support/Voice Bank/server-token`。

## 许可证

Voice Bank 源码采用 [MIT License](LICENSE)。模型和第三方依赖保留各自许可证，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)；图标说明见 [ASSETS.md](ASSETS.md)。
