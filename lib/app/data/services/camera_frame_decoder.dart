import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Converts the exact camera stream layouts accepted by ML Kit into RGB.
class CameraFrameDecoder {
  const CameraFrameDecoder._();

  /// Rotate RGB pixels in the same direction as the metadata supplied to ML
  /// Kit. CameraX keeps NV21 pixels in sensor orientation, while ML Kit reports
  /// face boxes in the rotated coordinate space.
  static img.Image rotateToInputOrientation(
    img.Image image,
    int rotationDegrees,
  ) {
    final normalized = rotationDegrees % 360;
    if (normalized == 0) return image;

    return img.copyRotate(image, angle: normalized);
  }

  static img.Image bgra8888({
    required int width,
    required int height,
    required int bytesPerRow,
    required Uint8List bytes,
  }) {
    if (width <= 0 || height <= 0 || bytesPerRow < width * 4) {
      throw const FormatException('Invalid BGRA frame geometry');
    }
    if (bytes.length < bytesPerRow * height) {
      throw const FormatException('Truncated BGRA frame');
    }

    final result = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = y * bytesPerRow + x * 4;
        result.setPixelRgba(
          x,
          y,
          bytes[offset + 2],
          bytes[offset + 1],
          bytes[offset],
          255,
        );
      }
    }

    return result;
  }

  /// Decodes CameraX's single-plane NV21 buffer: full-resolution Y followed by
  /// half-resolution, interleaved VU chroma. CameraX reports `bytesPerRow` as
  /// the width for this packed representation.
  static img.Image nv21({
    required int width,
    required int height,
    required int bytesPerRow,
    required Uint8List bytes,
  }) {
    if (width <= 0 || height <= 0 || width.isOdd || height.isOdd) {
      throw const FormatException('Invalid NV21 dimensions');
    }
    if (bytesPerRow < width) {
      throw const FormatException('Invalid NV21 row stride');
    }

    final yPlaneLength = bytesPerRow * height;
    final requiredLength = yPlaneLength + bytesPerRow * (height ~/ 2);
    if (bytes.length < requiredLength) {
      throw const FormatException('Truncated NV21 frame');
    }

    final result = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yValue = bytes[y * bytesPerRow + x] & 0xFF;
        final vuOffset = yPlaneLength + (y ~/ 2) * bytesPerRow + (x ~/ 2) * 2;
        final v = (bytes[vuOffset] & 0xFF) - 128;
        final u = (bytes[vuOffset + 1] & 0xFF) - 128;

        final red = (yValue + 1.402 * v).round().clamp(0, 255);
        final green = (yValue - 0.344 * u - 0.714 * v).round().clamp(0, 255);
        final blue = (yValue + 1.772 * u).round().clamp(0, 255);
        result.setPixelRgba(x, y, red, green, blue, 255);
      }
    }

    return result;
  }
}
