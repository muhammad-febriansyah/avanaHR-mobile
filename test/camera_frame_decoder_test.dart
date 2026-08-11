import 'dart:typed_data';

import 'package:avanahr/app/data/services/camera_frame_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes BGRA pixels while respecting row padding', () {
    final image = CameraFrameDecoder.bgra8888(
      width: 2,
      height: 1,
      bytesPerRow: 12,
      bytes: Uint8List.fromList([10, 20, 30, 255, 40, 50, 60, 255, 0, 0, 0, 0]),
    );

    final first = image.getPixel(0, 0);
    final second = image.getPixel(1, 0);
    expect((first.r, first.g, first.b), (30, 20, 10));
    expect((second.r, second.g, second.b), (60, 50, 40));
  });

  test('decodes CameraX single-plane NV21 with VU chroma order', () {
    final image = CameraFrameDecoder.nv21(
      width: 2,
      height: 2,
      bytesPerRow: 2,
      bytes: Uint8List.fromList([100, 100, 100, 100, 255, 128]),
    );

    final pixel = image.getPixel(0, 0);
    expect(pixel.r, 255);
    expect(pixel.b, 100);
    expect(pixel.g, lessThan(pixel.b));
  });

  test('rejects a truncated NV21 plane before reading outside the buffer', () {
    expect(
      () => CameraFrameDecoder.nv21(
        width: 2,
        height: 2,
        bytesPerRow: 2,
        bytes: Uint8List.fromList([100, 100, 100, 100]),
      ),
      throwsFormatException,
    );
  });
}
