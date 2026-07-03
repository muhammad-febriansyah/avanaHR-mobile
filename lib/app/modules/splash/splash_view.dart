import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/app_config.dart';
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
    final config = Get.find<ConfigService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Obx(() {
          final cfg = config.config.value;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _logo(cfg),
              SizedBox(height: 40.h),
              SizedBox(
                width: 22.w,
                height: 22.w,
                child: const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.2),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Brand logo from the web settings (`logo_url`); falls back to the bundled
  /// vector when it's unset or fails to load.
  Widget _logo(AppConfig cfg) {
    final url = cfg.logoUrl;
    if (url != null && url.isNotEmpty) {
      if (url.toLowerCase().endsWith('.svg')) {
        return SvgPicture.network(url, height: 120.h, placeholderBuilder: (_) => SizedBox(height: 120.h));
      }

      return Image.network(
        url,
        height: 120.h,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _fallbackLogo(),
      );
    }

    return _fallbackLogo();
  }

  Widget _fallbackLogo() => SvgPicture.asset(
        'assets/avanahr_onboarding_growth.svg',
        height: 130.h,
        placeholderBuilder: (_) => SizedBox(height: 130.h),
      );
}
