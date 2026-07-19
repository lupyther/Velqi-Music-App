import 'dart:io';

import 'package:dio/dio.dart';

import 'backend_android.dart';
import 'backend_config.dart';
import 'backend_desktop.dart';
import 'backend_runner.dart';

/// Orchestrates the embedded Python backend lifecycle and readiness.
class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: kBackendBaseUrl,
    connectTimeout: const Duration(seconds: 4),
  ));

  BackendRunner? _runner;
  bool _started = false;
  bool _ready = false;
  Future<bool>? _readyFuture;
  String? _lastError;

  bool get isReady => _ready;
  String? get lastError => _lastError;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Check if the backend is already running (e.g. process wasn't terminated or app is restarting within the same process)
    try {
      final res = await _dio.get('/ping',
          options: Options(receiveTimeout: const Duration(seconds: 1)));
      if (res.statusCode == 200) {
        final data = res.data is Map ? res.data : null;
        if (data != null && data['ok'] == true) {
          print('[BACKEND] already running, reusing existing process');
          return;
        }
      }
    } catch (_) {
      // Not running, proceed with starting it
    }

    _runner = Platform.isAndroid ? AndroidBackendRunner() : DesktopBackendRunner();
    try {
      await _runner!.start();
      print('[BACKEND] runner started');
    } catch (e) {
      _lastError = e.toString();
      print('[BACKEND] start error: $e');
    }
  }

  /// Polls /init until the Python side reports "initialized".
  Future<bool> ensureReady({Duration timeout = const Duration(seconds: 90)}) {
    if (_ready) return Future.value(true);
    return _readyFuture ??= _pollReady(timeout);
  }

  Future<bool> _pollReady(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await _dio.get('/init',
            options: Options(receiveTimeout: const Duration(seconds: 3)));
        final data = res.data is Map ? res.data : null;
        if (data != null && data['status'] == 'initialized') {
          _ready = true;
          print('[BACKEND] ready');
          return true;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 600));
    }
    _readyFuture = null;
    return false;
  }

  /// Returns the raw /init status map: {status, progress, message}.
  Future<Map<String, dynamic>> getInitStatus() async {
    final res = await _dio.get('/init',
        options: Options(receiveTimeout: const Duration(seconds: 3)));
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'status': 'importing', 'progress': 0, 'message': 'Iniciando...'};
  }

  Future<void> terminate() async {
    try {
      await _dio.get('/quit',
          options: Options(receiveTimeout: const Duration(seconds: 2)));
    } catch (_) {}
    await _runner?.terminate();
    _started = false;
    _ready = false;
    _readyFuture = null;
  }
}
