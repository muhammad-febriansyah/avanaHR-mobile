import 'dart:io';
import 'dart:ui' show Rect;

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
  /// when the model is unavailable.
  Future<List<double>?> embed(img.Image full, Rect box) async {
    try {
      await _ensureLoaded();
    } catch (e, st) {
      debugPrint('[FaceEmbedder] model load failed ($_modelAsset): $e\n$st');
      return null;
    }

    try {
      final crop = _cropFace(full, box);
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
  Future<List<double>?> embedFromFile(String path, Rect box) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      debugPrint(
        '[FaceEmbedder] decodeImage null for $path (${bytes.length}B)',
      );
      return null;
    }

    return embed(img.bakeOrientation(decoded), box);
  }

  img.Image _cropFace(img.Image full, Rect box) {
    final x = box.left.round().clamp(0, full.width - 1).toInt();
    final y = box.top.round().clamp(0, full.height - 1).toInt();
    final w = box.width.round().clamp(1, full.width - x).toInt();
    final h = box.height.round().clamp(1, full.height - y).toInt();

    return img.copyCrop(full, x: x, y: y, width: w, height: h);
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
