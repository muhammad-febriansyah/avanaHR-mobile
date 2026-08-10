import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

/// Thin wrapper around ML Kit face detection. Classification (smiling / eyes
/// open) and head-angle data are enabled so enrollment can gate on face quality
/// and run a lightweight active-liveness challenge (neutral → smile).
class FaceDetectorService {
  /// Primary detector. ML Kit documents `accurate` as detecting more faces at
  /// higher attribute accuracy than `fast`, so it stays the one whose pose and
  /// eye/smile probabilities the gates are read from.
  final FaceDetector _accurate = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
      // ML Kit's own default is 0.1; this used to be 0.30, i.e. the head had to
      // span nearly a third of the capture's width before the detector would
      // report a face at all — and a frame under that bar comes back as an
      // empty list, indistinguishable from "no one is there". How close the
      // face must be is now enforced separately against the measured frame
      // (see [isCloseEnough]), which can say "dekatkan wajah" instead.
      minFaceSize: 0.15,
    ),
  );

  /// Second opinion, tried only when [_accurate] finds nothing. The two models
  /// are different networks, so a frame one of them misses the other sometimes
  /// still reads — and [lastDetector] records which one carried the scan.
  final FaceDetector _fast = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  /// Which model produced the last result: `accurate`, `fast`, or `none`.
  /// Logged so a device where one model works and the other doesn't is visible
  /// in the face scan log rather than only on the employee's screen.
  String lastDetector = 'none';

  /// The smallest share of the frame width a face may occupy and still be
  /// embedded. Below this the crop carries too little detail to match reliably.
  static const double minFaceWidthRatio = 0.20;

  /// Detect faces in the image at [path] (a captured photo file), falling back
  /// to the fast model when the accurate one comes back empty.
  Future<List<Face>> detectFile(String path) async {
    final input = InputImage.fromFilePath(path);

    final accurate = await _accurate.processImage(input);
    if (accurate.isNotEmpty) {
      lastDetector = 'accurate';

      return accurate;
    }

    final fast = await _fast.processImage(input);
    lastDetector = fast.isEmpty ? 'none' : 'fast';

    return fast;
  }

  /// Detector for live camera frames.
  ///
  /// `fast` here, deliberately: a preview frame arrives many times a second and
  /// only has to answer "is a usable face in shot right now". The authoritative
  /// reading — the one an embedding is taken from — still runs through
  /// [detectFile] on a full still, where accuracy is worth the milliseconds.
  final FaceDetector _live = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.15,
    ),
  );

  /// Device rotations the camera plugin reports, as degrees.
  static const Map<DeviceOrientation, int> _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Detect faces in a live preview frame.
  ///
  /// Returns null when the frame's pixel format is not one ML Kit accepts, so
  /// the caller can fall back rather than treat it as "no face".
  Future<List<Face>?> detectFrame(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    final input = _inputFrom(image, camera, deviceOrientation);
    if (input == null) {
      return null;
    }

    lastDetector = 'live';

    return _live.processImage(input);
  }

  /// Build an ML Kit input from a camera frame, or null when the platform
  /// handed over a format it cannot read.
  ///
  /// The two platforms deliver different things: iOS a single BGRA plane, and
  /// Android NV21 (which the camera has to be asked for — its default YUV_420
  /// arrives in three planes ML Kit will not take). Rotation is ours to work
  /// out as well, from the sensor's mounting angle against the device's current
  /// orientation, mirrored for the front camera.
  /// Why the last frame could not be turned into an ML Kit input, or null when
  /// the last one converted fine. Reported to the scan log so a device that
  /// silently drops to the shutter fallback says why, instead of only showing
  /// the white flash the fallback causes.
  String? lastFrameRejection;

  InputImage? _inputFrom(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final rotation = _rotationFor(camera, deviceOrientation);
    if (rotation == null) {
      lastFrameRejection = 'rotation_unknown:${camera.sensorOrientation}';

      return null;
    }

    final raw = image.format.raw;
    final format = raw is int ? InputImageFormatValue.fromRawValue(raw) : null;
    if (format == null || image.planes.isEmpty) {
      lastFrameRejection = 'format_unknown:$raw:planes=${image.planes.length}';

      return null;
    }

    final expected = Platform.isIOS
        ? InputImageFormat.bgra8888
        : InputImageFormat.nv21;
    if (format != expected) {
      lastFrameRejection = 'format_mismatch:${format.name}';

      return null;
    }

    lastFrameRejection = null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _rotationFor(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }

    final compensation = _orientationDegrees[deviceOrientation];
    if (compensation == null) {
      return null;
    }

    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + compensation) % 360
        : (camera.sensorOrientation - compensation + 360) % 360;

    return InputImageRotationValue.fromRawValue(degrees);
  }

  /// Whether [f] fills enough of a live frame of [width]×[height] to be worth
  /// pursuing.
  ///
  /// Measured against the frame's shorter side, which is the one the portrait
  /// preview is bounded by whichever way ML Kit reports the coordinates — the
  /// still-photo check ([isCloseEnough]) has the exact geometry and rules for
  /// real; this only keeps the loop from chasing a face across the room.
  bool isCloseEnoughInFrame(Face f, int width, int height) {
    final shortSide = math.min(width, height);
    if (shortSide <= 0) {
      return true;
    }

    return f.boundingBox.width / shortSide >= minFaceWidthRatio;
  }

  /// Whether [f] fills enough of the frame to be worth embedding. Unknown frame
  /// size (the capture failed to decode) never blocks — that case is reported
  /// on its own.
  bool isCloseEnough(Face f) {
    if (_frameW <= 0) {
      return true;
    }

    return f.boundingBox.width / _frameW >= minFaceWidthRatio;
  }

  /// Whether [f] is a usable capture: a full, roughly frontal face with both
  /// eyes open. Rejects profiles, tilted heads, closed eyes, and — crucially —
  /// far / partial captures (e.g. only the forehead in frame), which ML Kit
  /// reports with null pose/eye data that previously defaulted to "good".
  bool isFrontalOpenEyes(Face f) => rejectionOf(f) == null;

  /// Why [f] is not a usable capture, as a stable reason code, or null when it
  /// is. Splitting the pose check from the eye check makes the server-side log
  /// say which of the two actually failed, instead of one merged verdict.
  String? rejectionOf(Face f) {
    final yaw = f.headEulerAngleY;
    final roll = f.headEulerAngleZ;
    if (yaw == null || roll == null) {
      return 'pose_unknown';
    }
    if (yaw.abs() > 15 || roll.abs() > 15) {
      return 'head_turned';
    }

    final leftEye = f.leftEyeOpenProbability;
    final rightEye = f.rightEyeOpenProbability;
    if (leftEye == null || rightEye == null) {
      return 'eyes_unknown';
    }
    if (leftEye < 0.5 || rightEye < 0.5) {
      return 'eyes_closed';
    }

    if (f.landmarks[FaceLandmarkType.leftEye] == null ||
        f.landmarks[FaceLandmarkType.rightEye] == null ||
        f.landmarks[FaceLandmarkType.noseBase] == null) {
      return 'landmarks_missing';
    }

    return null;
  }

  /// The sentence to show for a rejection code from [rejectionOf]. Each cause
  /// gets its own wording: a face that is turned away and one whose eyes are
  /// shut need different things from the employee, and a single catch-all hint
  /// leaves them guessing which.
  String hintForRejection(String reason) {
    switch (reason) {
      case 'head_turned':
        return 'Hadapkan wajah lurus ke kamera';
      case 'eyes_closed':
        return 'Buka mata Anda, jangan berkedip saat memindai';
      case 'eyes_unknown':
      case 'pose_unknown':
      case 'landmarks_missing':
        return 'Wajah kurang jelas — pastikan seluruh wajah terlihat '
            'dan cahaya cukup terang';
      default:
        return 'Hadapkan wajah lurus ke kamera, buka mata';
    }
  }

  /// Everything the detector measured about [f], for the server-side scan log.
  Map<String, dynamic> metricsOf(Face f) => {
    'detector': lastDetector,
    'yaw': f.headEulerAngleY,
    'roll': f.headEulerAngleZ,
    'pitch': f.headEulerAngleX,
    'left_eye_open': f.leftEyeOpenProbability,
    'right_eye_open': f.rightEyeOpenProbability,
    'smiling': f.smilingProbability,
    if (_frameW > 0) 'frame_width': _frameW.round(),
    if (_frameH > 0) 'frame_height': _frameH.round(),
    if (_frameW > 0) 'face_width_ratio': f.boundingBox.width / _frameW,
    if (_frameW > 0) 'center_x': f.boundingBox.center.dx / _frameW,
    if (_frameH > 0) 'center_y': f.boundingBox.center.dy / _frameH,
  };

  double _frameW = 0;
  double _frameH = 0;

  /// Forgets the cached frame size so the next [isCentered] call re-measures
  /// it. Call this whenever enrollment restarts (e.g. after a failed submit),
  /// so a bad first reading from an earlier attempt can't poison the rest of
  /// a new session.
  void resetFrame() {
    _frameW = 0;
    _frameH = 0;
  }

  /// Whether [f] sits roughly in the middle of the frame — rejects captures
  /// where the phone is pointed away and the face drifts to an edge/corner, the
  /// way a normal face-recognition prompt requires the face centered. Learns the
  /// frame size once from [path] (all captures share the camera resolution).
  Future<bool> isCentered(Face f, String path) async {
    await measureFrame(path);
    if (_frameW <= 0 || _frameH <= 0) {
      return true; // unknown frame size → don't block
    }

    final cx = f.boundingBox.center.dx / _frameW;
    final cy = f.boundingBox.center.dy / _frameH;

    return cx > 0.28 && cx < 0.72 && cy > 0.22 && cy < 0.78;
  }

  /// Learn the capture's frame size once, so centering and the diagnostics in
  /// [metricsOf] have something to measure against — including on a frame where
  /// no face was found at all, which is exactly the case worth logging.
  Future<void> measureFrame(String path) async {
    if (_frameW > 0 && _frameH > 0) {
      return;
    }

    final size = await _bakedSize(path);
    if (size == null) {
      // A capture the image decoder can't read is a finding in itself: it means
      // the camera wrote something other than the JPEG the pipeline expects.
      frameDecodeFailed = true;

      return;
    }
    frameDecodeFailed = false;
    _frameW = size.$1;
    _frameH = size.$2;
  }

  /// Whether the last attempt to measure a capture failed to decode it.
  bool frameDecodeFailed = false;

  /// The measured frame size, or null when it hasn't been read yet.
  (int, int)? get frameSize =>
      _frameW > 0 && _frameH > 0 ? (_frameW.round(), _frameH.round()) : null;

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
    _fast.close();
    _accurate.close();
    _live.close();
  }
}
