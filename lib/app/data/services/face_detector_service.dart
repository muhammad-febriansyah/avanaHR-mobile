import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

/// Thin wrapper around ML Kit face detection. Classification (smiling / eyes
/// open) and head-angle data are enabled so enrollment can gate on face quality
/// and verification can run active blink/head-movement liveness.
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
      // (see [positionRejectionForBox]), which can give a useful distance hint.
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
  /// The preview itself is now authoritative: its accepted frame is embedded
  /// and saved without switching to still capture. Accurate mode is therefore
  /// required for dependable pose and classification values.
  final FaceDetector _live = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      // Euler Y is only guaranteed by ML Kit in accurate mode. The active
      // head-movement challenge must not depend on an optional fast-mode value.
      performanceMode: FaceDetectorMode.accurate,
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
    if (format == null || image.planes.length != 1) {
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

    if (image.width <= 0 || image.height <= 0) {
      lastFrameRejection = 'invalid_dimensions:${image.width}x${image.height}';
      return null;
    }

    final plane = image.planes.first;
    final minimumBytesPerRow = Platform.isIOS ? image.width * 4 : image.width;
    final minimumBytes = Platform.isIOS
        ? plane.bytesPerRow * image.height
        : plane.bytesPerRow * image.height * 3 ~/ 2;
    if (plane.bytesPerRow < minimumBytesPerRow ||
        plane.bytes.length < minimumBytes) {
      lastFrameRejection =
          'truncated_frame:${plane.bytes.length}:expected=$minimumBytes';
      return null;
    }

    lastFrameRejection = null;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
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

  /// Rejects a live face that is too small, too close, cropped, or outside the
  /// central capture area. Android bounding boxes use the image after ML Kit's
  /// metadata rotation, so 90/270 degree frames must swap their dimensions.
  String? positionRejectionInFrame(
    Face face,
    int width,
    int height, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    var frameWidth = width.toDouble();
    var frameHeight = height.toDouble();
    final rotation = _rotationFor(camera, deviceOrientation);
    if (Platform.isAndroid &&
        (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg)) {
      final originalWidth = frameWidth;
      frameWidth = frameHeight;
      frameHeight = originalWidth;
    }

    return positionRejectionForBox(face.boundingBox, frameWidth, frameHeight);
  }

  /// Pure geometry gate, exposed so edge/crop behavior can be unit tested
  /// without opening a native ML Kit detector.
  static String? positionRejectionForBox(
    Rect box,
    double frameWidth,
    double frameHeight,
  ) {
    if (!frameWidth.isFinite ||
        !frameHeight.isFinite ||
        frameWidth <= 0 ||
        frameHeight <= 0 ||
        !box.left.isFinite ||
        !box.top.isFinite ||
        !box.right.isFinite ||
        !box.bottom.isFinite ||
        box.width <= 0 ||
        box.height <= 0) {
      return 'frame_invalid';
    }

    final tolerance = math.min(frameWidth, frameHeight) * 0.02;
    if (box.left < -tolerance ||
        box.top < -tolerance ||
        box.right > frameWidth + tolerance ||
        box.bottom > frameHeight + tolerance) {
      return 'face_cropped';
    }

    final widthRatio = box.width / frameWidth;
    final heightRatio = box.height / frameHeight;
    if (widthRatio < minFaceWidthRatio) return 'too_far';
    if (widthRatio > 0.72 || heightRatio > 0.82) return 'too_close';

    final centerX = box.center.dx / frameWidth;
    final centerY = box.center.dy / frameHeight;
    if (centerX < 0.24 || centerX > 0.76 || centerY < 0.20 || centerY > 0.80) {
      return 'not_centered';
    }

    return null;
  }

  String hintForPositionRejection(String reason) {
    switch (reason) {
      case 'too_far':
        return 'Wajah terlalu jauh — dekatkan ke kamera';
      case 'too_close':
        return 'Wajah terlalu dekat — mundur sedikit';
      case 'face_cropped':
        return 'Pastikan seluruh wajah terlihat di dalam bingkai';
      case 'not_centered':
        return 'Posisikan wajah di tengah bingkai';
      default:
        return 'Wajah belum terbaca dengan baik — sesuaikan posisi kamera';
    }
  }

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
    // ML Kit classification probabilities vary across platform camera
    // pipelines. A slightly lower iOS threshold avoids rejecting naturally
    // half-open eyes while still rejecting a clearly closed eye.
    final eyeThreshold = Platform.isIOS ? 0.35 : 0.5;
    if (leftEye < eyeThreshold || rightEye < eyeThreshold) {
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

  /// Forgets the cached still-frame size. Call this whenever enrollment
  /// restarts so a bad first reading cannot poison the next attempt.
  void resetFrame() {
    _frameW = 0;
    _frameH = 0;
  }

  Future<String?> positionRejectionInFile(Face face, String path) async {
    await measureFrame(path);
    if (_frameW <= 0 || _frameH <= 0) return 'frame_invalid';

    return positionRejectionForBox(face.boundingBox, _frameW, _frameH);
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

  Future<void> dispose() async {
    await Future.wait([
      _fast.close().catchError((_) {}),
      _accurate.close().catchError((_) {}),
      _live.close().catchError((_) {}),
    ]);
  }
}
