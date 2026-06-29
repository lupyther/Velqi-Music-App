// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:hive/hive.dart';

import '/models/album.dart';
import '/models/artist.dart';
import '/models/playlist.dart';
import '/models/media_Item_builder.dart';
import 'backend/backend_config.dart';

enum AudioQuality {
  Low,
  High,
}

/// Browse / search / metadata client for the embedded Python backend.
///
/// This used to be a hand-rolled YouTube InnerTube client (~950 lines of
/// fragile `nav()` paths). It now delegates to the embedded `ytmusicapi`
/// backend (see `python/ytmusic_backend.py`), which returns JSON already
/// shaped with the exact keys our model `fromJson` factories expect, plus a
/// `_type` tag per content item. So each method here is a thin HTTP call that
/// just builds the right model objects. ytmusicapi is actively maintained, so
/// YouTube Music structure changes are absorbed upstream.
class MusicServices extends getx.GetxService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: kBackendBaseUrl,
    connectTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 90),
  ));

  String _hlCode = 'en';

  @override
  void onInit() {
    init();
    super.onInit();
  }

  Future<void> init() async {
    try {
      _hlCode = Hive.box('AppPrefs').get('contentLanguage') ?? 'en';
    } catch (_) {
      _hlCode = 'en';
    }
  }

  set hlCode(String code) {
    _hlCode = code;
  }

  String get hlCode => _hlCode;

  /// GET against the backend with warm-up retries: on first launch the Python
  /// server may still be importing deps (HTTP 503) or not yet bound.
  /// Also retries on receiveTimeout/sendTimeout to survive slow 4G connections.
  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    // Up to 20 attempts to handle slow backend startup on first install
    // (serious_python needs to unpack archives + import ytdlp/ytmusicapi)
    for (int attempt = 0; attempt < 20; attempt++) {
      try {
        final res = await _dio.get(path, queryParameters: query);
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        if (data is Map && data['error'] != null && data['progress'] != null) {
          // backend not ready yet — wait and retry
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        return data;
      } on DioException catch (e) {
        final retriable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.response?.statusCode == 503 ||
            e.response?.statusCode == 429;
        if (attempt < 19 && retriable) {
          // Exponential backoff: 1 s → 2 s → 4 s → 6 s (capped at 6 s)
          final ms = 1000 * (1 << attempt.clamp(0, 2)).clamp(1, 6);
          await Future.delayed(Duration(milliseconds: ms));
          continue;
        }
        throw NetworkError();
      }
    }
    throw NetworkError();
  }

  /// POST raw text body to the backend (non-critical: failures are swallowed).
  Future<void> _post(String path, String body) async {
    try {
      await _dio.post(
        path,
        data: body,
        options: Options(
          contentType: 'text/plain; charset=utf-8',
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
    } catch (_) {
      // Cookie uploads are best-effort; never block the UI.
    }
  }

  /// Send cookie file content to the embedded Python backend.
  Future<void> postCookies(String cookieContent) async {
    await _post('/cookies', cookieContent);
  }

  /// Build the right model object from a `_type`-tagged backend item.
  dynamic _build(dynamic raw) {
    if (raw is! Map) return null;
    final item = Map<dynamic, dynamic>.from(raw);
    switch (item['_type']) {
      case 'song':
      case 'video':
        if (item['videoId'] == null) return null;
        return MediaItemBuilder.fromJson(item);
      case 'album':
        if (item['browseId'] == null) return null;
        return Album.fromJson(item);
      case 'playlist':
        if (item['playlistId'] == null) return null;
        return Playlist.fromJson(item);
      case 'artist':
        if (item['browseId'] == null) return null;
        return Artist.fromJson(item);
      default:
        return null;
    }
  }

  List _buildList(dynamic list) =>
      ((list as List?) ?? [])
          .map((e) => _build(e))
          .where((e) => e != null)
          .toList();

  /// Map a list of {title, contents:[...]} sections, building each item.
  List<Map<String, dynamic>> _buildSections(dynamic data) {
    final List sections = (data as List?) ?? [];
    return sections
        .whereType<Map>()
        .map<Map<String, dynamic>>((s) => {
              'title': s['title'] ?? '',
              'contents': _buildList(s['contents']),
            })
        .toList();
  }

  Future<dynamic> getHome({int limit = 4}) async {
    final data = await _get('/home', query: {'limit': limit});
    return _buildSections(data);
  }

  Future<List<Map<String, dynamic>>> getCharts(String catogory,
      {String? countryCode}) async {
    final data = await _get('/charts', query: {
      'category': catogory,
      if (countryCode != null) 'country': countryCode,
    });
    return _buildSections(data);
  }

  Future<Map<String, dynamic>> getWatchPlaylist(
      {String videoId = "",
      String? playlistId,
      int limit = 25,
      bool radio = false,
      bool shuffle = false,
      String? additionalParamsNext,
      bool onlyRelated = false}) async {
    if (videoId.isEmpty && playlistId == null) {
      throw Exception(
          "You must provide either a video id, a playlist id, or both");
    }
    final data = await _get('/watch', query: {
      if (videoId.isNotEmpty) 'videoId': videoId,
      if (playlistId != null) 'playlistId': playlistId,
      'radio': radio,
      'shuffle': shuffle,
      'onlyRelated': onlyRelated,
      'limit': limit,
    });
    if (onlyRelated) {
      return {'lyrics': data['lyrics'], 'related': data['related']};
    }
    return {
      'tracks': _buildList(data['tracks']),
      'playlistId': data['playlistId'],
      'lyrics': data['lyrics'],
      'related': data['related'],
      'additionalParamsForNext': data['additionalParamsForNext'],
    };
  }

  Future<String> getAlbumBrowseId(String audioPlaylistId) async {
    final data =
        await _get('/album_browse_id', query: {'audioPlaylistId': audioPlaylistId});
    return data is Map
        ? (data['browseId']?.toString() ?? audioPlaylistId)
        : audioPlaylistId;
  }

  dynamic getContentRelatedToSong(String videoId, String hlCode) async {
    final data = await _get('/related', query: {'videoId': videoId});
    return _buildSections(data);
  }

  dynamic getLyrics(String browseId) async {
    final data = await _get('/lyrics', query: {'browseId': browseId});
    return data is Map ? data['lyrics'] : data;
  }

  Future<Map<String, dynamic>> getPlaylistOrAlbumSongs(
      {String? playlistId,
      String? albumId,
      int limit = 3000,
      bool related = false,
      int suggestionsLimit = 0}) async {
    if (albumId != null) {
      final data = await _get('/album', query: {'browseId': albumId});
      final map = Map<String, dynamic>.from(data);
      map['tracks'] = _buildList(data['tracks']);
      map['duration_seconds'] = _sumDuration(map['tracks']);
      return map;
    }
    final data =
        await _get('/playlist', query: {'playlistId': playlistId, 'limit': limit});
    final map = Map<String, dynamic>.from(data);
    map['tracks'] = _buildList(data['tracks']);
    map['duration_seconds'] = _sumDuration(map['tracks']);
    return map;
  }

  int _sumDuration(List tracks) {
    int total = 0;
    for (final t in tracks) {
      try {
        total += (t.duration?.inSeconds as int?) ?? 0;
      } catch (_) {}
    }
    return total;
  }

  Future<List<String>> getSearchSuggestion(String queryStr) async {
    final data = await _get('/suggestions', query: {'q': queryStr});
    return ((data as List?) ?? []).map((e) => e.toString()).toList();
  }

  /// Specially created for deep-links.
  Future<List> getSongWithId(String songId) async {
    final data = await _get('/song_with_id', query: {'videoId': songId});
    if (data is List && data.length == 2) {
      final isMusic = data[0] == true;
      return [isMusic, isMusic ? _buildList(data[1]) : null];
    }
    return [false, null];
  }

  Future<Map<String, dynamic>> search(String query,
      {String? filter,
      String? scope,
      int limit = 30,
      bool ignoreSpelling = false,
      String? filterParams}) async {
    final data = await _get('/search', query: {
      'q': query,
      if (filter != null) 'filter': filter,
      if (scope != null) 'scope': scope,
      'limit': limit,
    });
    final Map<String, dynamic> out = {};
    final src = Map<String, dynamic>.from(data as Map);
    src.forEach((key, value) {
      if (key == 'searchEndpoint') {
        out['searchEndpoint'] = Map<String, dynamic>.from(value as Map);
      } else if (key == 'params') {
        out['params'] = value;
      } else if (value is List) {
        out[key] = _buildList(value);
      }
    });
    return out;
  }

  Future<Map<String, dynamic>> getSearchContinuation(Map additionalParamsNext,
      {int limit = 10}) async {
    // ytmusicapi returns full result sets in one call, so there is no
    // continuation to fetch. Return an empty page with a "no more" marker.
    final category = additionalParamsNext['category'];
    return {
      if (category != null) category: [],
      'params': {'additionalParams': '&ctoken=null&continuation=null'},
    };
  }

  Future<Map<String, dynamic>> getArtist(String channelId) async {
    final data = await _get('/artist', query: {'channelId': channelId});
    final map = Map<String, dynamic>.from(data as Map);
    for (final key in ['Songs', 'Videos', 'Albums', 'Singles']) {
      if (map[key] is Map && map[key]['content'] is List) {
        map[key] = Map<String, dynamic>.from(map[key]);
        map[key]['content'] = _buildList(map[key]['content']);
      }
    }
    return map;
  }

  Future<Map<String, dynamic>> getArtistRealtedContent(
      Map<String, dynamic> browseEndpoint, String category,
      {String additionalParams = ""}) async {
    // "View all" pagination for artist sections is not exposed by ytmusicapi's
    // simple API; the inline section content from getArtist is what we show.
    return {
      'results': [],
      'additionalParams': '&ctoken=null&continuation=null',
    };
  }

  Future<String?> getSongYear(String songId) async => null;

  @override
  void onClose() {
    _dio.close();
    super.onClose();
  }
}

class NetworkError extends Error {
  final message = "Network Error !";
}
