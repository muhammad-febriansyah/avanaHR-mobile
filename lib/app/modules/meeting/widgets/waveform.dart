import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

/// Live microphone levels drawn as a bar meter.
///
/// Purely reassurance: it is the only thing on the recorder screen that proves
/// the microphone is still hearing the room, since the transcript can lag a
/// sentence behind and a silent pause looks identical to a dead mic.
class Waveform extends StatelessWidget {
  final List<double> levels;
  final bool paused;

  const Waveform({super.key, required this.levels, this.paused = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64.h,
      child: CustomPaint(
        painter: _WaveformPainter(
          levels: levels,
          color: paused ? AppColors.textMuted.withValues(alpha: 0.35) : null,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> levels;
  final Color? color;

  _WaveformPainter({required this.levels, this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;

    const barWidth = 3.0;
    const gap = 4.0;
    final slots = (size.width / (barWidth + gap)).floor();
    if (slots <= 0) return;

    final centre = size.height / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    // Newest on the right: the meter reads like a tape running forward.
    final visible = levels.length > slots
        ? levels.sublist(levels.length - slots)
        : levels;

    final offset = slots - visible.length;

    for (var i = 0; i < visible.length; i++) {
      final level = visible[i];
      final height = math.max(3.0, level * size.height * 0.92);
      final x = (offset + i) * (barWidth + gap) + barWidth / 2;

      // Older bars fade, so the eye lands on what is being said now.
      final age = i / math.max(1, visible.length - 1);
      paint.color =
          color ??
          Color.lerp(
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.primary,
            age,
          )!;

      canvas.drawLine(
        Offset(x, centre - height / 2),
        Offset(x, centre + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.levels != levels || old.color != color;
}
