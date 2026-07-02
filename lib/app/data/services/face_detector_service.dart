import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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
      minFaceSize: 0.15,
    ),
  );

  /// Detect faces in the image at [path] (a captured photo file).
  Future<List<Face>> detectFile(String path) {
    return _detector.processImage(InputImage.fromFilePath(path));
  }

  /// Whether [f] is a usable capture: roughly frontal (small yaw/roll) with both
  /// eyes open. Rejects profiles, tilted heads, and closed-eye frames.
  bool isFrontalOpenEyes(Face f) {
    final yaw = (f.headEulerAngleY ?? 0).abs();
    final roll = (f.headEulerAngleZ ?? 0).abs();
    final leftEye = f.leftEyeOpenProbability ?? 1;
    final rightEye = f.rightEyeOpenProbability ?? 1;

    return yaw <= 18 && roll <= 18 && leftEye > 0.4 && rightEye > 0.4;
  }

  void dispose() {
    _detector.close();
  }
}
