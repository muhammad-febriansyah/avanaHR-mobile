import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
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

    // Pull branding (name/logo) first, then hold briefly so the API logo is
    // actually visible before we navigate away.
    await Get.find<ConfigService>().load();
    await Future.delayed(const Duration(milliseconds: 700));

    // Logged in → straight into the app (splash only, skip onboarding).
    if (auth.isLoggedIn && await auth.loadMe()) {
      Get.offAllNamed(Routes.MAIN);
      return;
    }
    // Not logged in → show the intro once, then the login screen.
    if (!storage.onboarded) {
      Get.offAllNamed(Routes.ONBOARDING);
      return;
    }
    Get.offAllNamed(Routes.LOGIN);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bundled brand logo — no network dependency on the API for the
            // very first frame.
            Image.asset(
              'assets/AvanaHR.png',
              height: 130.h,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 40.h),
            SizedBox(
              width: 22.w,
              height: 22.w,
              child: const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
