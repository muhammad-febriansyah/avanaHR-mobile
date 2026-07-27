import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import '../theme/app_colors.dart';
import 'robot_icon.dart';

/// Floating shortcut to the AI assistant.
///
/// The caller positions it — the shell stacks it bottom-right over the tabs —
/// so this widget stays a plain button and can be reused elsewhere.
///
/// Three motions, in order of how loud they are:
/// * an entrance pop, so the button reads as arriving with the tab rather than
///   being part of the page chrome;
/// * a slow halo ring that keeps pulsing — the only cue that the button is an
///   assistant waiting to be asked, kept at low alpha so it never competes
///   with the content behind it;
/// * a press dip for tactile feedback (this widget is a GestureDetector, so
///   there is no ripple to lean on).
class AiFab extends StatefulWidget {
  const AiFab({super.key});

  @override
  State<AiFab> createState() => _AiFabState();
}

class _AiFabState extends State<AiFab> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _entrance;
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..forward();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _entrance.dispose();
    _press.dispose();
    super.dispose();
  }

  void _onTap() {
    // Let the dip finish before the route push so the feedback is visible.
    _press.reverse();
    Get.toNamed(Routes.AI_ASSISTANT);
  }

  @override
  Widget build(BuildContext context) {
    final size = 54.w;
    final entrance = CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutBack,
    );
    // Only the leading 55% of the cycle animates; the tail is the rest beat
    // that keeps the pulse from reading as a spinner.
    final ring = CurvedAnimation(
      parent: _pulse,
      curve: const Interval(0, 0.55, curve: Curves.easeOut),
    );

    return Semantics(
      button: true,
      label: 'Buka AI Assistant',
      child: GestureDetector(
        onTap: _onTap,
        onTapDown: (_) => _press.forward(),
        onTapCancel: () => _press.reverse(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _entrance, _press]),
          builder: (context, child) {
            final pop = Tween<double>(begin: 0.4, end: 1).evaluate(entrance);
            final dip = 1 - (_press.value * 0.12);

            return Transform.scale(
              scale: pop * dip,
              child: Opacity(
                opacity: _entrance.value.clamp(0.0, 1.0),
                child: SizedBox(
                  // Layout box stays the button's own size: the halo overflows
                  // it (Clip.none) so the widget's position and hit target are
                  // unchanged by the animation. Max ring overflow is
                  // 54 * 0.45 / 2 ≈ 12dp, inside the 16dp screen inset the
                  // shell positions it with, so nothing gets cut off.
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Transform.scale(
                        scale: 1 + (ring.value * 0.45),
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(
                              alpha: 0.30 * (1 - ring.value),
                            ),
                          ),
                        ),
                      ),
                      child!,
                    ],
                  ),
                ),
              ),
            );
          },
          // The button face never changes, so it is built once and reused
          // across every frame of the three animations.
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Not const: AppColors.primary follows the tenant's brand colour.
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: RobotIcon(size: 25.sp, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
