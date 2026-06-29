import 'package:serious_python/serious_python.dart';

import 'backend_config.dart';
import 'backend_runner.dart';

/// Desktop (Windows): runs the bundled Python app via serious_python,
/// exactly like Android. The serious_python plugin embeds a full Python
/// runtime (python312.dll + Lib/ + DLLs/) next to the executable and
/// handles extraction and execution of the zip asset.
class DesktopBackendRunner extends BackendRunner {
  @override
  Future<void> start() async {
    await SeriousPython.run(
      'assets/python_app.zip',
      environmentVariables: {
        'PORT': '$kBackendPort',
        'PYTHONUTF8': '1',
        'PYTHONIOENCODING': 'utf-8',
      },
    );
  }

  @override
  Future<void> terminate() async {
    SeriousPython.terminate();
  }
}
