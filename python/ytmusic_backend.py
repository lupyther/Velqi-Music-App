"""ytmusicapi wrapper for the Velqi embedded backend (browse/search metadata).

This replaces the hand-rolled InnerTube client in `lib/services/music_service.dart`.
ytmusicapi is actively maintained, so YouTube Music structure changes are handled
upstream instead of by fragile Dart `nav()` paths.

Design: every function returns JSON shaped with the EXACT keys that Velqi's Dart
model `fromJson` factories expect (see lib/models/*.dart), plus a `_type` tag on each
content item ("song" | "video" | "album" | "playlist" | "artist") so the thin Dart
client knows which model to build. All the messy shape-mapping lives here.
"""
from datetime import datetime

from ytmusicapi import YTMusic

_yt = None


def _log(msg):
    print(f"[YTMUSIC {datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


def _configure_session(session):
    """Patch the ytmusicapi requests.Session for reliability on slow connections.

    - Mounts a retry adapter (3 attempts, exponential backoff) for transient errors.
    - Injects a per-request timeout so calls never hang indefinitely on poor 4G.
    """
    try:
        from requests.adapters import HTTPAdapter
        from urllib3.util.retry import Retry
        retry = Retry(
            total=3,
            backoff_factor=1.5,
            status_forcelist=[429, 500, 502, 503, 504],
            raise_on_status=False,
        )
        adapter = HTTPAdapter(max_retries=retry, pool_connections=2, pool_maxsize=4)
        session.mount("https://", adapter)
        session.mount("http://", adapter)

        # Monkey-patch to inject a timeout on every request.
        _orig = session.request

        def _request_with_timeout(method, url, **kwargs):
            kwargs.setdefault("timeout", 25)
            return _orig(method, url, **kwargs)

        session.request = _request_with_timeout
        _log("session retry/timeout configured")
    except Exception as e:
        _log(f"session config warning (non-fatal): {e}")


def _client():
    global _yt
    if _yt is None:
        _yt = YTMusic()  # unauthenticated
        try:
            _configure_session(_yt._session)
        except AttributeError:
            try:
                _configure_session(_yt.session)
            except Exception:
                pass
        _log("YTMusic session ready")
    return _yt


def reset_client():
    """Force a fresh YTMusic client on next call (used after cookies change)."""
    global _yt
    _yt = None


# ---------------------------------------------------------------------------
# Low-level mappers: ytmusicapi item -> Velqi model-contract dict
# ---------------------------------------------------------------------------

def _thumbs(item, fallback=None):
    """Return a non-empty thumbnails list of {'url': ...}.

    ytmusicapi uses 'thumbnails' (most items) or 'thumbnail' (watch tracks).
    Velqi's models read thumbnails[0]['url'], so we must never hand back [].
    """
    if not isinstance(item, dict):
        return fallback or [{"url": ""}]
    th = item.get("thumbnails") or item.get("thumbnail")
    if isinstance(th, list) and th:
        return [{"url": t.get("url", "")} for t in th if isinstance(t, dict)]
    if fallback:
        return fallback
    return [{"url": ""}]


def _artists(arts):
    """Normalize an artists list to [{'name': str, 'id': str|None}]."""
    out = []
    if isinstance(arts, list):
        for a in arts:
            if isinstance(a, dict):
                out.append({"name": a.get("name", ""), "id": a.get("id")})
            elif isinstance(a, str):
                out.append({"name": a, "id": None})
    return out or None


def _album_ref(alb):
    """Normalize a song's album reference to {'id': str, 'name': str} or None."""
    if isinstance(alb, dict) and alb.get("id"):
        return {"id": alb.get("id"), "name": alb.get("name", "")}
    return None


def _song(item, fallback_thumbs=None):
    """Map a ytmusicapi song/video -> MediaItemBuilder.fromJson contract."""
    is_video = (item.get("videoType") or "").startswith("MUSIC_VIDEO_TYPE_UGC") \
        or item.get("resultType") == "video"
    return {
        "_type": "video" if is_video else "song",
        "videoId": item.get("videoId"),
        "title": item.get("title"),
        "artists": _artists(item.get("artists")),
        "album": _album_ref(item.get("album")),
        "thumbnails": _thumbs(item, fallback_thumbs),
        # MediaItemBuilder uses 'duration' (int seconds) first, else parses 'length'
        "duration": item.get("duration_seconds"),
        "length": item.get("duration") if isinstance(item.get("duration"), str) else None,
        "year": item.get("year"),
    }


def _album(item):
    """Map a ytmusicapi album -> Album.fromJson contract."""
    return {
        "_type": "album",
        "title": item.get("title"),
        "browseId": item.get("browseId") or item.get("audioPlaylistId"),
        "artists": _artists(item.get("artists")) or [{"name": ""}],
        "year": item.get("year"),
        "audioPlaylistId": item.get("audioPlaylistId") or item.get("playlistId"),
        "thumbnails": _thumbs(item),
        "description": item.get("type") or "Album",
    }


def _playlist(item):
    """Map a ytmusicapi playlist -> Playlist.fromJson contract."""
    count = item.get("itemCount") or item.get("count")
    return {
        "_type": "playlist",
        "title": item.get("title"),
        "playlistId": item.get("playlistId") or item.get("browseId"),
        "thumbnails": _thumbs(item),
        "description": item.get("description") or "Playlist",
        "itemCount": str(count) if count is not None else None,
        "isCloudPlaylist": True,
    }


def _artist(item):
    """Map a ytmusicapi artist -> Artist.fromJson contract."""
    subs = item.get("subscribers")
    return {
        "_type": "artist",
        "artist": item.get("artist") or item.get("title") or item.get("name"),
        "browseId": item.get("browseId"),
        "radioId": item.get("radioId") or item.get("shuffleId"),
        "subscribers": subs,
        "thumbnails": _thumbs(item),
    }


def _classify(item):
    """Best-effort: turn one home/related content item into a tagged model dict."""
    if not isinstance(item, dict):
        return None
    bid = item.get("browseId") or ""
    if item.get("videoId"):
        return _song(item)
    if bid.startswith("UC") or (item.get("subscribers") is not None and not item.get("playlistId")):
        return _artist(item)
    if bid.startswith("MPRE"):
        return _album(item)
    if item.get("playlistId"):
        return _playlist(item)
    if bid:
        return _album(item)
    return None


def _section(sec):
    """Map a {title, contents:[...]} home/related section, classifying each item."""
    contents = []
    for it in sec.get("contents", []) or []:
        m = _classify(it)
        if m and m.get("videoId" if m["_type"] in ("song", "video") else
                       ("playlistId" if m["_type"] == "playlist" else "browseId")):
            contents.append(m)
    return {"title": sec.get("title") or "", "contents": contents}


# ---------------------------------------------------------------------------
# Public endpoints (called from main.py)
# ---------------------------------------------------------------------------

def get_home(limit=4):
    raw = _client().get_home(limit=max(limit, 4))
    sections = [_section(s) for s in raw if isinstance(s, dict)]
    # Drop empty sections but always keep something playable up top.
    sections = [s for s in sections if s["contents"]]
    return sections


def search(query, filter=None, scope=None, limit=30, ignore_spelling=False):
    raw = _client().search(query, filter=filter, scope=scope, limit=limit,
                           ignore_spelling=ignore_spelling)
    # Display-name buckets expected by the Dart search controller.
    buckets = {
        "Songs": [], "Videos": [], "Albums": [], "Artists": [],
        "Community playlists": [], "Featured playlists": [],
    }
    for it in raw:
        if not isinstance(it, dict):
            continue
        rt = it.get("resultType")
        if rt == "song":
            buckets["Songs"].append(_song(it))
        elif rt == "video":
            buckets["Videos"].append(_song(it))
        elif rt == "album":
            buckets["Albums"].append(_album(it))
        elif rt == "artist":
            buckets["Artists"].append(_artist(it))
        elif rt == "playlist":
            buckets["Community playlists"].append(_playlist(it))

    if filter:
        # Filtered call: return a single display-named bucket + a no-more params marker.
        name = _FILTER_TO_DISPLAY.get(filter, filter)
        items = buckets.get(name, [])
        if not items:  # fall back: collect whatever the filter produced
            for b in buckets.values():
                items.extend(b)
        return {
            name: items,
            "params": {"additionalParams": "&ctoken=null&continuation=null"},
        }

    # Unfiltered: build searchEndpoint chips for the tabs that actually have results.
    out = {"searchEndpoint": {}}
    for name, items in buckets.items():
        if items:
            out[name] = items
            out["searchEndpoint"][name] = name  # opaque token; reused as filterParams
    return out


_FILTER_TO_DISPLAY = {
    "songs": "Songs",
    "videos": "Videos",
    "albums": "Albums",
    "artists": "Artists",
    "community_playlists": "Community playlists",
    "featured_playlists": "Featured playlists",
    "playlists": "Community playlists",
}


def get_search_suggestions(query):
    res = _client().get_search_suggestions(query)
    out = []
    for s in res:
        if isinstance(s, str):
            out.append(s)
        elif isinstance(s, dict) and s.get("text"):
            out.append(s["text"])
    return out


def get_album(browse_id):
    raw = _client().get_album(browse_id)
    thumbs = _thumbs(raw)
    raw["thumbnails"] = thumbs
    raw["tracks"] = [_song(t, fallback_thumbs=thumbs) for t in raw.get("tracks", [])]
    # Album.fromJson on the Dart side reads these directly; keep type/year/artists.
    raw["artists"] = _artists(raw.get("artists")) or [{"name": ""}]
    return raw


def get_album_browse_id(audio_playlist_id):
    return _client().get_album_browse_id(audio_playlist_id)


def get_playlist(playlist_id, limit=None):
    raw = _client().get_playlist(playlist_id, limit=limit)
    thumbs = _thumbs(raw)
    raw["thumbnails"] = thumbs
    raw["tracks"] = [_song(t, fallback_thumbs=thumbs) for t in raw.get("tracks", [])]
    return raw


def get_artist(channel_id):
    raw = _client().get_artist(channel_id)
    out = {
        "name": raw.get("name"),
        "channelId": raw.get("channelId") or channel_id,
        "description": raw.get("description"),
        "views": raw.get("views"),
        "subscribers": raw.get("subscribers"),
        "thumbnails": _thumbs(raw),
        "shuffleId": raw.get("shuffleId"),
        "radioId": raw.get("radioId"),
    }

    def _sec(key, mapper):
        block = raw.get(key) or {}
        results = block.get("results") or []
        return {
            "browseId": block.get("browseId"),
            "params": block.get("params"),
            "content": [mapper(r) for r in results],
        }

    out["Songs"] = _sec("songs", lambda r: _song(r, fallback_thumbs=_thumbs(raw)))
    out["Videos"] = _sec("videos", _song)
    out["Albums"] = _sec("albums", _album)
    out["Singles"] = _sec("singles", _album)
    return out


def get_song(video_id):
    return _client().get_song(video_id)


def get_watch_playlist(video_id=None, playlist_id=None, radio=False, shuffle=False,
                       limit=25, only_related=False):
    raw = _client().get_watch_playlist(
        videoId=video_id or None, playlistId=playlist_id or None,
        radio=radio, shuffle=shuffle, limit=limit,
    )
    if only_related:
        return {"lyrics": raw.get("lyrics"), "related": raw.get("related")}
    return {
        "tracks": [_song(t) for t in raw.get("tracks", [])],
        "playlistId": raw.get("playlistId") or playlist_id,
        "lyrics": raw.get("lyrics"),
        "related": raw.get("related"),
        "additionalParamsForNext": None,
    }


def get_song_related(video_id):
    """Sections of content related to a song (for the home 'based on last' mode)."""
    wp = _client().get_watch_playlist(videoId=video_id, limit=1)
    related = wp.get("related")
    if not related:
        return []
    raw = _client().get_song_related(related)
    sections = [_section(s) for s in raw if isinstance(s, dict)]
    return [s for s in sections if s["contents"]]


def get_song_with_id(video_id):
    """Deep-link helper: ([isMusic], tracks|None)."""
    try:
        info = _client().get_song(video_id)
        details = info.get("videoDetails", {}) if isinstance(info, dict) else {}
        is_music = "musicVideoType" in details
    except Exception:
        is_music = True
    wp = get_watch_playlist(video_id=video_id)
    return [is_music, wp["tracks"]]


def get_charts(category="Trending", country="ZZ"):
    raw = _client().get_charts(country=country)
    out = []

    def _items(key):
        # ytmusicapi >=1.x returns chart categories as plain lists; older
        # builds wrapped them as {"items": [...]}. Handle both.
        v = raw.get(key)
        if isinstance(v, dict):
            v = v.get("items")
        return v if isinstance(v, list) else []

    # Top music videos -> playable songs/videos.
    videos = _items("videos") or _items("trending") or _items("songs")
    if videos:
        out.append({"title": "Top Music Videos",
                    "contents": [_song(v) for v in videos[:24]]})

    # Daily / weekly chart playlists (premium accounts expose these).
    for pkey, ptitle in (("daily", "Daily Top"), ("weekly", "Weekly Top")):
        pls = _items(pkey)
        if pls:
            out.append({"title": ptitle,
                        "contents": [_playlist(p) for p in pls[:24]]})

    # Genre chart playlists (US only).
    genres = _items("genres")
    if genres:
        out.append({"title": "Genres",
                    "contents": [_playlist(g) for g in genres[:24]]})

    # Top artists.
    artists = _items("artists")
    if artists:
        out.append({"title": "Top Artists",
                    "contents": [_artist(a) for a in artists[:24]]})

    return out


def get_lyrics(browse_id):
    try:
        raw = _client().get_lyrics(browse_id)
    except Exception as e:
        _log(f"lyrics error: {e}")
        return {"lyrics": None}
    if isinstance(raw, dict):
        return {"lyrics": raw.get("lyrics"), "source": raw.get("source")}
    return {"lyrics": raw}
