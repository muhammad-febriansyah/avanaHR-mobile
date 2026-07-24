import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../routes/app_pages.dart';

/// A brief branded welcome shown right after login: the tenant's own logo /
/// name and brand colour, then it forwards to the main app. Keeps a clean,
/// centred layout whether or not the tenant has uploaded a logo.
class BrandSplashView extends StatefulWidget {
  const BrandSplashView({super.key});

  @override
  State<BrandSplashView> createState() => _BrandSplashViewState();
}

class _BrandSplashViewState extends State<BrandSplashView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        Get.offAllNamed(Routes.MAIN);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Get.find<AuthService>().user.value;
    final logo = user?.tenantLogoUrl;
    final company = user?.tenantName ?? 'AvanaHR';

    // flutter_svg does not render text-based SVGs reliably, so only raster
    // logos are shown as images; everything else falls back to an initials mark.
    final showImage =
        logo != null && logo.isNotEmpty && !logo.toLowerCase().contains('.svg');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Column(
              children: [
                const Spacer(flex: 5),
                showImage ? _logoCard(logo) : _initialsMark(company),
                SizedBox(height: 22.h),
                Text(
                  company,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Selamat datang',
                  style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
                ),
                const Spacer(flex: 5),
                SizedBox(
                  width: 26.w,
                  height: 26.w,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.6,
                  ),
                ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A white rounded card holding the tenant's raster logo.
  Widget _logoCard(String url) {
    return Container(
      constraints: BoxConstraints(maxWidth: 220.w, maxHeight: 120.h),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _initialsMark(
          Get.find<AuthService>().user.value?.tenantName ?? 'AvanaHR',
        ),
      ),
    );
  }

  /// A brand-coloured rounded badge with the company initials.
  Widget _initialsMark(String company) {
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
