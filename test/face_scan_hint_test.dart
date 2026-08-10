import 'package:avanahr/app/data/services/face_detector_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scanner used to answer every rejection with one sentence, so "you are
/// turned away", "your eyes are shut" and "the camera cannot make out your
/// face" all read the same and left the employee guessing which. Each cause now
/// carries its own instruction, and the wording is what the server-side scan log
/// records alongside the numbers.
void main() {
  group('FaceDetectorService.hintForRejection', () {
    // Not disposed: closing a detector reaches for a platform channel that no
    // unit test has. Constructing one only builds the options object.
    final detector = FaceDetectorService();

    test('names the specific thing to correct', () {
      expect(detector.hintForRejection('head_turned'), contains('lurus'));
      expect(detector.hintForRejection('eyes_closed'), contains('mata'));
    });

    test('asks for light when the face itself could not be read', () {
      for (final reason in [
        'pose_unknown',
        'eyes_unknown',
        'landmarks_missing',
      ]) {
        expect(
          detector.hintForRejection(reason),
          contains('cahaya'),
          reason: 'reason "$reason" should point at readability, not posture',
        );
      }
    });

    test('still says something actionable for an unknown code', () {
      expect(detector.hintForRejection('something_new'), isNotEmpty);
    });
  });
}
