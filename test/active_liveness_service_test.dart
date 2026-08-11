import 'package:avanahr/app/data/services/active_liveness_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 8, 11, 9);

  LivenessObservation observation({
    double yaw = 0,
    double roll = 0,
    double leftEye = 0.9,
    double rightEye = 0.9,
  }) => LivenessObservation(
    yaw: yaw,
    roll: roll,
    leftEyeOpen: leftEye,
    rightEyeOpen: rightEye,
  );

  group('ActiveLivenessGate blink', () {
    test('requires neutral, closed eyes, then a stable open-eyed face', () {
      final gate = ActiveLivenessGate(challenge: ActiveLivenessChallenge.blink);

      gate.observe(observation(), at: start);
      final prompted = gate.observe(
        observation(),
        at: start.add(const Duration(milliseconds: 200)),
      );
      expect(prompted.stage, ActiveLivenessStage.performChallenge);

      final blink = gate.observe(
        observation(leftEye: 0.1, rightEye: 0.12),
        at: start.add(const Duration(milliseconds: 400)),
      );
      expect(blink.stage, ActiveLivenessStage.returnToCenter);

      gate.observe(
        observation(),
        at: start.add(const Duration(milliseconds: 600)),
      );
      final result = gate.observe(
        observation(),
        at: start.add(const Duration(milliseconds: 800)),
      );

      expect(result.passed, isTrue);
      expect(gate.evidence['challenge'], 'blink');
      expect(gate.evidence['duration_ms'], 800);
      expect(gate.evidence['minimum_eye_open'], closeTo(0.1, 0.001));
    });

    test('does not accept closed eyes before a neutral baseline', () {
      final gate = ActiveLivenessGate(challenge: ActiveLivenessChallenge.blink);

      gate.observe(observation(leftEye: 0.1, rightEye: 0.1), at: start);
      gate.observe(
        observation(leftEye: 0.1, rightEye: 0.1),
        at: start.add(const Duration(milliseconds: 200)),
      );
      gate.observe(
        observation(),
        at: start.add(const Duration(milliseconds: 400)),
      );
      final result = gate.observe(
        observation(),
        at: start.add(const Duration(milliseconds: 600)),
      );

      expect(result.stage, ActiveLivenessStage.performChallenge);
      expect(result.passed, isFalse);
    });
  });

  group('ActiveLivenessGate head movement', () {
    test('requires a turn and a return to center', () {
      final gate = ActiveLivenessGate(
        challenge: ActiveLivenessChallenge.turnHead,
      );

      gate.observe(observation(), at: start);
      gate.observe(
        observation(),
        at: start.add(const Duration(milliseconds: 200)),
      );
      final turn = gate.observe(
        observation(yaw: -24),
        at: start.add(const Duration(milliseconds: 400)),
      );
      expect(turn.stage, ActiveLivenessStage.returnToCenter);

      gate.observe(
        observation(),
        at: start.add(const Duration(milliseconds: 600)),
      );
      final result = gate.observe(
        observation(),
        at: start.add(const Duration(milliseconds: 800)),
      );

      expect(result.passed, isTrue);
      expect(gate.evidence['challenge'], 'turn_head');
      expect(gate.evidence['peak_abs_yaw'], 24);
    });

    test('does not treat a tilted head as a valid turn', () {
      final gate = ActiveLivenessGate(
        challenge: ActiveLivenessChallenge.turnHead,
      );

      gate.observe(observation(), at: start);
      gate.observe(
        observation(),
        at: start.add(const Duration(milliseconds: 200)),
      );
      final result = gate.observe(
        observation(yaw: 25, roll: 24),
        at: start.add(const Duration(milliseconds: 400)),
      );

      expect(result.stage, ActiveLivenessStage.performChallenge);
      expect(result.passed, isFalse);
    });
  });

  test('three invalid frames reset an unfinished challenge', () {
    final gate = ActiveLivenessGate(challenge: ActiveLivenessChallenge.blink);

    gate.observe(observation(), at: start);
    gate.observe(
      observation(),
      at: start.add(const Duration(milliseconds: 200)),
    );
    expect(gate.stage, ActiveLivenessStage.performChallenge);

    expect(gate.registerInvalidFrame(), isFalse);
    expect(gate.registerInvalidFrame(), isFalse);
    expect(gate.registerInvalidFrame(), isTrue);
    expect(gate.stage, ActiveLivenessStage.centerFace);
  });

  test('an expired challenge restarts instead of passing stale movement', () {
    final gate = ActiveLivenessGate(
      challenge: ActiveLivenessChallenge.blink,
      timeout: const Duration(seconds: 3),
    );

    gate.observe(observation(), at: start);
    gate.observe(
      observation(),
      at: start.add(const Duration(milliseconds: 200)),
    );
    final result = gate.observe(
      observation(leftEye: 0.1, rightEye: 0.1),
      at: start.add(const Duration(seconds: 4)),
    );

    expect(result.timedOut, isTrue);
    expect(result.stage, ActiveLivenessStage.centerFace);
    expect(result.passed, isFalse);
  });
}
