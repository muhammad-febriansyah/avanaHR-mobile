import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_mark.dart';
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
                BrandMark(logoUrl: logo, company: company),
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
}
