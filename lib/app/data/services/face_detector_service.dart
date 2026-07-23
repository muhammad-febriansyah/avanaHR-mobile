import 'dart:io';
import 'dart:ui' show Offset;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

/// Thin wrapper around ML Kit face detection. Classification (smiling / eyes
/// open) and head-angle data are enabled so enrollment can gate on face quality
/// and run a lightweight active-liveness challenge (neutral → smile).
class FaceDetectorService {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
      // Face must fill ≥30% of the frame width to be detected at all — rejects
      // faces that are too far away ("dekatkan wajah").
      minFaceSize: 0.30,
    ),
  );

  /// Detect faces in the image at [path] (a captured photo file).
  Future<List<Face>> detectFile(String path) {
    return _detector.processImage(InputImage.fromFilePath(path));
  }

  /// Whether [f] is a usable capture: a full, roughly frontal face with both
  /// eyes open. Rejects profiles, tilted heads, closed eyes, and — crucially —
  /// far / partial captures (e.g. only the forehead in frame), which ML Kit
  /// reports with null pose/eye data that previously defaulted to "good".
  bool isFrontalOpenEyes(Face f) {
    final yaw = f.headEulerAngleY;
    final roll = f.headEulerAngleZ;
    // Pose must actually be measured; a poor/partial capture returns null.
    if (yaw == null || roll == null || yaw.abs() > 15 || roll.abs() > 15) {
      return false;
    }

    // Eye-open classification must be present (null when the face is too far or
    // partly out of frame) and both eyes open.
    final leftEye = f.leftEyeOpenProbability;
    final rightEye = f.rightEyeOpenProbability;
    if (leftEye == null || rightEye == null || leftEye < 0.5 || rightEye < 0.5) {
      return false;
    }

    // Both eyes and the nose must be in frame, so a partial face (only the
    // forehead, chin, or a cheek) is rejected rather than embedded.
    if (f.landmarks[FaceLandmarkType.leftEye] == null ||
        f.landmarks[FaceLandmarkType.rightEye] == null ||
        f.landmarks[FaceLandmarkType.noseBase] == null) {
      return false;
    }

    return true;
  }

  double _frameW = 0;
  double _frameH = 0;

  /// Whether [f] sits roughly in the middle of the frame — rejects captures
  /// where the phone is pointed away and the face drifts to an edge/corner, the
  /// way a normal face-recognition prompt requires the face centered. Learns the
  /// frame size once from [path] (all captures share the camera resolution).
  Future<bool> isCentered(Face f, String path) async {
    if (_frameW <= 0 || _frameH <= 0) {
      final size = await _bakedSize(path);
      if (size == null) {
        return true; // unknown frame size → don't block
      }
      _frameW = size.$1;
      _frameH = size.$2;
    }

    final cx = f.boundingBox.center.dx / _frameW;
    final cy = f.boundingBox.center.dy / _frameH;

    return cx > 0.28 && cx < 0.72 && cy > 0.22 && cy < 0.78;
  }

  /// EXIF-corrected pixel dimensions of the image at [path] (matches ML Kit's
  /// coordinate space), or null on failure.
  Future<(double, double)?> _bakedSize(String path) async {
    try {
      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (decoded == null) {
        return null;
      }
      final baked = img.bakeOrientation(decoded);

      return (baked.width.toDouble(), baked.height.toDouble());
    } catch (_) {
      return null;
    }
  }

  /// Left-eye landmark position (image px) for eye-aligned embedding, or null.
  Offset? leftEyeOf(Face f) => _landmark(f, FaceLandmarkType.leftEye);

  /// Right-eye landmark position (image px) for eye-aligned embedding, or null.
  Offset? rightEyeOf(Face f) => _landmark(f, FaceLandmarkType.rightEye);

  Offset? _landmark(Face f, FaceLandmarkType type) {
    final p = f.landmarks[type]?.position;

    return p == null ? null : Offset(p.x.toDouble(), p.y.toDouble());
  }

  void dispose() {
    _detector.close();
  }
}
