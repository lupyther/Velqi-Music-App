"""yt-dlp stream resolver for the Velqi embedded backend.

Returns audio formats shaped to match Velqi's Dart `Audio.fromJson`
(itag / audioCodec / bitrate / loudnessDb / url / approxDurationMs / size),
so `StreamProvider.fetch()` consumes them with zero model changes.

This replaces the fragile `youtube_explode_dart` cipher/signature path:
yt-dlp keeps up with YouTube changes, the Dart side does not have to.
"""
import os
import tempfile
from datetime import datetime

import yt_dlp

_HERE = os.path.dirname(os.path.abspath(__file__))

# Active cookies file path (None = no cookies; set via set_cookies() or auto-detect at init).
_cookies_path = None


def _log(msg):
    print(f"[YTDLP {datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


def _resolve_bundled_cookies():
    """Return path to bundled cookies.txt extracted alongside the Python scripts, or None."""
    candidate = os.path.join(_HERE, "cookies.txt")
    if os.path.isfile(candidate) and os.path.getsize(candidate) > 0:
        return candidate
    return None


def _init_cookies():
    """Called once at module import: auto-detect bundled cookies."""
    global _cookies_path
    bundled = _resolve_bundled_cookies()
    if bundled:
        _cookies_path = bundled
        _log(f"cookies loaded from bundle: {bundled}")
    else:
        _log("no bundled cookies found; running unauthenticated")


# Run at import time.
_init_cookies()

# Path for user-supplied cookies (writable, takes precedence over bundled).
_USER_COOKIES_PATH = os.path.join(_HERE, "cookies_user.txt")


def set_cookies(content: str) -> bool:
    """Write user-supplied Netscape cookie content to disk and activate it.

    Returns True on success. If content is empty/None, reverts to bundled cookies.
    """
    global _cookies_path
    if not content or not content.strip():
        # Revert to bundled cookies.
        if os.path.isfile(_USER_COOKIES_PATH):
            try:
                os.remove(_USER_COOKIES_PATH)
            except Exception:
                pass
        bundled = _resolve_bundled_cookies()
        _cookies_path = bundled
        _log("user cookies cleared; reverted to bundled" if bundled else "user cookies cleared; no cookies active")
        return True
    try:
        with open(_USER_COOKIES_PATH, "w", encoding="utf-8") as f:
            f.write(content)
        _cookies_path = _USER_COOKIES_PATH
        _log(f"user cookies saved ({len(content)} chars)")
        return True
    except Exception as e:
        _log(f"failed to save user cookies: {e}")
        return False


def get_cookies_status() -> dict:
    """Return current cookies status for the /cookies/status endpoint."""
    if _cookies_path and os.path.isfile(_cookies_path):
        is_user = _cookies_path == _USER_COOKIES_PATH
        return {
            "active": True,
            "source": "user" if is_user else "bundled",
            "path": _cookies_path,
        }
    return {"active": False, "source": "none", "path": None}


def _base_opts():
    opts = {
        "quiet": True,
        "no_warnings": True,
        "nocheckcertificate": True,
        "socket_timeout": 15,
        "retries": 4,
        "fragment_retries": 5,
        "skip_download": True,
        "check_formats": False,
        "extractor_retries": 3,
        "force_ipv4": True,
        # tv_embedded + android: tv_embedded skips the signature challenge entirely
        # (no JS player needed), android is the fast fallback. Together they resolve
        # a stream URL in ~300-600ms vs ~1-2s with the web client.
        "extractor_args": {
            "youtube": {
                "player_client": ["tv_embedded", "android"],
                "skip": ["hls", "dash"],   # we only need progressive/DASH audio
            }
        },
        "user_agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ),
    }
    # Inject cookies if available.
    if _cookies_path and os.path.isfile(_cookies_path):
        opts["cookiefile"] = _cookies_path
        _log(f"using cookies: {os.path.basename(_cookies_path)}")
    # Optional QuickJS runtime fallback if a `qjs` binary is bundled next to this file.
    qjs = os.path.join(_HERE, "qjs")
    if os.path.exists(qjs):
        try:
            os.chmod(qjs, 0o755)
        except Exception:
            pass
        opts["js_runtimes"] = {"quickjs": {"path": qjs}}
    return opts


def _extract_info(url, opts):
    """Try tv_embedded+android; on failure fall back to web client.

    tv_embedded skips the JS signature challenge so is the fastest path.
    If it errors (age-gate, etc.) we drop to yt-dlp's default web client.
    """
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            return ydl.extract_info(url, download=False)
    except Exception as e:
        _log(f"primary extract failed ({e}); retrying with web client")
        fb = dict(opts)
        ext = dict(fb.get("extractor_args") or {})
        yt = dict(ext.get("youtube") or {})
        # Drop to web client — handles age-gated and restricted content
        yt["player_client"] = ["web"]
        yt.pop("skip", None)
        ext["youtube"] = yt
        fb["extractor_args"] = ext
        with yt_dlp.YoutubeDL(fb) as ydl:
            return ydl.extract_info(url, download=False)


def _codec_name(acodec):
    a = (acodec or "").lower()
    if "mp4a" in a or "aac" in a:
        return "mp4a"
    return "opus"


def get_audio_formats(video_id):
    url = f"https://www.youtube.com/watch?v={video_id}"
    _log(f"resolving {video_id}")
    opts = _base_opts()
    opts["format"] = "bestaudio/best"
    info = _extract_info(url, opts)

    dur_ms = int((info.get("duration") or 0) * 1000)
    by_itag = {}
    for f in info.get("formats") or []:
        # audio-only formats with a usable direct url
        if f.get("acodec") in (None, "none"):
            continue
        if f.get("vcodec") not in (None, "none"):
            continue
        if not f.get("url"):
            continue
        # On YouTube, yt-dlp's format_id IS the itag (e.g. "140", "251");
        # DRC variants come as "251-drc" -> take the numeric head.
        head = str(f.get("format_id") or "").split("-")[0]
        if not head.isdigit():
            continue
        itag = int(head)
        abr = f.get("abr") or f.get("tbr") or 0
        size = f.get("filesize") or f.get("filesize_approx") or 0
        fmt = {
            "itag": itag,
            "audioCodec": _codec_name(f.get("acodec")),
            "bitrate": int(abr * 1000),
            "loudnessDb": 0.0,
            "url": f.get("url"),
            "approxDurationMs": dur_ms,
            "size": int(size or 0),
        }
        # de-dup itags (drc/non-drc), keep highest bitrate
        cur = by_itag.get(itag)
        if cur is None or fmt["bitrate"] > cur["bitrate"]:
            by_itag[itag] = fmt

    formats = list(by_itag.values())
    if formats:
        return formats

    # Fallback (OpenSudo behaviour): no audio-only DASH track was offered, so
    # use whatever single stream yt-dlp's "bestaudio/best" selector resolved.
    # As of 2026 the android client frequently returns only the muxed itag 18
    # (AAC+H.264 MP4); ExoPlayer/just_audio plays its audio track fine. The Dart
    # selectors fall back to audioFormats.first for unknown itags, so any itag
    # works here.
    sel_url = info.get("url")
    if sel_url:
        abr = info.get("abr") or info.get("tbr") or 0
        size = info.get("filesize") or info.get("filesize_approx") or 0
        head = str(info.get("format_id") or "0").split("-")[0]
        itag = int(head) if head.isdigit() else 0
        _log(f"no audio-only formats; using selected stream itag={itag}")
        return [{
            "itag": itag,
            "audioCodec": _codec_name(info.get("acodec")),
            "bitrate": int(abr * 1000),
            "loudnessDb": 0.0,
            "url": sel_url,
            "approxDurationMs": dur_ms,
            "size": int(size or 0),
        }]
    return []


def fetch_stream(video_id):
    """Payload consumed by Dart `StreamProvider.fetch()`."""
    try:
        audio_formats = get_audio_formats(video_id)
        if not audio_formats:
            return {"playable": False, "statusMSG": "No audio formats found", "audioFormats": []}
        return {"playable": True, "statusMSG": "OK", "audioFormats": audio_formats}
    except Exception as e:
        msg = str(e)
        low = msg.lower()
        if "unavailable" in low:
            status = "Song is unavailable"
        elif "private" in low:
            status = "Song is private"
        elif "sign in" in low or "age-restricted" in low or "age restricted" in low:
            status = "Song requires sign-in"
        elif "network" in low or "getaddrinfo" in low or "timed out" in low:
            status = "networkError"
        else:
            status = msg
        _log(f"error {video_id}: {msg}")
        return {"playable": False, "statusMSG": status, "audioFormats": []}
