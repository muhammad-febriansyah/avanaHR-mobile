import 'dart:io';

import 'package:avanahr/app/data/services/face_embedder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MobileFaceNet asset is a bundled TFLite FlatBuffer', () {
    final model = File('assets/models/mobilefacenet.tflite').readAsBytesSync();

    expect(model.length, greaterThan(1024 * 1024));
    expect(String.fromCharCodes(model.sublist(4, 8)), 'TFL3');
    expect(FaceEmbedderService.inputSize, 112);
    expect(FaceEmbedderService.embeddingSize, 192);
  });
}
