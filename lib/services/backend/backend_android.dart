import 'package:serious_python/serious_python.dart';

import 'backend_runner.dart';

/// Android: runs the bundled Python app via serious_python.
///
/// The Python dependencies (yt-dlp, ytmusicapi, ...) are bundled into the APK
/// at build time from the venv pointed to by SERIOUS_PYTHON_SITE_PACKAGES.
/// main.py starts the localhost HTTP server (default port [kBackendPort]).
class AndroidBackendRunner extends BackendRunner {
  @override
  Future<void> start() async {
    await SeriousPython.run('assets/python_app.zip');
  }

  @override
  Future<void> terminate() async {
    SeriousPython.terminate();
  }
}
