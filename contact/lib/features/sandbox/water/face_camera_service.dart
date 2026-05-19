import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';

typedef FaceFrame = void Function(ui.Image image, Uint8List jpeg);

/// Periodically grabs a low-res still from the front camera. Capture starts
/// automatically once the OS grants the camera permission; if it is denied or
/// no camera exists, this stays silent (no face reflection).
class FaceCameraService {
  final FaceFrame onFrame;
  CameraController? _controller;
  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;

  FaceCameraService(this.onFrame);

  Future<void> start(Duration interval) async {
    List<CameraDescription> cams;
    try {
      cams = await availableCameras();
    } catch (_) {
      return;
    }
    if (cams.isEmpty || _disposed) return;

    final front = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    final controller = CameraController(
      front,
      ResolutionPreset.low,
      enableAudio: false,
    );
    try {
      await controller.initialize(); // triggers permission prompt
    } catch (_) {
      await controller.dispose();
      return; // permission denied / unavailable
    }
    if (_disposed) {
      await controller.dispose();
      return;
    }
    _controller = controller;

    await _capture();
    _timer = Timer.periodic(interval, (_) => _capture());
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || _busy || _disposed || !c.value.isInitialized) return;
    _busy = true;
    try {
      final shot = await c.takePicture();
      final bytes = await shot.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (_disposed) {
        frame.image.dispose();
        return;
      }
      onFrame(frame.image, bytes);
    } catch (_) {
      // transient capture failure — skip this tick
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _controller?.dispose();
    _controller = null;
  }
}
