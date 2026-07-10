import 'dart:core';
import 'package:flutter/services.dart';
import 'package:velqi/services/stream_service.dart';

Future<Map<String, dynamic>> getStreamInfo(String songId, dynamic token) async {
  if (songId.substring(0, 4) == "MPED") {
    songId = songId.substring(4);
  }
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final playerResponse = (await StreamProvider.fetch(songId));
  return playerResponse.hmStreamingData;
}
