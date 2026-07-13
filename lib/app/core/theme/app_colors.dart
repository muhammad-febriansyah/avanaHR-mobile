import 'package:flutter/material.dart';

/// AvanaHR brand palette (light mode only). Mirrors the web design tokens.
class AppColors {
  static const primary = Color(0xFF2547F9); // brand blue
  static const primaryHover = Color(0xFF1E3EDC); // pressed / hover
  static const primaryLight = Color(0xFFEEF2FF); // tinted primary fill

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const destructive = Color(0xFFEF4444); // danger
  static const danger = destructive; // alias
  static const info = Color(0xFF06B6D4);

  static const background = Color(0xFFF8FAFC); // app canvas
  static const surface = Color(0xFFFFFFFF); // cards, sheets, app bars
  static const muted = Color(0xFFF1F5F9); // neutral fill (chips, inputs)
  static const border = Color(0xFFE2E8F0);

  static const textPrimary = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B); // text-secondary

  /// Deep slate — strong headings. Kept as `navy` for existing call sites.
  static const navy = Color(0xFF0F172A);

  /// Secondary sky accent — used sparingly (nav, map markers).
  static const accent = Color(0xFF6E9BE6);
}
