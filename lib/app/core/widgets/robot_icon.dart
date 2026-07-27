import 'package:flutter/material.dart';

/// The assistant's robot mark, drawn rather than picked from an icon font.
///
/// Material's `Icons.smart_toy` is a squat box that reads as a toaster at the
/// sizes we use it (15–30sp), and neither Iconsax nor Cupertino ships a robot
/// at all — so the shape is a path: antenna dot, thin stem, tall rounded head
/// with two capsule eyes cut out of it.
///
/// [size] matches the `size` of an [Icon]; [color] fills the mark and the eyes
/// are genuine holes, so it sits on any background.
class RobotIcon extends StatelessWidget {
  final double size;
  final Color color;

  const RobotIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RobotPainter(color)),
    );
  }
}

class _RobotPainter extends CustomPainter {
  final Color color;

  const _RobotPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Authored on the same 24×24 grid Material icons use, then scaled — so
    // swapping this in for an Icon of the same `size` keeps the optical weight.
    canvas.scale(size.shortestSide / 24.0);
    final paint = Paint()..color = color;

    canvas.drawCircle(const Offset(12, 2.5), 1.5, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(11.25, 3.4, 12.75, 7.4),
        const Radius.circular(0.75),
      ),
      paint,
    );

    final head = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(3.4, 6.4, 20.6, 19.6),
          const Radius.circular(5.4),
        ),
      );
    // Capsule eyes, not circles: the vertical slot is what separates a robot
    // from a smiley at 15sp.
    final eyes = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(7.4, 10.5, 10.1, 14.6),
          const Radius.circular(1.35),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(13.9, 10.5, 16.6, 14.6),
          const Radius.circular(1.35),
        ),
      );

    canvas.drawPath(Path.combine(PathOperation.difference, head, eyes), paint);
  }

  @override
  bool shouldRepaint(covariant _RobotPainter oldDelegate) =>
      oldDelegate.color != color;
}
