import 'dart:math';

import 'package:avanahr/app/core/utils/vector_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VectorMath.l2normalize', () {
    test('scales a vector to unit length', () {
      final out = VectorMath.l2normalize([3, 4]);
      expect(_norm(out), closeTo(1.0, 1e-9));
      expect(out[0], closeTo(0.6, 1e-9));
      expect(out[1], closeTo(0.8, 1e-9));
    });

    test('leaves a zero vector unchanged', () {
      expect(VectorMath.l2normalize([0, 0, 0]), [0, 0, 0]);
    });
  });

  group('VectorMath.averageNormalized', () {
    test('averages then normalizes to unit length', () {
      final out = VectorMath.averageNormalized([
        [1, 0, 0],
        [0, 1, 0],
      ]);
      expect(_norm(out), closeTo(1.0, 1e-9));
      // Mean is (0.5, 0.5, 0) → normalized both components equal.
      expect(out[0], closeTo(out[1], 1e-9));
      expect(out[2], closeTo(0.0, 1e-9));
    });
  });

  group('VectorMath.cosine', () {
    test('identical vectors score 1', () {
      expect(VectorMath.cosine([1, 2, 3], [1, 2, 3]), closeTo(1.0, 1e-9));
    });

    test('orthogonal vectors score 0', () {
      expect(VectorMath.cosine([1, 0], [0, 1]), closeTo(0.0, 1e-9));
    });

    test('mismatched lengths return -1', () {
      expect(VectorMath.cosine([1, 2], [1]), -1);
    });

    test('empty input returns -1', () {
      expect(VectorMath.cosine([], []), -1);
    });

    test('crosses the 0.6 enrollment threshold for a near-identical face', () {
      // A tiny perturbation still matches; an opposite vector does not.
      final base = List<double>.generate(192, (i) => sin(i.toDouble()));
      final jittered = [for (var i = 0; i < base.length; i++) base[i] + 0.01];
      final opposite = [for (final x in base) -x];

      expect(VectorMath.cosine(base, jittered), greaterThan(0.6));
      expect(VectorMath.cosine(base, opposite), lessThan(0.6));
    });
  });
}

double _norm(List<double> v) {
  var sum = 0.0;
  for (final x in v) {
    sum += x * x;
  }

  return sqrt(sum);
}
