import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_mark.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/config_service.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final storage = Get.find<StorageService>();
    final auth = Get.find<AuthService>();

    // Pull branding first, then hold briefly so the splash is actually seen.
    await Get.find<ConfigService>().load();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    if (auth.isLoggedIn && await auth.loadMe()) {
      Get.offAllNamed(Routes.MAIN);
      return;
    }
    if (!storage.onboarded) {
      Get.offAllNamed(Routes.ONBOARDING);
      return;
    }
    Get.offAllNamed(Routes.LOGIN);
  }

  @override
  Widget build(BuildContext context) {
    // AvanaHR is only the pre-login / onboarding splash. Once there is a session
    // the launch splash shows the tenant brand — matching the post-login
    // BrandSplash — so a cold start or hot restart never flips back to AvanaHR.
    final auth = Get.find<AuthService>();
    final box = GetStorage();
    final loggedIn = auth.isLoggedIn;
    final cachedName = box.read<String>(kBrandNameKey);
    // Prefer the cached brand (persisted at login); fall back to the live user
    // if this frame runs before the cache is warm.
    final company = (cachedName != null && cachedName.isNotEmpty)
        ? cachedName
        : (auth.user.value?.tenantName ?? '');
    final logo =
        box.read<String>(kBrandLogoKey) ?? auth.user.value?.tenantLogoUrl;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        // White — matches the native launch screen so the handoff is seamless.
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loggedIn) ...[
                BrandMark(logoUrl: logo, company: company),
                if (company.isNotEmpty) ...[
                  SizedBox(height: 18.h),
                  Text(
                    company,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ] else
                Image.asset(
                  'assets/AvanaHR.png',
                  width: 200.w,
                  fit: BoxFit.contain,
                  semanticLabel: 'AvanaHR',
                ),
              SizedBox(height: 44.h),
              SizedBox(
                width: 26.w,
                height: 26.w,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
