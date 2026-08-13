from __future__ import annotations

import asyncio
import hmac
import json
import os
import re
import subprocess
import tempfile
import threading
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import Any

import requests
import uvicorn
from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse


SERVICE_NAME = "voice_bank_voice_input"
SERVICE_VERSION = "v1.2"
DEFAULT_PORT = 8767
LOOPBACK_HOSTS = {"127.0.0.1", "::1", "localhost"}


def read_owner_only_token() -> str:
    token_path = Path.home() / "Library" / "Application Support" / "Voice Bank" / "server-token"
    try:
        metadata = token_path.stat()
        if metadata.st_uid != os.getuid() or metadata.st_mode & 0o077:
            return ""
        return token_path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""

ROOT = Path(__file__).resolve().parent
LOG_DIR = Path(os.environ.get("VOICE_BANK_VOICE_INPUT_LOG_DIR", ROOT / "logs"))
MEMORY_DIR = Path(os.environ.get("VOICE_BANK_MEMORY_DIR", ROOT / "data" / "history"))
OLLAMA_URL = os.environ.get("VOICE_BANK_OLLAMA_URL", "http://localhost:11434/api/generate")
MODEL_NAME = os.environ.get(
    "VOICE_BANK_POLISH_MODEL",
    "gemma4@sha256:c6eb396dbd5992bbe3f5cdb947e8bbc0ee413d7c17e2beaae69f5d569cf982eb",
)
SMART_POLISH_MODE = os.environ.get("VOICE_BANK_SMART_POLISH_MODE", "smart")
MODEL_POLISH_MIN_CHARS = int(os.environ.get("VOICE_BANK_MODEL_POLISH_MIN_CHARS", "120"))
PREWARM_POLISH_MODEL = os.environ.get("VOICE_BANK_PREWARM_POLISH_MODEL", "0") not in {"0", "false", "False", "no", "NO"}
SAVE_HISTORY = os.environ.get("VOICE_BANK_SAVE_HISTORY", "0") not in {"0", "false", "False", "no", "NO"}
DEBUG_TEXT_LOGS = os.environ.get("VOICE_BANK_DEBUG_TEXT_LOGS", "0") not in {"0", "false", "False", "no", "NO"}
MAX_UPLOAD_BYTES = int(os.environ.get("VOICE_BANK_MAX_UPLOAD_MB", "50")) * 1024 * 1024
MAX_AUDIO_SECONDS = int(os.environ.get("VOICE_BANK_MAX_AUDIO_SECONDS", "300"))
MAX_CONCURRENT_TRANSCRIPTIONS = max(1, int(os.environ.get("VOICE_BANK_MAX_CONCURRENT_TRANSCRIPTIONS", "1")))
SERVER_HOST = os.environ.get("VOICE_BANK_VOICE_INPUT_HOST", "127.0.0.1").strip()
API_TOKEN = (
    os.environ.get("VOICE_BANK_API_TOKEN", "").strip()
    or os.environ.get("VOICE_INPUT_SERVER_TOKEN", "").strip()
    or read_owner_only_token()
)
ALLOW_INSECURE_LAN = os.environ.get("VOICE_BANK_ALLOW_INSECURE_LAN", "0") not in {"0", "false", "False", "no", "NO"}
FUNASR_MODEL = os.environ.get(
    "VOICE_BANK_FUNASR_MODEL",
    "iic/speech_seaco_paraformer_large_asr_nat-zh-cn-16k-common-vocab8404-pytorch",
)
FUNASR_MODEL_REVISION = os.environ.get("VOICE_BANK_FUNASR_MODEL_REVISION", "v2.0.9")
PUNC_MODEL = os.environ.get(
    "VOICE_BANK_PUNC_MODEL",
    "iic/punc_ct-transformer_zh-cn-common-vocab272727-pytorch",
)
PUNC_MODEL_REVISION = os.environ.get("VOICE_BANK_PUNC_MODEL_REVISION", "v2.0.4")
IS_NON_LOOPBACK = SERVER_HOST not in LOOPBACK_HOSTS
ALLOWED_AUDIO_SUFFIXES = {".wav", ".m4a", ".mp3", ".flac", ".aiff", ".aif", ".ogg", ".webm"}

_asr_lock = threading.Lock()
_asr_model: Any | None = None
_startup_error: str | None = None
_polish_prewarm_status = "not_started"
_transcription_slots = asyncio.Semaphore(MAX_CONCURRENT_TRANSCRIPTIONS)


def normalize_text(text: str) -> str:
    text = re.sub(r"\s+", " ", text.replace("\u3000", " ")).strip()
    text = re.sub(r"(?<=[\u4e00-\u9fff])\s+(?=[\u4e00-\u9fff])", "", text)
    text = re.sub(r"\bhello\s+hello\b", "Hello hello", text, flags=re.IGNORECASE)
    return text


def ffprobe_duration(path: Path) -> float | None:
    command = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(path),
    ]
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=10)
        return round(float(result.stdout.strip()), 3)
    except Exception:
        return None


def load_asr_model() -> None:
    global _asr_model, _startup_error
    try:
        from funasr import AutoModel

        _asr_model = AutoModel(
            model=FUNASR_MODEL,
            model_revision=FUNASR_MODEL_REVISION,
            punc_model=PUNC_MODEL,
            punc_model_revision=PUNC_MODEL_REVISION,
            disable_update=True,
        )
        _startup_error = None
        print(f"voice_input_asr_loaded model={FUNASR_MODEL} punc={PUNC_MODEL}", flush=True)
    except Exception as exc:
        _startup_error = str(exc)
        print(f"voice_input_asr_load_failed error={exc}", flush=True)


def prewarm_polish_model() -> None:
    global _polish_prewarm_status
    if not PREWARM_POLISH_MODEL or SMART_POLISH_MODE == "local":
        _polish_prewarm_status = "disabled"
        return

    _polish_prewarm_status = "warming"
    payload = {
        "model": MODEL_NAME,
        "prompt": "预热",
        "stream": False,
        "keep_alive": -1,
        "options": {"temperature": 0.0, "num_predict": 1},
    }
    started = time.perf_counter()
    try:
        response = requests.post(OLLAMA_URL, json=payload, timeout=180)
        response.raise_for_status()
        _polish_prewarm_status = f"ready:{round(time.perf_counter() - started, 3)}s"
        print(f"voice_input_polish_model_prewarmed model={MODEL_NAME} seconds={round(time.perf_counter() - started, 3)}", flush=True)
    except Exception as exc:
        _polish_prewarm_status = f"failed:{exc}"
        print(f"voice_input_polish_model_prewarm_failed model={MODEL_NAME} error={exc}", flush=True)


@asynccontextmanager
async def lifespan(_: FastAPI):
    if IS_NON_LOOPBACK and not API_TOKEN and not ALLOW_INSECURE_LAN:
        raise RuntimeError(
            "Non-loopback mode requires VOICE_BANK_API_TOKEN. "
            "Set VOICE_BANK_ALLOW_INSECURE_LAN=1 only on an encrypted, trusted network."
        )
    if IS_NON_LOOPBACK and not API_TOKEN:
        print("WARNING: Voice Bank LAN mode has no authentication or TLS; use only inside an encrypted trusted network.", flush=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    if SAVE_HISTORY:
        MEMORY_DIR.mkdir(parents=True, exist_ok=True)
        (MEMORY_DIR / "daily").mkdir(parents=True, exist_ok=True)
    started = time.perf_counter()
    load_asr_model()
    print(f"voice_input_startup_asr_load_seconds={time.perf_counter() - started:.3f}", flush=True)
    threading.Thread(target=prewarm_polish_model, name="voice-bank-polish-prewarm", daemon=True).start()
    yield


app = FastAPI(
    title="Voice Bank Voice Input",
    version=SERVICE_VERSION,
    lifespan=lifespan,
    docs_url=None if IS_NON_LOOPBACK else "/docs",
    redoc_url=None if IS_NON_LOOPBACK else "/redoc",
    openapi_url=None if IS_NON_LOOPBACK else "/openapi.json",
)


@app.middleware("http")
async def require_bearer_token(request: Request, call_next):
    if API_TOKEN:
        authorization = request.headers.get("authorization", "")
        expected = f"Bearer {API_TOKEN}"
        if not hmac.compare_digest(authorization, expected):
            return JSONResponse(status_code=401, content={"detail": "Unauthorized"})
    return await call_next(request)


def transcribe_audio_with_resident_funasr(audio_path: Path) -> dict[str, Any]:
    if _asr_model is None:
        raise HTTPException(status_code=503, detail=f"FunASR model unavailable: {_startup_error or 'not loaded'}")

    duration = ffprobe_duration(audio_path)
    if duration is None or duration < 0.35:
        raise HTTPException(status_code=400, detail="Audio is empty or too short to transcribe")
    if duration > MAX_AUDIO_SECONDS:
        raise HTTPException(status_code=413, detail="The uploaded audio is too long")

    started = time.perf_counter()
    with _asr_lock:
        try:
            result = _asr_model.generate(input=str(audio_path), batch_size_s=60)
        except AssertionError as exc:
            raise HTTPException(status_code=400, detail=f"Invalid audio for ASR: {exc}") from exc
    asr_seconds = round(time.perf_counter() - started, 3)

    result_items = result if isinstance(result, list) else [result]
    segments = []
    for index, item in enumerate(result_items):
        if not isinstance(item, dict):
            continue
        text = normalize_text(str(item.get("text") or ""))
        if text:
            segments.append({"start": 0.0, "end": duration or 0.0, "index": index, "text": text})
    raw_text = normalize_text(" ".join(segment["text"] for segment in segments))
    return {"duration": duration, "segments": segments, "timings": {"asr_seconds": asr_seconds}}


def readable_char_count(text: str) -> int:
    return len(re.sub(r"[\s，。！？,.!?、；;：:\"'“”‘’（）()]+", "", text))


def rebalance_long_commas(text: str, max_span: int = 34) -> str:
    chars: list[str] = []
    span = 0
    for char in text:
        if char in "。！？.!?":
            chars.append(char)
            span = 0
        elif char in "，、；;":
            if span >= max_span:
                chars.append("。")
                span = 0
            else:
                chars.append("，")
        else:
            chars.append(char)
            if char.strip():
                span += 1
    return "".join(chars)


def split_long_plain_spans(text: str, max_span: int = 26) -> str:
    parts = re.split(r"([。！？])", text)
    rebuilt: list[str] = []
    for index in range(0, len(parts), 2):
        segment = parts[index]
        mark = parts[index + 1] if index + 1 < len(parts) else ""
        while readable_char_count(segment) > max_span:
            split_at = -1
            for pattern in (
                r"(所以|然后|但是|不过|因为|如果|另外|还有|感觉|确实|好像|现在|后面|这个呢|那这个)",
                r"(它是|他是|这是|我来|我看|你看|我发现|我记得|我觉得|看看)",
                r"(就是|对吧|对吗|是吧|怎么样|怎么说呢)",
            ):
                matches = list(re.finditer(pattern, segment))
                candidates = [
                    match.start()
                    for match in matches
                    if 8 <= readable_char_count(segment[: match.start()]) <= max_span
                ]
                if candidates:
                    split_at = candidates[-1]
                    break
            if split_at < 0:
                break
            rebuilt.append(segment[:split_at].rstrip("，、；;：:") + "。")
            segment = segment[split_at:]
        rebuilt.append(segment + mark)
    return "".join(rebuilt)


def apply_lightweight_sentence_breaks(text: str) -> str:
    text = normalize_text(text)
    text = re.sub(r"\s+([，。！？,.!?])", r"\1", text)
    text = re.sub(r"^好的(?=[\u4e00-\u9fff])", "好的，", text)

    # Short dictation should stay fast, but still needs readable sentence breaks.
    question_followers = (
        "我|你|他|她|它|我们|你们|他们|现在|之前|后面|这个|那个|另外|还有|"
        "然后|所以|但是|不过|因为|如果|感觉|确实|好像|接下来"
    )
    text = re.sub(rf"(吗|么|是不是|对不对|是吧|对吧)(?=(?:{question_followers}))", r"\1？", text)
    text = re.sub(
        r"(?<=[\u4e00-\u9fff])"
        r"(但(?!是)|但是|不过|所以|因为|如果|比如|另外|还有|然后|现在|接下来|确实|其实|主要是|好像|倒不是|简单说|总之|反正)"
        r"(?=[\u4e00-\u9fff])",
        r"，\1",
        text,
    )
    text = re.sub(r"因为([^，。！？]{1,6})，如果", r"因为\1如果", text)
    text = re.sub(r"^(哎|对|可以|行)(?=[\u4e00-\u9fff]{2,})", r"\1，", text)
    text = re.sub(r"^哦你看", "哦，你看", text)
    text = re.sub(r"我来试一下(?=这是)", "我来试一下，", text)
    text = re.sub(r"这是一个测试(?=看看|看)", "这是一个测试，", text)
    text = re.sub(r"(?<=[\u4e00-\u9fff])以及(?=[\u4e00-\u9fff])", "，以及", text)
    text = re.sub(r"(耶|呀)(?=(?:它|他|这个|那个|那|现在|后面|我|你))", r"\1。", text)
    text = re.sub(r"(对吗|是吧|对吧)(?=(?:它|他|这个|那个|那|现在|后面|我|你))", r"\1？", text)
    text = re.sub(r"(怎么说呢|这个呢)(?=(?:它|他|这个|那个|那|现在|后面|我|你))", r"\1，", text)
    text = re.sub(r"(?<=[\u4e00-\u9fff])(他还是|它还是|这还是)", r"，\1", text)
    text = text.replace("听得到吗听到", "听得到吗？听到")
    text = text.replace("听得到吗", "听得到吗？")
    text = text.replace("听到请回答", "听到请回答。")
    text = re.sub(r"^(Hello hello)(?=[\u4e00-\u9fff])", r"\1，", text)
    text = rebalance_long_commas(text)
    text = split_long_plain_spans(text)
    text = re.sub(r"[，、]\s*[，、]+", "，", text)
    text = re.sub(r"([。！？])\s*[，、]+", r"\1", text)
    text = text.replace("？？", "？").replace("。。", "。").replace("，，", "，")
    text = re.sub(r"(会不会[^。！？]{0,12}|怎么样|可以吗|能不能[^。！？]{0,12})。$", r"\1？", text)
    return text


def conservative_punctuate(raw_text: str) -> str:
    text = apply_lightweight_sentence_breaks(raw_text)
    if not re.search(r"[。！？.!?]$", text):
        if re.search(r"(吗|么|是不是|对不对|是吧|对吧)$", text):
            text += "？"
        else:
            text += "。"
    return text


DISFLUENCY_MARKERS = (
    "嗯",
    "呃",
    "啊",
    "额",
    "呃呃",
    "就是",
    "那个",
    "这个",
    "然后",
    "其实",
    "反正",
    "我觉得",
)


def strip_disfluencies_for_compare(text: str) -> str:
    text = normalize_text(text)
    for marker in DISFLUENCY_MARKERS:
        text = text.replace(marker, "")
    return text


def disfluency_score(text: str) -> int:
    normalized = normalize_text(text)
    return sum(normalized.count(marker) for marker in DISFLUENCY_MARKERS)


def local_smart_cleanup(raw_text: str) -> str:
    text = conservative_punctuate(raw_text)
    # Keep this deliberately conservative: remove repeated filler words, not content-bearing phrases.
    replacements = [
        (r"^(?:嗯|呃|额|啊|那个|这个|就是|然后)[，、\s]*", ""),
        (r"(^|[，。！？!?；;：:\s])(?:嗯|呃|额|啊)[，、\s]*", r"\1"),
        (r"(?:，|\s)*(?:嗯|呃|额|啊)(?=[，。！？!?；;：:\s]|$)", ""),
        (r"(?<=[\u4e00-\u9fff])(?:嗯|呃|额|啊)(?=[\u4e00-\u9fff])", ""),
        (r"(?:就是|那个|这个)[，、\s]*(?=(?:我|你|他|她|它|我们|你们|他们|这个|那个|现在|接下来|然后|如果|因为|所以|要|想|可以|需要|感觉|问题))", ""),
        (r"(?:然后)[，、\s]*(?=(?:然后|这个|那个|我|你|现在|接下来))", ""),
    ]
    for pattern, replacement in replacements:
        text = re.sub(pattern, replacement, text)
    text = re.sub(r"[，、]\s*[，、]+", "，", text)
    text = re.sub(r"^[，、\s]+", "", text)
    text = re.sub(r"\s+([，。！？；：])", r"\1", text)
    text = apply_lightweight_sentence_breaks(text)
    text = text.replace("？？", "？").replace("。。", "。").replace("，，", "，")
    if text and not re.search(r"[。！？.!?]$", text):
        text += "。"
    return normalize_text(text)


def compact_chars(text: str) -> str:
    return re.sub(r"[\s，。！？,.!?、；;：:\"'“”‘’（）()]+", "", text).lower()


def over_rewritten(raw_text: str, polished_text: str) -> bool:
    raw_compact = compact_chars(raw_text)
    polished_compact = compact_chars(polished_text)
    if not raw_compact or not polished_compact:
        return True
    raw_core = compact_chars(strip_disfluencies_for_compare(raw_text))
    polished_core = compact_chars(strip_disfluencies_for_compare(polished_text))
    minimum_length = int(len(raw_core or raw_compact) * 0.55)
    if len(polished_core or polished_compact) < max(4, minimum_length):
        return True
    compare_raw = raw_core or raw_compact
    compare_polished = polished_core or polished_compact
    raw_bigrams = {compare_raw[index : index + 2] for index in range(max(len(compare_raw) - 1, 0))}
    polished_bigrams = {compare_polished[index : index + 2] for index in range(max(len(compare_polished) - 1, 0))}
    return bool(raw_bigrams and len(raw_bigrams & polished_bigrams) / len(raw_bigrams) < 0.42)


def should_use_local_gate(raw_text: str) -> bool:
    if SMART_POLISH_MODE == "model":
        return False
    if SMART_POLISH_MODE == "local":
        return True
    compact = compact_chars(raw_text)
    if not compact:
        return True
    severe_noise_markers = ("听不清", "无法识别", "乱码", "呃呃呃呃")
    if any(marker in raw_text for marker in severe_noise_markers):
        return False
    return len(compact) <= MODEL_POLISH_MIN_CHARS


def query_ollama_to_polish(raw_text: str) -> tuple[str, float, bool, str]:
    normalized_raw = normalize_text(raw_text)
    conservative = local_smart_cleanup(normalized_raw)
    if should_use_local_gate(normalized_raw):
        return conservative, 0.0, False, "local_smart_gate"

    prompt = f"""你是中文语音输入法的本地智能整理模型。任务是把口语转写整理成可以直接发送的文字。

请执行：
1. 删除明显口水词和拖延词，例如“嗯、呃、啊、额、那个、这个、就是、然后然后”。
2. 自动加中文标点；长内容按语义分成短段落。
3. 调顺不通顺的表达，但保留原意、称呼、事实、数字、时间、专有名词和语气。
4. 不要总结，不要扩写，不要替用户新增观点。
5. 如果原文是问题，仍然保留为问题。

输出要求：只输出整理后的最终文本，不要解释。

原始转写：
{normalized_raw}

整理结果："""

    payload = {
        "model": MODEL_NAME,
        "prompt": prompt,
        "stream": False,
        "keep_alive": -1,
        "options": {"temperature": 0.0},
    }
    started = time.perf_counter()
    try:
        response = requests.post(OLLAMA_URL, json=payload, timeout=90)
        response.raise_for_status()
        polished = normalize_text(response.json().get("response", "")) or conservative
    except Exception as exc:
        print(f"voice_input_ollama_polish_failed error={exc}", flush=True)
        return conservative, round(time.perf_counter() - started, 3), True, "ollama_error_fallback"

    guarded = over_rewritten(normalized_raw, polished)
    if guarded:
        if DEBUG_TEXT_LOGS:
            print(f"voice_input_polish_guard_fallback raw={normalized_raw!r} model={polished!r}", flush=True)
        else:
            print("voice_input_polish_guard_fallback", flush=True)
        polished = conservative
    return polished, round(time.perf_counter() - started, 3), guarded, "ollama_smart_guarded" if guarded else "ollama_smart"


def segments_to_text(segments: list[dict[str, Any]]) -> str:
    return normalize_text(" ".join(str(segment.get("text") or "").strip() for segment in segments))


def append_voice_memory(
    *,
    raw_text: str,
    polished_text: str,
    duration: float | None,
    timings: dict[str, Any],
    polish_mode: str,
    polish_guarded: bool,
    client_host: str | None,
) -> dict[str, Any]:
    created_at = datetime.now().astimezone()
    memory_id = f"vb-{created_at.strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:8]}"
    entry = {
        "id": memory_id,
        "created_at": created_at.isoformat(timespec="seconds"),
        "date": created_at.strftime("%Y-%m-%d"),
        "time": created_at.strftime("%H:%M:%S"),
        "source": "mini_voice_input",
        "client_host": client_host,
        "raw": raw_text,
        "polished": polished_text,
        "text": polished_text,
        "raw_chars": len(raw_text),
        "text_chars": len(polished_text),
        "duration": duration,
        "timings": timings,
        "polish_mode": polish_mode,
        "polish_guarded": polish_guarded,
    }

    MEMORY_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    daily_dir = MEMORY_DIR / "daily"
    daily_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    MEMORY_DIR.chmod(0o700)
    daily_dir.chmod(0o700)

    index_path = MEMORY_DIR / "index.jsonl"
    with index_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + "\n")
    index_path.chmod(0o600)

    daily_path = daily_dir / f"{entry['date']}.md"
    with daily_path.open("a", encoding="utf-8") as handle:
        handle.write(f"\n## {entry['time']} · {entry['text_chars']} 字\n\n")
        handle.write(polished_text.strip() + "\n")
        if raw_text and raw_text != polished_text:
            handle.write("\n原始转写：\n\n")
            handle.write(raw_text.strip() + "\n")
    daily_path.chmod(0o600)

    return {
        "id": memory_id,
        "dir": str(MEMORY_DIR),
        "index": str(MEMORY_DIR / "index.jsonl"),
        "daily": str(daily_path),
        "text_chars": entry["text_chars"],
    }


@app.get("/healthz")
def healthz() -> dict[str, Any]:
    return {
        "ok": _asr_model is not None,
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "status": "ready" if _asr_model is not None else "starting_or_unavailable",
        "save_history": SAVE_HISTORY,
        "authentication": bool(API_TOKEN),
    }


async def save_upload_limited(upload: UploadFile, destination: Path) -> int:
    total_bytes = 0
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            while True:
                chunk = await upload.read(1024 * 1024)
                if not chunk:
                    break
                total_bytes += len(chunk)
                if total_bytes > MAX_UPLOAD_BYTES:
                    raise HTTPException(status_code=413, detail="The uploaded audio file is too large")
                handle.write(chunk)
    finally:
        await upload.close()
    if total_bytes == 0:
        raise HTTPException(status_code=400, detail="The uploaded audio file is empty")
    return total_bytes


@app.post("/transcribe")
async def transcribe(request: Request, file: UploadFile = File(...)) -> dict[str, Any]:
    total_started = time.perf_counter()
    suffix = Path(file.filename or "recording.wav").suffix.lower() or ".wav"
    if suffix not in ALLOWED_AUDIO_SUFFIXES:
        await file.close()
        raise HTTPException(status_code=415, detail="Unsupported audio file type")

    async with _transcription_slots:
        with tempfile.TemporaryDirectory(prefix="voice_bank_voice_input_") as temp_dir:
            audio_path = Path(temp_dir) / f"recording{suffix}"
            await save_upload_limited(file, audio_path)

            asr_result = await asyncio.to_thread(transcribe_audio_with_resident_funasr, audio_path)
            raw_text = segments_to_text(asr_result.get("segments", []))
            if DEBUG_TEXT_LOGS:
                print(f"voice_input_raw_text={raw_text}", flush=True)
            if not raw_text:
                return {
                    "service": SERVICE_NAME,
                    "raw": "",
                    "polished": "",
                    "text": "",
                    "segments": [],
                    "timings": asr_result.get("timings", {}),
                }

            polished_text, polish_seconds, polish_guarded, polish_mode = await asyncio.to_thread(
                query_ollama_to_polish, raw_text
            )
            timings = {
                **asr_result.get("timings", {}),
                "polish_seconds": polish_seconds,
                "total_seconds": round(time.perf_counter() - total_started, 3),
            }
            if DEBUG_TEXT_LOGS:
                print(f"voice_input_polished_text={polished_text}", flush=True)
            print(f"voice_input_timings={timings} polish_guarded={polish_guarded} polish_mode={polish_mode}", flush=True)
            memory = None
            if SAVE_HISTORY:
                memory = append_voice_memory(
                    raw_text=raw_text,
                    polished_text=polished_text,
                    duration=asr_result.get("duration"),
                    timings=timings,
                    polish_mode=polish_mode,
                    polish_guarded=polish_guarded,
                    client_host=request.client.host if request.client else None,
                )
                print(f"voice_input_memory_saved id={memory['id']}", flush=True)
            response = {
                "service": SERVICE_NAME,
                "raw": raw_text,
                "polished": polished_text,
                "text": polished_text,
                "segments": asr_result.get("segments", []),
                "duration": asr_result.get("duration"),
                "timings": timings,
                "polish_guarded": polish_guarded,
                "polish_mode": polish_mode,
            }
            if memory is not None:
                response["memory"] = memory
            return response


if __name__ == "__main__":
    port = int(os.environ.get("VOICE_BANK_VOICE_INPUT_PORT", str(DEFAULT_PORT)))
    uvicorn.run(app, host=SERVER_HOST, port=port)
