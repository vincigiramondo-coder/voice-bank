import os
import sys
import time
import argparse
import mimetypes
import json
import shutil
import signal
import tempfile
import requests
import subprocess
import uuid
from datetime import datetime, timedelta
from pathlib import Path

try:
    sys.stdout.reconfigure(line_buffering=True)
    sys.stderr.reconfigure(line_buffering=True)
except Exception:
    pass

# Override this local default when the voice server runs on another machine.
DEFAULT_SERVER_URL = "http://127.0.0.1:8767/transcribe"
SERVER_URL = os.getenv("VOICE_INPUT_SERVER_URL", DEFAULT_SERVER_URL)
SERVER_TOKEN = os.getenv("VOICE_INPUT_SERVER_TOKEN", "").strip()
REQUEST_TIMEOUT_SECONDS = int(os.getenv("VOICE_INPUT_TIMEOUT_SECONDS", "120"))
LOCAL_HISTORY_DIR = Path(
    os.path.expanduser(os.getenv("VOICE_BANK_LOCAL_HISTORY_DIR", "~/Documents/Voice Bank/History"))
)
TEMP_RECORDING_PREFIX = "voicebank-recording-"
STALE_RECORDING_SECONDS = int(os.getenv("VOICE_BANK_STALE_RECORDING_SECONDS", "21600"))
SAVE_LOCAL_HISTORY = os.getenv("VOICE_BANK_SAVE_LOCAL_HISTORY", "0") not in {"0", "false", "False", "no", "NO"}
HISTORY_RETENTION_DAYS = int(os.getenv("VOICE_BANK_HISTORY_RETENTION_DAYS", "30"))


def cleanup_stale_recordings() -> None:
    temp_root = Path(tempfile.gettempdir())
    cutoff = time.time() - STALE_RECORDING_SECONDS
    for candidate in temp_root.glob(f"{TEMP_RECORDING_PREFIX}*"):
        try:
            metadata = candidate.lstat()
            if candidate.is_symlink() or not candidate.is_dir():
                continue
            if metadata.st_uid != os.getuid() or metadata.st_mtime > cutoff:
                continue
            shutil.rmtree(candidate)
        except OSError:
            continue


def create_secure_recording_path() -> tuple[Path, Path]:
    temp_dir = Path(tempfile.mkdtemp(prefix=TEMP_RECORDING_PREFIX))
    temp_dir.chmod(0o700)
    return temp_dir, temp_dir / "recording.wav"


def install_termination_handlers() -> None:
    def terminate(signum, _frame):
        raise SystemExit(128 + signum)

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)

def record_audio(filename: str, duration_seconds: float | None = None):
    """
    录制麦克风音频。使用 macOS 自带的 'rec' (SoX) 或者是 pyaxio/sounddevice。
    为了尽量减少 Python 依赖，如果未安装 python 音频库，我们会尝试调用 macOS 的 'sox' 或是用 Python 最基础的 sounddevice 进行录制。
    这里使用 Python 'sounddevice' 和 'soundfile'，因为它们最稳定且支持在终端显示实时波形/状态。
    """
    try:
        import sounddevice as sd
        import soundfile as sf
        import numpy as np
    except ImportError:
        print("\n[错误] 本地缺少必要的音频库，请在 MacBook Air 终端执行以下命令安装：")
        print("pip install sounddevice soundfile numpy requests\n")
        sys.exit(1)

    samplerate = 16000  # Whisper 最优采样率
    channels = 1

    if duration_seconds is None:
        print("\n🎤 [已就绪] 按回车键 (Enter) 开始录音...")
        input()
    else:
        print(f"\n🎤 [已就绪] 将自动录音 {duration_seconds:.1f} 秒...")

    recording = []
    last_level_print_time = 0.0

    def callback(indata, frames, time_info, status):
        nonlocal last_level_print_time
        if status:
            print(status, file=sys.stderr)
        recording.append(indata.copy())
        now = time.time()
        if now - last_level_print_time >= 0.06:
            rms = float(np.sqrt(np.mean(np.square(indata))))
            level = min(1.0, rms * 18.0)
            print(f"VB_LEVEL {level:.3f}", flush=True)
            last_level_print_time = now

    # 开始录制流
    stream = sd.InputStream(samplerate=samplerate, channels=channels, callback=callback)
    with stream:
        if duration_seconds is None:
            print("🎙️ 正在录音... [按回车键 (Enter) 结束录音并发送]")
            input()
        else:
            print("🎙️ 正在录音...")
            time.sleep(duration_seconds)

    # 保存为 WAV 文件
    if not recording:
        print("[错误] 未录到音频。请确认麦克风权限已授权，并稍等片刻再结束录音。")
        sys.exit(4)

    audio_data = np.concatenate(recording, axis=0)
    if audio_data.shape[0] < int(samplerate * 0.35):
        print("[错误] 录音太短，没有足够音频可识别。")
        sys.exit(4)

    sf.write(filename, audio_data, samplerate)
    os.chmod(filename, 0o600)
    print("💾 录音已保存，正在传输至 Mac mini 进行处理...")

def set_clipboard_and_paste(text: str):
    """
    使用 macOS 系统的 pbcopy 写入剪贴板，并通过 AppleScript 模拟 Cmd+V 粘贴至当前光标位置。
    """
    if not text:
        return

    # 1. 写入剪贴板 (pbcopy)
    process = subprocess.Popen(['pbcopy'], stdin=subprocess.PIPE)
    process.communicate(input=text.encode('utf-8'))

    # 2. 模拟 Cmd+V 粘贴
    target_app = os.getenv("VOICE_INPUT_PASTE_TARGET_APP", "").strip()
    if target_app:
        subprocess.run(["open", "-a", target_app], check=False)
        time.sleep(0.2)
    applescript = 'tell application "System Events" to keystroke "v" using {command down}'
    subprocess.run(["osascript", "-e", applescript])
    print("✨ 已将整理后的文本自动粘贴到光标处！")

def pick_result_text(result: dict) -> tuple[str, str]:
    for key in ("polished", "polished_text", "text", "raw"):
        value = result.get(key)
        if value:
            return key, value
    return "", ""

def append_local_history(result: dict, output_text: str, server_url: str) -> dict:
    created_at = datetime.now().astimezone()
    history_id = f"air-{created_at.strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:8]}"
    raw_text = result.get("raw", "") or ""
    server_memory = result.get("memory") if isinstance(result.get("memory"), dict) else {}
    entry = {
        "id": history_id,
        "created_at": created_at.isoformat(timespec="seconds"),
        "date": created_at.strftime("%Y-%m-%d"),
        "time": created_at.strftime("%H:%M:%S"),
        "source": "air_voice_client",
        "server_url": server_url,
        "server_memory_id": server_memory.get("id"),
        "raw": raw_text,
        "polished": result.get("polished", "") or output_text,
        "text": output_text,
        "raw_chars": len(raw_text),
        "text_chars": len(output_text),
        "duration": result.get("duration"),
        "timings": result.get("timings", {}),
        "polish_mode": result.get("polish_mode"),
        "polish_guarded": result.get("polish_guarded"),
    }

    daily_dir = LOCAL_HISTORY_DIR / "daily"
    LOCAL_HISTORY_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    daily_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    LOCAL_HISTORY_DIR.chmod(0o700)
    daily_dir.chmod(0o700)
    prune_local_history(HISTORY_RETENTION_DAYS)

    index_path = LOCAL_HISTORY_DIR / "index.jsonl"
    with index_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + "\n")
    index_path.chmod(0o600)

    daily_path = daily_dir / f"{entry['date']}.md"
    with daily_path.open("a", encoding="utf-8") as handle:
        handle.write(f"\n## {entry['time']} · {entry['text_chars']} 字\n\n")
        handle.write(output_text.strip() + "\n")
        if raw_text and raw_text != output_text:
            handle.write("\n原始转写：\n\n")
            handle.write(raw_text.strip() + "\n")
    daily_path.chmod(0o600)

    return {
        "id": history_id,
        "dir": str(LOCAL_HISTORY_DIR),
        "index": str(index_path),
        "daily": str(daily_path),
        "text_chars": entry["text_chars"],
    }


def prune_local_history(retention_days: int) -> None:
    if retention_days <= 0 or not LOCAL_HISTORY_DIR.exists():
        return
    cutoff = (datetime.now().astimezone() - timedelta(days=retention_days)).date()
    daily_dir = LOCAL_HISTORY_DIR / "daily"
    if daily_dir.exists():
        for daily_path in daily_dir.glob("????-??-??.md"):
            try:
                if datetime.strptime(daily_path.stem, "%Y-%m-%d").date() < cutoff:
                    daily_path.unlink()
            except (OSError, ValueError):
                continue

    index_path = LOCAL_HISTORY_DIR / "index.jsonl"
    if not index_path.exists():
        return
    retained: list[str] = []
    for line in index_path.read_text(encoding="utf-8").splitlines():
        try:
            entry = json.loads(line)
            entry_date = datetime.strptime(str(entry.get("date", "")), "%Y-%m-%d").date()
            if entry_date >= cutoff:
                retained.append(line)
        except (ValueError, TypeError, json.JSONDecodeError):
            continue
    temp_index = LOCAL_HISTORY_DIR / f".index-{uuid.uuid4().hex}.tmp"
    temp_index.write_text("\n".join(retained) + ("\n" if retained else ""), encoding="utf-8")
    temp_index.chmod(0o600)
    os.replace(temp_index, index_path)


def clear_local_history() -> None:
    if LOCAL_HISTORY_DIR.exists():
        shutil.rmtree(LOCAL_HISTORY_DIR)

def transcribe_audio(audio_path: str, server_url: str) -> dict:
    mime_type = mimetypes.guess_type(audio_path)[0] or 'application/octet-stream'
    with open(audio_path, 'rb') as f:
        files = {'file': (os.path.basename(audio_path), f, mime_type)}
        session = requests.Session()
        session.trust_env = False
        headers = {"Authorization": f"Bearer {SERVER_TOKEN}"} if SERVER_TOKEN else {}
        response = session.post(server_url, files=files, headers=headers, timeout=REQUEST_TIMEOUT_SECONDS)
        response.raise_for_status()
        return response.json()

def parse_args():
    parser = argparse.ArgumentParser(description="Air Voice Bank voice_input client")
    parser.add_argument(
        "--server-url",
        default=SERVER_URL,
        help="Transcribe endpoint. Defaults to localhost or VOICE_INPUT_SERVER_URL.",
    )
    parser.add_argument(
        "--file",
        default="",
        help="Upload an existing audio file instead of recording from the microphone.",
    )
    parser.add_argument(
        "--no-paste",
        action="store_true",
        help="Print the returned text without writing clipboard or sending Cmd+V.",
    )
    parser.add_argument(
        "--keep-audio",
        action="store_true",
        help="Copy the recording to a unique owner-only file in the current directory after processing.",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=0,
        help="Record for N seconds without interactive Enter prompts. Useful for menu bar app launchers.",
    )
    history_group = parser.add_mutually_exclusive_group()
    history_group.add_argument("--save-history", dest="save_history", action="store_true")
    history_group.add_argument("--no-history", dest="save_history", action="store_false")
    parser.set_defaults(save_history=None)
    parser.add_argument(
        "--history-retention-days",
        type=int,
        default=HISTORY_RETENTION_DAYS,
        help="Delete local text-history entries older than N days when history is enabled.",
    )
    parser.add_argument(
        "--clear-history",
        action="store_true",
        help="Delete all local Voice Bank text history and exit.",
    )
    return parser.parse_args()

def main():
    args = parse_args()
    install_termination_handlers()
    cleanup_stale_recordings()
    if args.clear_history:
        clear_local_history()
        print("本机 Voice Bank 文字历史已清空。")
        return

    save_history = SAVE_LOCAL_HISTORY if args.save_history is None else args.save_history
    global HISTORY_RETENTION_DAYS
    HISTORY_RETENTION_DAYS = max(1, args.history_retention_days)

    recorded_temp_audio = not args.file
    temp_dir: Path | None = None
    if recorded_temp_audio:
        temp_dir, audio_path = create_secure_recording_path()
    else:
        audio_path = Path(args.file).expanduser()

    try:
        if recorded_temp_audio:
            record_audio(str(audio_path), args.duration if args.duration > 0 else None)

        if not audio_path.exists():
            print("[错误] 未找到音频文件。")
            sys.exit(1)

        start_time = time.time()
        print(f"⏳ 正在发送到 Voice Bank voice_input: {args.server_url}")
        result = transcribe_audio(str(audio_path), args.server_url)
        text_key, output_text = pick_result_text(result)
        raw_text = result.get("raw", "")
        polished_text = result.get("polished", "")

        print(f"\n📝 原始转录: {raw_text}")
        print(f"💎 输出文本 ({text_key or 'empty'}): {output_text}")
        print(f"⏱️ 耗时: {time.time() - start_time:.2f} 秒")

        if not output_text:
            print("[警告] 服务返回成功，但没有 raw/polished/text 字段可用于粘贴。")
            sys.exit(3)
        if save_history:
            history = append_local_history(result, output_text, args.server_url)
            print(f"🗂️ 本机文字记录已保存: {history['daily']}")
        if args.no_paste:
            return
        set_clipboard_and_paste(output_text)

    except requests.exceptions.RequestException as e:
        print("\n[连接失败] 无法访问语音服务。请确认服务已启动，并检查 VOICE_INPUT_SERVER_URL。")
        print(f"错误详情: {e}")
        sys.exit(2)
    except Exception as e:
        print(f"\n[执行错误]: {e}")
        sys.exit(1)
    finally:
        if recorded_temp_audio and args.keep_audio and audio_path.exists():
            kept_audio = Path.cwd() / f"voicebank-recording-{uuid.uuid4().hex}.wav"
            shutil.copy2(audio_path, kept_audio)
            kept_audio.chmod(0o600)
            print(f"录音副本已保存: {kept_audio}")
        if temp_dir is not None:
            shutil.rmtree(temp_dir, ignore_errors=True)

if __name__ == "__main__":
    main()
