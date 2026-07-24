import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../routes/app_pages.dart';

/// A brief branded welcome shown right after login: the tenant's own company
/// logo (white-label), then it forwards to the main app. Falls back to the
/// company name when the tenant has no uploaded logo.
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
      await Future.delayed(const Duration(milliseconds: 1500));
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _logo(logo, company),
              SizedBox(height: 18.h),
              Text(
                'Selamat datang',
                style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
              ),
              SizedBox(height: 4.h),
              Text(
                company,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 40.h),
              SizedBox(
                width: 24.w,
                height: 24.w,
                child: const CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders the tenant logo (SVG or raster), with a name-badge fallback.
  Widget _logo(String? url, String company) {
    if (url == null || url.isEmpty) {
      return _fallback(company);
    }

    final logo = url.toLowerCase().contains('.svg')
        ? SvgPicture.network(
            url,
            height: 84.h,
            width: 220.w,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => _fallback(company),
          )
        : Image.network(
            url,
            height: 84.h,
            width: 220.w,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _fallback(company),
          );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 90.h, maxWidth: 240.w),
      child: logo,
    );
  }

  /// A tinted rounded badge with the company initials when no logo exists.
  Widget _fallback(String company) {
    final initials = company
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      width: 76.w,
      height: 76.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        initials.isEmpty ? 'A' : initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: 26.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
