import 'package:flutter/material.dart';

/// AvanaHR brand palette (light mode only). Mirrors the web design tokens.
///
/// The brand colours ([primary], [primaryHover], [primaryLight]) are mutable so
/// the app can re-brand to a tenant's own accent colour (set on the web
/// "Tampilan & Tema" screen) via [applyBrand].
class AppColors {
  static Color primary = const Color(0xFF2547F9); // brand blue
  static Color primaryHover = const Color(0xFF1E3EDC); // pressed / hover
  static Color primaryLight = const Color(0xFFEEF2FF); // tinted primary fill

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

  static const _defaultPrimary = Color(0xFF2547F9);

  /// Re-brand the app from a tenant accent hex (e.g. `#2F54C9`). Passing null
  /// or an invalid value resets to the default AvanaHR blue. Derives the hover
  /// (slightly darker) and light-fill (tint) shades from the accent.
  static void applyBrand(String? accentHex) {
    final accent = _parseHex(accentHex) ?? _defaultPrimary;
    primary = accent;
    primaryHover = _shift(accent, -0.12);
    primaryLight = _tint(accent, 0.90);
  }

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length != 6) return null;
    final value = int.tryParse(h, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  /// Lighten (positive) or darken (negative) a colour by a lightness delta.
  static Color _shift(Color c, double delta) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  /// A very light tint of a colour, for subtle active/hover fills.
  static Color _tint(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * 0.6).clamp(0.0, 1.0))
        .withLightness(
          (hsl.lightness + (1 - hsl.lightness) * amount).clamp(0.0, 1.0),
        )
        .toColor();
  }
}
