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

  void dispose() {
    _detector.close();
  }
}
