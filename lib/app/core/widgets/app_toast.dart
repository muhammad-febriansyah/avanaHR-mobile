import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Sonner-style feedback for the app. Mirrors the web toast semantics.
class AppToast {
  static void success(String message) => _show(message, ToastificationType.success);
  static void error(String message) => _show(message, ToastificationType.error);
  static void info(String message) => _show(message, ToastificationType.info);

  static void _show(String message, ToastificationType type) {
    toastification.show(
      type: type,
      style: ToastificationStyle.fillColored,
      title: Text(message),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 3),
      borderRadius: BorderRadius.circular(12),
    );
  }
}
