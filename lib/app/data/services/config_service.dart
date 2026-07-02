import 'package:get/get.dart';

import '../models/app_config.dart';
import '../models/onboarding_slide.dart';
import '../providers/avana_api.dart';

/// Holds the public app branding (name, logo, tagline) pulled from the web
/// "Pengaturan Web" settings, plus the onboarding slides. Falls back to
/// sensible defaults when offline so splash / onboarding / login always render.
class ConfigService extends GetxService {
  final _api = AvanaApi();

  final Rx<AppConfig> config = const AppConfig().obs;

  /// Onboarding slides from the web CRUD. Empty until loaded (or on failure),
  /// in which case the onboarding screen uses its bundled fallback slides.
  final RxList<OnboardingSlide> slides = <OnboardingSlide>[].obs;

  AppConfig get value => config.value;

  Future<void> load() async {
    try {
      config.value = await _api.appConfig();
    } catch (_) {
      // Keep defaults on failure.
    }
    try {
      slides.value = await _api.onboardingSlides();
    } catch (_) {
      // Keep bundled onboarding slides on failure.
    }
  }
}
