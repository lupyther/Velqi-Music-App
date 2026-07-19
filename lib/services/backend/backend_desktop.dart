import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'backend_config.dart';
import 'backend_runner.dart';

/// Desktop (Windows): extracts python_app.zip and runs main.py as a
/// separate process using a system Python installation.
class DesktopBackendRunner extends BackendRunner {
  Process? _process;

  @override
  Future<void> start() async {
    // 1. Find a working Python executable
    final pythonExe = await _findPython();
    if (pythonExe == null) {
      throw Exception(
          'No Python installation found. Install Python 3.10+ and add it to PATH.');
    }
    print('[BACKEND] Python: $pythonExe');

    // 2. Extract python_app.zip to a persistent directory
    final supportDir = await getApplicationSupportDirectory();
    final appDir = Directory(p.join(supportDir.path, 'velqi_backend'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    final bytes = await rootBundle.load('assets/python_app.zip');
    final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
    await extractArchiveToDiskAsync(archive, appDir.path, asyncWrite: true);

    final mainPy = p.join(appDir.path, 'main.py');
    if (!await File(mainPy).exists()) {
      throw Exception('main.py not found after extraction at $mainPy');
    }
    print('[BACKEND] Extracted to: ${appDir.path}');

    // 3. Run main.py as a child process
    try {
      _process = await Process.start(
        pythonExe,
        [mainPy],
        environment: {
          'PORT': '$kBackendPort',
          'PYTHONUTF8': '1',
          'PYTHONIOENCODING': 'utf-8',
          'PYTHONNOUSERSITE': '1',
        },
        workingDirectory: appDir.path,
        runInShell: false,
      );

      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .listen((line) {
        print('[PY OUT] $line');
      });
      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((line) {
        print('[PY ERR] $line');
      });

      _process!.exitCode.then((code) {
        print('[BACKEND] Python exited with code $code');
        _process = null;
      });

      print('[BACKEND] process started (pid=${_process!.pid})');
    } catch (e) {
      print('[BACKEND] FAILED to start Python process: $e');
      rethrow;
    }
  }

  @override
  Future<void> terminate() async {
    _process?.kill(ProcessSignal.sigterm);
    _process = null;
  }

  /// Search for a working Python 3.10+ installation.
  static Future<String?> _findPython() async {
    final candidates = [
      'python',
      'python3',
      'py',
      r'C:\Python312\python.exe',
      r'C:\Python311\python.exe',
      r'C:\Python310\python.exe',
    ];

    for (final cmd in candidates) {
      try {
        final result = await Process.run(
          cmd,
          ['--version'],
          environment: {'PYTHONUTF8': '1'},
        );
        if (result.exitCode == 0) {
          final ver = result.stdout.toString().trim();
          final match = RegExp(r'Python (\d+)\.(\d+)').firstMatch(ver);
          if (match != null) {
            final major = int.parse(match.group(1)!);
            final minor = int.parse(match.group(2)!);
            if (major == 3 && minor >= 10) {
              // If bare command worked, use it directly
              if (!cmd.contains(r'\') && !cmd.contains('/')) {
                return cmd;
              }
              // Otherwise use the absolute path
              if (await File(cmd).exists()) return cmd;
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
