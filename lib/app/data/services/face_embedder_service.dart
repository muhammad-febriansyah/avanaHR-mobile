import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../core/utils/vector_math.dart';

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
    _interpreter ??= await Interpreter.fromAsset(_modelAsset);
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
