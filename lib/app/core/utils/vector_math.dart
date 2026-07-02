import 'dart:math';

/// Pure vector helpers for face embeddings. No plugin imports so this is
/// unit-testable under `flutter test`.
class VectorMath {
  const VectorMath._();

  /// Scale [v] to unit L2 length. Returns [v] unchanged when its norm is 0.
  static List<double> l2normalize(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = sqrt(sum);
    if (norm == 0) {
      return v;
    }

    return [for (final x in v) x / norm];
  }

  /// Element-wise mean of equal-length [vectors], re-normalized to unit length.
  static List<double> averageNormalized(List<List<double>> vectors) {
    final n = vectors.first.length;
    final out = List<double>.filled(n, 0.0);
    for (final v in vectors) {
      for (var i = 0; i < n; i++) {
        out[i] += v[i];
      }
    }
    for (var i = 0; i < n; i++) {
      out[i] /= vectors.length;
    }

    return l2normalize(out);
  }

  /// Cosine similarity in [-1, 1]; returns -1 for empty or mismatched lengths.
  /// Mirrors the server-side matcher so client and API agree on the metric.
  static double cosine(List<double> a, List<double> b) {
    if (a.isEmpty || a.length != b.length) {
      return -1;
    }

    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA <= 0 || normB <= 0) {
      return -1;
    }

    return dot / (sqrt(normA) * sqrt(normB));
  }
}
