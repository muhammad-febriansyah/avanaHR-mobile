import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../data/services/auth_service.dart';
import '../theme/app_colors.dart';

/// Compact tenant identity for light surfaces: the tenant logo beside the
/// signed-in employee's role, the tenant brand name, and its legal company
/// name. Sized for cards — this is the only place the app shows tenant
/// branding now that the splash screens are AvanaHR's own.
///
/// Falls back to the brand cached at login so the row still renders offline,
/// and to an initials badge when the tenant has no raster logo.
/// (SVG logos are skipped — flutter_svg doesn't render text-based SVGs well.)
class TenantBrandRow extends StatelessWidget {
  /// Logo box height, in logical pixels before scaling. The box is square for
  /// initials, but widens up to [_maxLogoAspect] times this for wordmarks.
  final double size;

  /// Widest the logo may get, as a multiple of [size]. Tenant logos are
  /// usually wordmarks around 4:1, and anything narrower than that scales them
  /// down by width instead of letting them fill the row height.
  static const double _maxLogoAspect = 3.6;

  /// Hard ceiling on logo width as a fraction of screen width, so the tenant
  /// name keeps its half of the row on narrow phones.
  static const double _maxLogoScreenFraction = 0.42;

  const TenantBrandRow({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();

    return Obx(() {
      final user = auth.user.value;
      final box = GetStorage();

      final logoUrl = _firstFilled([
        user?.tenantLogoUrl,
        box.read<String>(kBrandLogoKey),
      ]);
      final legalName = _firstFilled([
        user?.tenantName,
        box.read<String>(kBrandNameKey),
      ]);
      final brandName = _firstFilled([user?.tenantBrandName, legalName]);

      if (brandName == null) {
        return const SizedBox.shrink();
      }

      // Job title first, department second: the position is what people
      // identify themselves by. Falls back to a generic label so the eyebrow
      // never collapses for employees whose record has no employment block —
      // `roles` is no help, the API hands everyone `["employee"]`.
      final role = user == null
          ? null
          : _firstFilled([
              user.employee?.employment?.position,
              user.employee?.employment?.department,
              user.isManager ? 'Manajer' : 'Karyawan',
            ]);

      // Only show the second line when it adds something beyond the first.
      final subtitle = (legalName != null && legalName != brandName)
          ? legalName
          : null;

      return Row(
        children: [
          _logo(logoUrl, brandName),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (role != null) ...[
                  Text(
                    role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 3.h),
                ],
                // Long legal names (PT … (Persero) Tbk) wrap onto a second line
                // rather than being cut to an ellipsis — the card is a Column
                // in a scroll view, so growing a line costs nothing. The line
                // caps and ellipsis stay as the guard against a pathological
                // name pushing the whole card open.
                Text(
                  brandName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: AppColors.navy,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _logo(String? logoUrl, String brandName) {
    final showImage =
        logoUrl != null && !logoUrl.toLowerCase().endsWith('.svg');

    if (!showImage) {
      return _initialsBadge(brandName);
    }

    // No frame around the logo: on a white card the border and inner padding
    // only ate the room the wordmark needs to stay legible. The image sizes
    // itself from its own aspect ratio, so height drives it and width follows.
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: size.w,
        maxWidth: math.min(
          (size * _maxLogoAspect).w,
          _maxLogoScreenFraction.sw,
        ),
        minHeight: size.w,
        maxHeight: size.w,
      ),
      child: Image.network(
        logoUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _initialsBadge(brandName),
      ),
    );
  }

  Widget _initialsBadge(String brandName) {
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
        borderRadius: BorderRadius.circular(size.w * 0.26),
      ),
      child: Text(
        _initials(brandName),
        style: TextStyle(
          color: Colors.white,
          fontSize: (size * 0.38).sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials(String brandName) {
    final initials = brandName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return initials.isEmpty ? 'A' : initials;
  }

  static String? _firstFilled(List<String?> candidates) {
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
