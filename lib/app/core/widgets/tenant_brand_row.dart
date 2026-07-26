import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../data/services/auth_service.dart';
import '../theme/app_colors.dart';

/// Compact tenant identity for light surfaces: the tenant logo beside its
/// brand name and legal company name. Sized for cards, unlike [BrandMark]
/// which is the full-size splash variant.
///
/// Falls back to the brand cached at login so the row still renders offline,
/// and to an initials badge when the tenant has no raster logo.
/// (SVG logos are skipped — flutter_svg doesn't render text-based SVGs well.)
class TenantBrandRow extends StatelessWidget {
  /// Logo box side length, in logical pixels before scaling.
  final double size;

  const TenantBrandRow({super.key, this.size = 34});

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
                Text(
                  brandName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 1.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w500,
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

    return Container(
      width: size.w,
      height: size.w,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size.w * 0.28),
        border: Border.all(color: AppColors.border),
      ),
      child: Image.network(
        logoUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _initialsBadge(brandName),
      ),
    );
  }

  Widget _initialsBadge(String brandName) {
    final initials = brandName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

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
        borderRadius: BorderRadius.circular(size.w * 0.28),
      ),
      child: Text(
        initials.isEmpty ? 'A' : initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: (size * 0.42).sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
