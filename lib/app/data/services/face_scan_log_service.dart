import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../providers/avana_api.dart';
import 'device_service.dart';

/// One recorded face-scan attempt, waiting to be flushed to the API.
class FaceScanEvent {
  const FaceScanEvent({
    required this.context,
    required this.outcome,
    required this.reason,
    this.step,
    this.message,
    this.metrics,
  });

  /// `enroll` (Daftar Wajah) or `verify` (scan before clocking in).
  final String context;

  /// `ok`, `fail`, or `blocked`.
  final String outcome;

  /// Machine-readable cause, e.g. `no_face`, `not_frontal`.
  final String reason;

  /// Enrollment step the attempt belongs to (0 = neutral, 1 = smile).
  final int? step;

  /// The hint the employee was shown, if any.
  final String? message;

  /// Whatever the detector measured: face count, head angles, probabilities.
  final Map<String, dynamic>? metrics;

  Map<String, dynamic> toJson() => {
    'context': context,
    'outcome': outcome,
    'reason': reason,
    if (step != null) 'step': step,
    if (message != null) 'message': message,
    if (metrics != null && metrics!.isNotEmpty) 'metrics': metrics,
  };
}

/// Ships face-scan diagnostics to the server.
///
/// Detection runs entirely on the phone, so when a scan never succeeds there is
/// nothing on the server to look at — the employee just watches the same hint
/// repeat, and support has no way to tell a bad camera frame from a device the
/// detector mishandles. This records each attempt and flushes in batches.
///
/// Two rules keep the scan loop from becoming a request loop: repeats of the
/// same reason are collapsed (only the first, then one every
/// [_repeatInterval], is kept), and the queue is flushed on a timer rather than
/// per event. Every failure here is swallowed — diagnostics must never be the
/// reason an employee can't clock in.
class FaceScanLogService extends GetxService {
  final AvanaApi _api = AvanaApi();

  final List<FaceScanEvent> _queue = [];
  final Map<String, DateTime> _lastSentAt = {};

  Timer? _flushTimer;
  bool _sending = false;

  /// How often a repeat of the same reason is worth recording again.
  static const _repeatInterval = Duration(seconds: 20);

  /// How long to wait for more events before sending what we have.
  static const _flushDelay = Duration(seconds: 4);

  /// Most events held at once; the API accepts 20 per request.
  static const _maxQueue = 20;

  /// Record one attempt. Returns immediately — the send happens later.
  void record(FaceScanEvent event) {
    // Successes and hard blocks are always kept: they are the ones that
    // explain what finally worked (or refused to).
    if (event.outcome == 'fail' && _isRepeat(event.reason)) {
      return;
    }
    _lastSentAt[event.reason] = DateTime.now();

    _queue.add(event);
    if (_queue.length >= _maxQueue) {
      unawaited(flush());
      return;
    }

    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDelay, () => unawaited(flush()));
  }

  /// Send everything queued. Safe to call at any time, including on dispose.
  Future<void> flush() async {
    _flushTimer?.cancel();

    // A send already in flight keeps whatever arrived meanwhile; without
    // re-arming the timer those events would sit in the queue until the next
    // scan happened to record one, and a session that ends right after would
    // lose them — exactly the failures worth keeping.
    if (_sending) {
      if (_queue.isNotEmpty) {
        _flushTimer = Timer(_flushDelay, () => unawaited(flush()));
      }

      return;
    }

    if (_queue.isEmpty) return;

    final batch = List<FaceScanEvent>.from(_queue);
    _queue.clear();
    _sending = true;

    try {
      final device = await Get.find<DeviceService>().current();
      await _api.logFaceScans(
        events: batch.map((e) => e.toJson()).toList(),
        device: device.toJson(),
      );
    } catch (e) {
      // Never resurface: the log is a diagnostic aid, not part of the flow.
      debugPrint('[FaceScanLog] flush failed: $e');
    } finally {
      _sending = false;
    }
  }

  bool _isRepeat(String reason) {
    final last = _lastSentAt[reason];

    return last != null && DateTime.now().difference(last) < _repeatInterval;
  }

  @override
  void onClose() {
    _flushTimer?.cancel();
    super.onClose();
  }
}
