import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/utils/vector_math.dart';
import 'camera_frame_decoder.dart';

class FaceFrameCapture {
  const FaceFrameCapture({required this.embedding, this.photoPath});

  final List<double> embedding;
  final String? photoPath;
}

/// Turns a detected face into a MobileFaceNet embedding on-device. The 192-d
/// vector (not the photo) is what leaves the phone, matching happens server-side
/// against the enrolled embedding. Fails soft: [embed] returns null when the
/// model can't be loaded, so the rest of the app keeps working.
class FaceEmbedderService extends GetxService {
  static const String _modelAsset = 'assets/models/mobilefacenet.tflite';
  static const int inputSize = 112;
  static const int embeddingSize = 192;

  Interpreter? _interpreter;

  /// Whether the TFLite model loads on this device.
  Future<bool> get isAvailable async {
    try {
      await _ensureLoaded();

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureLoaded() async {
    if (_interpreter != null) return;

    final interpreter = await Interpreter.fromAsset(_modelAsset);
    try {
      final inputs = interpreter.getInputTensors();
      final outputs = interpreter.getOutputTensors();
      final validContract =
          inputs.length == 1 &&
          listEquals(inputs.single.shape, const [1, inputSize, inputSize, 3]) &&
          inputs.single.type == TensorType.float32 &&
          outputs.length == 1 &&
          listEquals(outputs.single.shape, const [1, embeddingSize]) &&
          outputs.single.type == TensorType.float32;
      if (!validContract) {
        throw StateError(
          'Unexpected MobileFaceNet tensor contract: '
          'inputs=${inputs.map((tensor) => tensor.shape).toList()} '
          'outputs=${outputs.map((tensor) => tensor.shape).toList()}',
        );
      }
      _interpreter = interpreter;
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  /// L2-normalized 192-d embedding for the face at [box] within [full], or null
  /// when the model is unavailable. When [leftEye]/[rightEye] are given, the
  /// crop is eye-aligned (rolled level + margined) so the same face maps to a
  /// consistent input — MobileFaceNet is alignment-sensitive, and the raw
  /// detector box (tight, tilted) makes genuine and impostor scores overlap.
  Future<List<double>?> embed(
    img.Image full,
    Rect box, {
    Offset? leftEye,
    Offset? rightEye,
  }) async {
    try {
      await _ensureLoaded();
    } catch (e, st) {
      debugPrint('[FaceEmbedder] model load failed ($_modelAsset): $e\n$st');
      return null;
    }

    try {
      final crop = (leftEye != null && rightEye != null)
          ? _alignedCrop(full, box, leftEye, rightEye)
          : _cropFace(full, box);
      final resized = img.copyResize(crop, width: inputSize, height: inputSize);
      final input = _toInput(resized);
      final output = [List<double>.filled(embeddingSize, 0.0)];

      _interpreter!.run(input, output);

      return VectorMath.l2normalize(output[0]);
    } catch (e, st) {
      debugPrint('[FaceEmbedder] embed run failed (box=$box): $e\n$st');
      return null;
    }
  }

  /// Decode the photo at [path], normalize EXIF orientation, and embed the face
  /// at [box]. Returns null when the image can't be decoded or the model is
  /// unavailable.
  Future<List<double>?> embedFromFile(
    String path,
    Rect box, {
    Offset? leftEye,
    Offset? rightEye,
  }) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      debugPrint(
        '[FaceEmbedder] decodeImage null for $path (${bytes.length}B)',
      );
      return null;
    }

    return embed(
      img.bakeOrientation(decoded),
      box,
      leftEye: leftEye,
      rightEye: rightEye,
    );
  }

  /// Embed a face from a live camera stream frame. No stop/restart or shutter is
  /// needed, so iOS does not have to switch its AVFoundation capture output.
  ///
  /// [camera] and [deviceOrientation] are needed so the raw sensor frame can be
  /// rotated into the same coordinate space ML Kit's bounding box is measured in.
  Future<List<double>?> embedFromCameraImage(
    CameraImage image,
    Rect box, {
    Offset? leftEye,
    Offset? rightEye,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    final capture = await captureFromCameraImage(
      image,
      box,
      leftEye: leftEye,
      rightEye: rightEye,
      camera: camera,
      deviceOrientation: deviceOrientation,
    );

    return capture?.embedding;
  }

  /// Persists a live camera frame without loading or running MobileFaceNet.
  ///
  /// Server-side recognition uses this JPEG as its input. Keeping the frame
  /// conversion here also preserves the iOS stream-only capture path, so the
  /// camera session never switches to `takePicture()` and flashes white.
  Future<String?> saveCameraFrame(
    CameraImage image, {
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    try {
      final frame = _cameraImageToImg(image, camera, deviceOrientation);

      return _saveFrame(frame);
    } catch (e, st) {
      debugPrint('[FaceEmbedder] saveCameraFrame failed: $e\n$st');
      return null;
    }
  }

  /// Embeds a live frame and optionally persists that exact frame as the
  /// attendance selfie. Both results share one raw-frame conversion, avoiding
  /// a second `takePicture()` capture and its iOS preview flash/freeze.
  Future<FaceFrameCapture?> captureFromCameraImage(
    CameraImage image,
    Rect box, {
    Offset? leftEye,
    Offset? rightEye,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
    bool savePhoto = false,
  }) async {
    try {
      await _ensureLoaded();
    } catch (e, st) {
      debugPrint('[FaceEmbedder] model load failed ($_modelAsset): $e\n$st');
      return null;
    }

    try {
      final full = _cameraImageToImg(image, camera, deviceOrientation);
      final crop = (leftEye != null && rightEye != null)
          ? _alignedCrop(full, box, leftEye, rightEye)
          : _cropFace(full, box);
      final resized = img.copyResize(crop, width: inputSize, height: inputSize);
      final input = _toInput(resized);
      final output = [List<double>.filled(embeddingSize, 0.0)];

      _interpreter!.run(input, output);

      final embedding = VectorMath.l2normalize(output[0]);
      final photoPath = savePhoto ? await _saveFrame(full) : null;
      if (savePhoto && photoPath == null) {
        return null;
      }

      return FaceFrameCapture(embedding: embedding, photoPath: photoPath);
    } catch (e, st) {
      debugPrint(
        '[FaceEmbedder] captureFromCameraImage failed (box=$box): $e\n$st',
      );
      return null;
    }
  }

  img.Image _cameraImageToImg(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final raw = Platform.isIOS ? _bgraToImage(image) : _nv21ToImage(image);

    // camera_avfoundation applies the requested orientation to its video
    // output connection before delivering BGRA frames. ML Kit also ignores the
    // rotation metadata on iOS, so its face box is already in this raw frame's
    // coordinate space. Rotating it again makes the crop miss the face.
    if (Platform.isIOS) return raw;

    final degrees = _rotationDegrees(camera, deviceOrientation);
    if (degrees == 0) return raw;

    return img.copyRotate(raw, angle: -degrees);
  }

  /// Degrees ML Kit rotated the frame internally. The raw camera image must be
  /// rotated by the same amount so the bounding box coordinates line up.
  static const _orientationDegrees = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  int _rotationDegrees(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final compensation = _orientationDegrees[deviceOrientation] ?? 0;

    return camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + compensation) % 360
        : (camera.sensorOrientation - compensation + 360) % 360;
  }

  img.Image _bgraToImage(CameraImage image) {
    final plane = image.planes.first;
    return CameraFrameDecoder.bgra8888(
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      bytes: plane.bytes,
    );
  }

  img.Image _nv21ToImage(CameraImage image) {
    final plane = image.planes.first;
    return CameraFrameDecoder.nv21(
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      bytes: plane.bytes,
    );
  }

  Future<String?> _saveFrame(img.Image frame) async {
    try {
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/face_${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File(
        path,
      ).writeAsBytes(img.encodeJpg(frame, quality: 88), flush: true);

      return path;
    } catch (e, st) {
      debugPrint('[FaceEmbedder] saving attendance frame failed: $e\n$st');
      return null;
    }
  }

  img.Image _cropFace(img.Image full, Rect box) {
    final x = box.left.round().clamp(0, full.width - 1).toInt();
    final y = box.top.round().clamp(0, full.height - 1).toInt();
    final w = box.width.round().clamp(1, full.width - x).toInt();
    final h = box.height.round().clamp(1, full.height - y).toInt();

    return img.copyCrop(full, x: x, y: y, width: w, height: h);
  }

  /// Eye-aligned face crop: expands the tight detector box with margin, then
  /// rotates so the eye line is horizontal — the same normalization MobileFaceNet
  /// expects. Falls back to the plain box crop if the geometry looks degenerate.
  img.Image _alignedCrop(
    img.Image full,
    Rect box,
    Offset leftEye,
    Offset rightEye,
  ) {
    final mx = box.width * 0.35;
    final my = box.height * 0.35;
    final x = (box.left - mx).round().clamp(0, full.width - 1).toInt();
    final y = (box.top - my).round().clamp(0, full.height - 1).toInt();
    final w = (box.width + 2 * mx).round().clamp(1, full.width - x).toInt();
    final h = (box.height + 2 * my).round().clamp(1, full.height - y).toInt();
    final sub = img.copyCrop(full, x: x, y: y, width: w, height: h);

    final angleDeg =
        math.atan2(rightEye.dy - leftEye.dy, rightEye.dx - leftEye.dx) *
        180 /
        math.pi;

    // Skip the rotation for near-level or implausible eye lines.
    if (angleDeg.abs() <= 1.0 || angleDeg.abs() >= 45) {
      return sub;
    }

    final rotated = img.copyRotate(sub, angle: -angleDeg);

    // Trim the rotation border by center-cropping back to the pre-rotate size.
    final cx = ((rotated.width - w) / 2).round().clamp(0, rotated.width - 1);
    final cy = ((rotated.height - h) / 2).round().clamp(0, rotated.height - 1);

    return img.copyCrop(
      rotated,
      x: cx,
      y: cy,
      width: w.clamp(1, rotated.width - cx),
      height: h.clamp(1, rotated.height - cy),
    );
  }

  /// Shape [1, 112, 112, 3], pixels normalized to [-1, 1] as (v - 128) / 128.
  List<List<List<List<double>>>> _toInput(img.Image im) {
    return [
      List.generate(inputSize, (y) {
        return List.generate(inputSize, (x) {
          final p = im.getPixel(x, y);

          return [
            (p.r - 128) / 128.0,
            (p.g - 128) / 128.0,
            (p.b - 128) / 128.0,
          ];
        });
      }),
    ];
  }

  @override
  void onClose() {
    _interpreter?.close();
    _interpreter = null;
    super.onClose();
  }
}
