import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Sonner-style feedback for the app. Mirrors the web toast semantics.
class AppToast {
  /// How long a toast stays on screen.
  static const _visibleFor = Duration(seconds: 4);

  /// When each message was last shown, so the same sentence cannot stack on
  /// top of itself. Two taps on a blocked button used to leave two identical
  /// banners covering the screen, and neither said anything the first had not.
  static final Map<String, DateTime> _shownAt = {};

  static void success(String message) =>
      _show(message, ToastificationType.success);
  static void error(String message) => _show(message, ToastificationType.error);
  static void warning(String message) =>
      _show(message, ToastificationType.warning);
  static void info(String message) => _show(message, ToastificationType.info);

  static void _show(String message, ToastificationType type) {
    if (_isDuplicate(message)) return;

    toastification.show(
      type: type,
      style: ToastificationStyle.fillColored,
      // Let long messages (e.g. device-binding errors) wrap fully instead of
      // truncating to one line.
      title: Text(
        message,
        maxLines: 5,
        softWrap: true,
        overflow: TextOverflow.visible,
        style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
      ),
      alignment: Alignment.topCenter,
      autoCloseDuration: _visibleFor,
      borderRadius: BorderRadius.circular(12),
    );
  }

  /// True while an identical message is still on screen. Entries older than the
  /// visible window are dropped as we go, so the map never grows unbounded.
  static bool _isDuplicate(String message) {
    final now = DateTime.now();
    _shownAt.removeWhere((_, at) => now.difference(at) >= _visibleFor);

    if (_shownAt.containsKey(message)) return true;
    _shownAt[message] = now;

    return false;
  }

  /// Forget what has been shown — for tests, and for a sign-out that should not
  /// swallow the first toast of the next session.
  @visibleForTesting
  static void reset() => _shownAt.clear();

  /// Whether this message would be rendered rather than swallowed as a repeat.
  /// Exercises the dedupe without needing a widget tree to show a toast in.
  @visibleForTesting
  static bool debugWouldShow(String message) => !_isDuplicate(message);
}
