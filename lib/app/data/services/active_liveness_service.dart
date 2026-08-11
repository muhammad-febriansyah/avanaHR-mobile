enum ActiveLivenessChallenge { blink, turnHead }

enum ActiveLivenessStage {
  centerFace,
  performChallenge,
  returnToCenter,
  passed,
}

class LivenessObservation {
  const LivenessObservation({
    required this.yaw,
    required this.roll,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
  });

  final double yaw;
  final double roll;
  final double leftEyeOpen;
  final double rightEyeOpen;
}

class ActiveLivenessUpdate {
  const ActiveLivenessUpdate({
    required this.stage,
    required this.hint,
    required this.passed,
    this.timedOut = false,
  });

  final ActiveLivenessStage stage;
  final String hint;
  final bool passed;
  final bool timedOut;
}

/// A small active-liveness state machine for live ML Kit observations.
///
/// It deliberately requires a stable, open-eyed neutral face before accepting
/// a prompted movement, then requires the face to return to a capture-quality
/// pose. A closed eye or turned head therefore cannot itself become the frame
/// used for recognition.
class ActiveLivenessGate {
  ActiveLivenessGate({
    required this.challenge,
    this.openEyeThreshold = 0.5,
    this.closedEyeThreshold = 0.22,
    this.timeout = const Duration(seconds: 12),
  });

  ActiveLivenessChallenge challenge;
  final double openEyeThreshold;
  final double closedEyeThreshold;
  final Duration timeout;

  ActiveLivenessStage _stage = ActiveLivenessStage.centerFace;
  DateTime? _startedAt;
  DateTime? _completedAt;
  int _stableFrames = 0;
  int _invalidFrames = 0;
  double _peakAbsYaw = 0;
  double _minimumEyeOpen = 1;

  static const int _requiredStableFrames = 2;
  static const double _centerYaw = 12;
  static const double _turnYaw = 20;
  static const double _maximumRoll = 18;

  ActiveLivenessStage get stage => _stage;
  bool get passed => _stage == ActiveLivenessStage.passed;

  String get challengeCode => switch (challenge) {
    ActiveLivenessChallenge.blink => 'blink',
    ActiveLivenessChallenge.turnHead => 'turn_head',
  };

  String get currentHint => switch (_stage) {
    ActiveLivenessStage.centerFace =>
      'Hadapkan wajah lurus dan buka kedua mata',
    ActiveLivenessStage.performChallenge => switch (challenge) {
      ActiveLivenessChallenge.blink => 'Kedipkan kedua mata satu kali',
      ActiveLivenessChallenge.turnHead => 'Gerakkan kepala ke kiri atau kanan',
    },
    ActiveLivenessStage.returnToCenter =>
      'Kembali hadapkan wajah lurus ke kamera',
    ActiveLivenessStage.passed => 'Liveness berhasil - memverifikasi wajah...',
  };

  ActiveLivenessUpdate observe(
    LivenessObservation observation, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    _startedAt ??= now;

    if (!passed && now.difference(_startedAt!) > timeout) {
      reset();
      _startedAt = now;
      return ActiveLivenessUpdate(
        stage: _stage,
        hint: 'Waktu habis. Hadapkan wajah lurus untuk mencoba lagi.',
        passed: false,
        timedOut: true,
      );
    }

    _invalidFrames = 0;
    _peakAbsYaw = observation.yaw.abs() > _peakAbsYaw
        ? observation.yaw.abs()
        : _peakAbsYaw;
    final minimumEye = observation.leftEyeOpen < observation.rightEyeOpen
        ? observation.leftEyeOpen
        : observation.rightEyeOpen;
    if (minimumEye < _minimumEyeOpen) _minimumEyeOpen = minimumEye;

    final centered =
        observation.yaw.abs() <= _centerYaw &&
        observation.roll.abs() <= _maximumRoll;
    final eyesOpen =
        observation.leftEyeOpen >= openEyeThreshold &&
        observation.rightEyeOpen >= openEyeThreshold;

    switch (_stage) {
      case ActiveLivenessStage.centerFace:
        if (centered && eyesOpen) {
          _stableFrames++;
          if (_stableFrames >= _requiredStableFrames) {
            _stableFrames = 0;
            _stage = ActiveLivenessStage.performChallenge;
          }
        } else {
          _stableFrames = 0;
        }
        break;
      case ActiveLivenessStage.performChallenge:
        final challengeMet = switch (challenge) {
          ActiveLivenessChallenge.blink =>
            observation.leftEyeOpen <= closedEyeThreshold &&
                observation.rightEyeOpen <= closedEyeThreshold,
          ActiveLivenessChallenge.turnHead =>
            observation.yaw.abs() >= _turnYaw &&
                observation.roll.abs() <= _maximumRoll,
        };
        if (challengeMet) {
          _stableFrames = 0;
          _stage = ActiveLivenessStage.returnToCenter;
        }
        break;
      case ActiveLivenessStage.returnToCenter:
        if (centered && eyesOpen) {
          _stableFrames++;
          if (_stableFrames >= _requiredStableFrames) {
            _stage = ActiveLivenessStage.passed;
            _completedAt = now;
          }
        } else {
          _stableFrames = 0;
        }
        break;
      case ActiveLivenessStage.passed:
        break;
    }

    return ActiveLivenessUpdate(
      stage: _stage,
      hint: currentHint,
      passed: passed,
    );
  }

  /// A short detector miss is tolerated. A sustained missing, multiple, or
  /// undersized face invalidates the movement sequence and starts it over.
  bool registerInvalidFrame() {
    if (passed) return false;
    _invalidFrames++;
    if (_invalidFrames < 3) return false;
    reset();
    return true;
  }

  void reset({ActiveLivenessChallenge? withChallenge}) {
    if (withChallenge != null) challenge = withChallenge;
    _stage = ActiveLivenessStage.centerFace;
    _startedAt = null;
    _completedAt = null;
    _stableFrames = 0;
    _invalidFrames = 0;
    _peakAbsYaw = 0;
    _minimumEyeOpen = 1;
  }

  Map<String, dynamic> get evidence => {
    'challenge': challengeCode,
    'passed': passed,
    'duration_ms': _startedAt == null || _completedAt == null
        ? null
        : _completedAt!.difference(_startedAt!).inMilliseconds,
    'peak_abs_yaw': _peakAbsYaw,
    'minimum_eye_open': _minimumEyeOpen,
  };
}
