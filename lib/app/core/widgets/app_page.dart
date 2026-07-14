import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';

/// Standard page chrome for the whole app: a blue gradient header with a subtle
/// diagonal mesh ([BrandMeshPainter]) and a flat white content area underneath —
/// the same visual language as the Beranda (home) screen. Every non-home screen
/// should use this so the app reads as one product.
class AppPage extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Header trailing actions (use [HeaderAction]).
  final List<Widget> actions;

  /// Show the back button (false for bottom-nav tabs).
  final bool showBack;

  /// Reserve bottom space equal to the persistent nav bar so scroll content is
  /// not hidden behind it. Enable only on bottom-nav tab screens.
  final bool reserveBottomNav;

  /// Pull-to-refresh handler. When set, [child] must be scrollable.
  final Future<void> Function()? onRefresh;

  final Widget child;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.reserveBottomNav = false,
    this.onRefresh,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  /// Vertical space the persistent Style 13 nav bar occupies (floating-button
  /// gutter + bar + bottom safe area) — scroll views on tab screens pad their
  /// bottom by this so their last item clears the bar.
  static double bottomNavClearance(BuildContext context) =>
      87.h + MediaQuery.of(context).viewPadding.bottom;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.primary,
        child: child,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: Column(
          children: [
            _header(context),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: reserveBottomNav
                    ? EdgeInsets.only(bottom: bottomNavClearance(context))
                    : EdgeInsets.zero,
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: CustomPaint(painter: const BrandMeshPainter()),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                showBack ? 8.w : 20.w,
                10.h,
                12.w,
                18.h,
              ),
              child: Row(
                children: [
                  if (showBack) ...[
                    HeaderAction(Iconsax.arrow_left_2, () => Get.back()),
                    SizedBox(width: 8.w),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: EdgeInsets.only(top: 1.h),
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle diagonal crosshatch (mesh) painted behind the brand blue header —
/// shared by every page header and the home screen for one visual language.
class BrandMeshPainter extends CustomPainter {
  /// Line color (pre-applied alpha). Defaults to a faint white for blue headers;
  /// pass a tinted color for the mesh on light backgrounds (e.g. the splash).
  final Color color;

  const BrandMeshPainter({this.color = const Color(0x0FFFFFFF)});

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color;

    const gap = 24.0;
    final h = size.height;

    // ╲ diagonals (top-left → bottom-right).
    for (var d = -h; d < size.width + h; d += gap) {
      canvas.drawLine(Offset(d, 0), Offset(d + h, h), line);
    }
    // ╱ diagonals (top-right → bottom-left).
    for (var d = 0.0; d < size.width + h; d += gap) {
      canvas.drawLine(Offset(d, 0), Offset(d - h, h), line);
    }
  }

  @override
  bool shouldRepaint(covariant BrandMeshPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A translucent white icon button for the [AppPage] header.
class HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  const HeaderAction(this.icon, this.onTap, {super.key, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 8.w),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100.r),
        child: Stack(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20.sp),
            ),
            if (badge > 0)
              Positioned(
                right: 3.w,
                top: 3.h,
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: AppColors.destructive,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(minWidth: 15.w, minHeight: 15.w),
                  child: Text(
                    '$badge',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A flat white card surface with a hairline border — the standard container
/// for list items and grouped content.
class ContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const ContentCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding ?? EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: child,
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: card,
    );
  }
}

/// A rounded tinted bubble holding a leading icon — used on list rows.
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBubble(this.icon, this.color, {super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular((size * 0.29).r),
      ),
      child: Icon(icon, color: color, size: (size * 0.47).sp),
    );
  }
}

/// A label → value row for detail/complex-data screens; the label column is
/// fixed-width so values line up in a scannable column.
class InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;

  const InfoRow(this.label, this.value, {super.key, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value!.isEmpty ? '-' : value!,
              style: TextStyle(
                color: valueColor ?? AppColors.navy,
                fontWeight: FontWeight.w500,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
