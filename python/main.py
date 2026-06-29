"""Velqi embedded backend — localhost HTTP microservice.

Pattern: a stdlib http.server on 127.0.0.1 that the
Flutter app talks to over HTTP. Two responsibilities:
  - yt-dlp     -> audio stream formats        (ytdlp_backend)
  - ytmusicapi -> browse / search / metadata  (ytmusic_backend)

Runs embedded via serious_python on Android and via a bundled python.exe
on desktop. The Dart side polls /init until the backends finish importing.
"""
import atexit
import json
import os
import sys
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from http.server import BaseHTTPRequestHandler, HTTPServer

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.append(_HERE)

# Resolver y agregar la ruta de site-packages relativa al ejecutable (velqi.exe)
try:
    exe_dir = os.path.dirname(sys.executable)
    site_pkgs = os.path.join(exe_dir, "Lib", "site-packages")
    if os.path.isdir(site_pkgs) and site_pkgs not in sys.path:
        sys.path.insert(0, site_pkgs)
except Exception:
    pass

# serious_python may unpack bundled deps into ./site-packages
_SP = os.path.join(_HERE, "site-packages")
if os.path.isdir(_SP) and _SP not in sys.path:
    sys.path.append(_SP)

# Carga robusta de dependencias desde site-packages.zip en memoria (ZipImport - Android Velqi)
try:
    _ZIP_SP = os.path.join(_HERE, "site-packages.zip")
    if os.path.isfile(_ZIP_SP) and _ZIP_SP not in sys.path:
        sys.path.insert(0, _ZIP_SP)
except Exception as e:
    print(f"[BACKEND] Error loading site-packages.zip: {e}")

DEFAULT_PORT = 8765


def log(tag, msg):
    try:
        sys.stdout.write(f"[{tag}] {msg}\n")
        sys.stdout.flush()
    except Exception:
        pass


executor = ThreadPoolExecutor(max_workers=4)
_ready = {"ok": False, "pct": 0, "msg": "Preparando..."}
httpd = None


def _import_deps():
    try:
        _ready["pct"], _ready["msg"] = 20, "Cargando yt-dlp..."
        import ytdlp_backend  # noqa: F401
        _ready["pct"], _ready["msg"] = 60, "Cargando ytmusicapi..."
        import ytmusic_backend  # noqa: F401
        _ready["pct"], _ready["msg"], _ready["ok"] = 100, "Listo", True
        log("PY", "backends imported and ready")
    except Exception as e:
        _ready["pct"], _ready["msg"] = 0, f"Error: {e}"
        log("FATAL", f"import error: {e}")


executor.submit(_import_deps)


def _shutdown():
    executor.shutdown(wait=False, cancel_futures=True)


atexit.register(_shutdown)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        log("HTTP", fmt % args)

    def _json(self, data, status=200):
        try:
            body = json.dumps(data).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            log("HTTP", f"send error: {e}")

    def _run(self, fn, *args, timeout=30, **kwargs):
        return executor.submit(fn, *args, **kwargs).result(timeout=timeout)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        path = u.path
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode("utf-8") if content_length > 0 else ""
        except Exception:
            body = ""

        if path == "/cookies":
            if not _ready["ok"]:
                return self._json({"error": "not ready"}, 503)
            import ytdlp_backend
            import ytmusic_backend
            ok = ytdlp_backend.set_cookies(body)
            # Reset ytmusicapi client so it picks up fresh state if needed.
            ytmusic_backend.reset_client()
            return self._json({
                "ok": ok,
                "status": ytdlp_backend.get_cookies_status(),
            })

        return self._json({"error": f"not found: {path}"}, 404)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        path = u.path
        q = urllib.parse.parse_qs(u.query)

        def one(key, default=None):
            v = q.get(key, [default])
            return v[0] if v else default

        if path == "/init":
            return self._json({
                "status": "initialized" if _ready["ok"] else "importing",
                "progress": _ready["pct"],
                "message": _ready["msg"],
            })
        if path == "/ping":
            return self._json({"ok": True})
        if path == "/quit":
            self._json({"status": "quitting"})
            if httpd is not None:
                executor.submit(httpd.shutdown)
            return

        if not _ready["ok"]:
            return self._json({"error": "not ready", "progress": _ready["pct"]}, 503)

        import ytdlp_backend
        import ytmusic_backend

        # Cookies status (no heavy work needed).
        if path == "/cookies/status":
            return self._json(ytdlp_backend.get_cookies_status())

        try:
            if path == "/stream":
                vid = one("videoId") or one("id")
                if not vid:
                    return self._json({"error": "missing videoId"}, 400)
                return self._json(self._run(ytdlp_backend.fetch_stream, vid, timeout=45))

            if path == "/home":
                return self._json(self._run(
                    ytmusic_backend.get_home, int(one("limit", "4")), timeout=45))

            if path == "/search":
                return self._json(self._run(
                    ytmusic_backend.search, one("q", ""),
                    filter=one("filter"), scope=one("scope"),
                    limit=int(one("limit", "30")), timeout=60))

            if path == "/suggestions":
                return self._json(self._run(
                    ytmusic_backend.get_search_suggestions, one("q", ""), timeout=20))

            if path == "/album":
                return self._json(self._run(
                    ytmusic_backend.get_album, one("browseId"), timeout=40))

            if path == "/album_browse_id":
                return self._json({"browseId": self._run(
                    ytmusic_backend.get_album_browse_id, one("audioPlaylistId"), timeout=25)})

            if path == "/playlist":
                lim = one("limit")
                return self._json(self._run(
                    ytmusic_backend.get_playlist, one("playlistId"),
                    limit=int(lim) if lim else None, timeout=75))

            if path == "/artist":
                return self._json(self._run(
                    ytmusic_backend.get_artist, one("channelId"), timeout=40))

            if path == "/song":
                return self._json(self._run(
                    ytmusic_backend.get_song, one("videoId"), timeout=25))

            if path == "/watch":
                return self._json(self._run(
                    ytmusic_backend.get_watch_playlist,
                    video_id=one("videoId"), playlist_id=one("playlistId"),
                    radio=one("radio", "false") == "true",
                    shuffle=one("shuffle", "false") == "true",
                    only_related=one("onlyRelated", "false") == "true",
                    limit=int(one("limit", "25")), timeout=60))

            if path == "/related":
                vid = one("videoId")
                if not vid:
                    return self._json({"error": "missing videoId"}, 400)
                return self._json(self._run(
                    ytmusic_backend.get_song_related, vid, timeout=50))

            if path == "/song_with_id":
                vid = one("videoId")
                if not vid:
                    return self._json({"error": "missing videoId"}, 400)
                return self._json(self._run(
                    ytmusic_backend.get_song_with_id, vid, timeout=50))

            if path == "/charts":
                return self._json(self._run(
                    ytmusic_backend.get_charts, one("category", "Trending"),
                    country=one("country", "ZZ"), timeout=50))

            if path == "/lyrics":
                return self._json(self._run(
                    ytmusic_backend.get_lyrics, one("browseId"), timeout=25))

            return self._json({"error": f"not found: {path}"}, 404)
        except TimeoutError:
            return self._json({"error": "timeout"}, 504)
        except Exception as e:
            return self._json({"error": str(e)}, 500)


def run(port=DEFAULT_PORT):
    global httpd
    httpd = HTTPServer(("127.0.0.1", port), Handler)
    log("PY", f"server on http://127.0.0.1:{port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()


def main():
    run(int(os.environ.get("PORT", str(DEFAULT_PORT))))


main()
