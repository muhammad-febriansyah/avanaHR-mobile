import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../data/services/config_service.dart';
import '../theme/app_colors.dart';

/// Brand identity for light surfaces. Renders the uploaded web logo (from
/// Pengaturan Web) when available, otherwise a branded icon mark + site name.
class BrandLogo extends StatelessWidget {
  /// Logo image height (also drives the fallback mark size).
  final double height;
  final bool showName;

  const BrandLogo({super.key, this.height = 40, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final cfg = Get.find<ConfigService>();

    return Obx(() {
      final c = cfg.config.value;
      final logo = c.logoUrl;

      if (logo != null && logo.isNotEmpty) {
        return Image.network(
          logo,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => _fallback(c.siteName),
        );
      }
      return _fallback(c.siteName);
    });
  }

  Widget _fallback(String name) {
    final box = height;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: box,
          width: box,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(box * 0.28),
          ),
          child: Icon(Iconsax.briefcase, color: Colors.white, size: box * 0.5),
        ),
        if (showName) ...[
          SizedBox(width: 10.w),
          Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              fontSize: (height * 0.42).sp,
            ),
          ),
        ],
      ],
    );
  }
}
