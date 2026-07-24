import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// The tenant brand mark used on the splash screens: a raster company logo in a
/// white card, or a brand-coloured initials badge when no logo is available.
/// (SVG logos are skipped — flutter_svg doesn't render text-based SVGs well.)
class BrandMark extends StatelessWidget {
  final String? logoUrl;
  final String company;

  const BrandMark({super.key, required this.logoUrl, required this.company});

  bool get _showImage =>
      logoUrl != null &&
      logoUrl!.isNotEmpty &&
      !logoUrl!.toLowerCase().contains('.svg');

  @override
  Widget build(BuildContext context) {
    if (!_showImage) {
      return _initialsMark();
    }

    return Container(
      constraints: BoxConstraints(maxWidth: 220.w, maxHeight: 120.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Image.network(
        logoUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _initialsMark(),
      ),
    );
  }

  Widget _initialsMark() {
    final initials = company
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      width: 84.w,
      height: 84.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        initials.isEmpty ? 'A' : initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: 30.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
