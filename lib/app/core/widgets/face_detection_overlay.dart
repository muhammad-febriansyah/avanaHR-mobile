import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FaceDetectionOverlay extends StatelessWidget {
  const FaceDetectionOverlay({
    required this.boxes,
    required this.previewSize,
    required this.faceAccepted,
    super.key,
  });

  final List<Rect> boxes;
  final Size previewSize;
  final bool faceAccepted;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _FaceDetectionPainter(
          boxes: boxes,
          previewSize: previewSize,
          faceAccepted: faceAccepted,
        ),
      ),
    );
  }
}

class _FaceDetectionPainter extends CustomPainter {
  const _FaceDetectionPainter({
    required this.boxes,
    required this.previewSize,
    required this.faceAccepted,
  });

  final List<Rect> boxes;
  final Size previewSize;
  final bool faceAccepted;

  @override
  void paint(Canvas canvas, Size size) {
    if (boxes.isEmpty || previewSize.isEmpty || size.isEmpty) return;

    final scale = math.max(
      size.width / previewSize.width,
      size.height / previewSize.height,
    );
    final horizontalOffset = (size.width - previewSize.width * scale) / 2;
    final verticalOffset = (size.height - previewSize.height * scale) / 2;
    final color = boxes.length > 1
        ? AppColors.danger
        : faceAccepted
        ? AppColors.success
        : Colors.white;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    for (final normalized in boxes) {
      final rect = Rect.fromLTRB(
        horizontalOffset + normalized.left * previewSize.width * scale,
        verticalOffset + normalized.top * previewSize.height * scale,
        horizontalOffset + normalized.right * previewSize.width * scale,
        verticalOffset + normalized.bottom * previewSize.height * scale,
      );
      final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rounded, fill);
      canvas.drawRRect(rounded, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _FaceDetectionPainter oldDelegate) {
    return oldDelegate.boxes != boxes ||
        oldDelegate.previewSize != previewSize ||
        oldDelegate.faceAccepted != faceAccepted;
  }
}
