/// Platform-agnostic contract for starting/stopping the embedded Python backend.
abstract class BackendRunner {
  Future<void> start();
  Future<void> terminate();
}
