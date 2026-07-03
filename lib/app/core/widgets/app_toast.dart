import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Sonner-style feedback for the app. Mirrors the web toast semantics.
class AppToast {
  static void success(String message) => _show(message, ToastificationType.success);
  static void error(String message) => _show(message, ToastificationType.error);
  static void warning(String message) => _show(message, ToastificationType.warning);
  static void info(String message) => _show(message, ToastificationType.info);

  static void _show(String message, ToastificationType type) {
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
      autoCloseDuration: const Duration(seconds: 4),
      borderRadius: BorderRadius.circular(12),
    );
  }
}
