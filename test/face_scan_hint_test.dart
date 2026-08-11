import 'package:avanahr/app/data/services/face_detector_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

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

  group('FaceDetectorService.positionRejectionForBox', () {
    const frameWidth = 480.0;
    const frameHeight = 640.0;

    test('accepts a complete, centered face at a usable distance', () {
      expect(
        FaceDetectorService.positionRejectionForBox(
          const Rect.fromLTRB(120, 150, 360, 500),
          frameWidth,
          frameHeight,
        ),
        isNull,
      );
    });

    test('rejects faces that are too far or too close', () {
      expect(
        FaceDetectorService.positionRejectionForBox(
          const Rect.fromLTRB(200, 250, 280, 370),
          frameWidth,
          frameHeight,
        ),
        'too_far',
      );
      expect(
        FaceDetectorService.positionRejectionForBox(
          const Rect.fromLTRB(40, 50, 440, 610),
          frameWidth,
          frameHeight,
        ),
        'too_close',
      );
    });

    test('rejects cropped and off-center faces', () {
      expect(
        FaceDetectorService.positionRejectionForBox(
          const Rect.fromLTRB(-30, 150, 230, 500),
          frameWidth,
          frameHeight,
        ),
        'face_cropped',
      );
      expect(
        FaceDetectorService.positionRejectionForBox(
          const Rect.fromLTRB(0, 180, 120, 440),
          frameWidth,
          frameHeight,
        ),
        'not_centered',
      );
    });

    test('rejects invalid frame geometry', () {
      expect(
        FaceDetectorService.positionRejectionForBox(
          Rect.zero,
          frameWidth,
          frameHeight,
        ),
        'frame_invalid',
      );
    });
  });
}
