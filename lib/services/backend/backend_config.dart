/// Shared config for the embedded Python backend.
///
/// Kept free of plugin imports so it is safe to import from any isolate
/// (including the audio_service background isolate used by background_task.dart).
const int kBackendPort = 8765;
const String kBackendBaseUrl = 'http://127.0.0.1:$kBackendPort';
