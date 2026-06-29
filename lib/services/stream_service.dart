import 'dart:convert';

import 'package:dio/dio.dart';

import 'backend/backend_config.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: kBackendBaseUrl,
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Resolves audio formats via the embedded yt-dlp backend.
  ///
  /// Replaces the old `youtube_explode_dart` path. The returned shape is
  /// identical (List<Audio> by itag), so the selectors below, `hmStreamingData`
  /// and the downloader keep working unchanged.
  static Future<StreamProvider> fetch(String videoId) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final res =
            await _dio.get('/stream', queryParameters: {'videoId': videoId});
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        if (data['playable'] == true) {
          final formats = (data['audioFormats'] as List)
              .map((e) => Audio.fromJson(e))
              .toList();
          return StreamProvider(
              playable: true, statusMSG: "OK", audioFormats: formats);
        }
        return StreamProvider(
            playable: false,
            statusMSG: data['statusMSG']?.toString() ?? "Song is unplayable");
      } on DioException catch (e) {
        // The backend may still be warming up on first launch -> brief retry.
        final retriable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout;
        if (attempt < 2 && retriable) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return StreamProvider(playable: false, statusMSG: "networkError");
      } catch (e) {
        return StreamProvider(
            playable: false, statusMSG: "Unknown error occurred");
      }
    }
    return StreamProvider(playable: false, statusMSG: "networkError");
  }

  Audio? get highestQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 140,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateMp4aAudio =>
      audioFormats?.lastWhere((item) => item.itag == 140 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Audio? get highestBitrateOpusAudio =>
      audioFormats?.lastWhere((item) => item.itag == 251 || item.itag == 250,
          orElse: () => audioFormats!.first);

  Audio? get lowQualityAudio =>
      audioFormats?.lastWhere((item) => item.itag == 249 || item.itag == 139,
          orElse: () => audioFormats!.first);

  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson()
    };
  }
}

class Audio {
  final int itag;
  final Codec audioCodec;
  final int bitrate;
  final int duration;
  final int size;
  final double loudnessDb;
  final String url;
  Audio(
      {required this.itag,
      required this.audioCodec,
      required this.bitrate,
      required this.duration,
      required this.loudnessDb,
      required this.url,
      required this.size});

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.toString(),
        "bitrate": bitrate,
        "loudnessDb": loudnessDb,
        "url": url,
        "approxDurationMs": duration,
        "size": size
      };

  factory Audio.fromJson(json) => Audio(
      audioCodec: (json["audioCodec"] as String).contains("mp4a")
          ? Codec.mp4a
          : Codec.opus,
      itag: json['itag'],
      duration: json["approxDurationMs"] ?? 0,
      bitrate: json["bitrate"] ?? 0,
      loudnessDb: (json['loudnessDb'])?.toDouble() ?? 0.0,
      url: json['url'],
      size: json["size"] ?? 0);
}

enum Codec { mp4a, opus }
