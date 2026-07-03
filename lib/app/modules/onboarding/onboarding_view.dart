import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/config_service.dart';
import '../../data/services/storage_service.dart';
import '../../routes/app_pages.dart';

/// One intro slide. Either a bundled [asset] (offline fallback) or a remote
/// [imageUrl] served by the web "Onboarding App" CRUD.
class _Slide {
  final String? asset;
  final String? imageUrl;
  final String title;
  final String body;
  const _Slide({this.asset, this.imageUrl, required this.title, required this.body});

  bool get isSvg => (imageUrl ?? asset ?? '').toLowerCase().endsWith('.svg');
}

/// Bundled fallback used when the web slides can't be loaded (offline).
const _fallbackSlides = <_Slide>[
  _Slide(
    asset: 'assets/avanahr_onboarding_attendance.svg',
    title: 'Absensi Anti Ribet',
    body: 'Clock-in & clock-out berbasis GPS dan face recognition — langsung dari ponsel, di mana saja.',
  ),
  _Slide(
    asset: 'assets/avanahr_onboarding_leave_payroll.svg',
    title: 'Cuti & Slip Gaji',
    body: 'Ajukan cuti, lembur, dan reimbursement. Pantau status & lihat slip gaji kapan saja.',
  ),
  _Slide(
    asset: 'assets/avanahr_onboarding_growth.svg',
    title: 'Tumbuh Bersama',
    body: 'Semua kebutuhan HR dalam satu aplikasi. Advancing People, Empowering Growth.',
  ),
];

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pageC = PageController();
  int _index = 0;
  late final List<_Slide> _slides;

  @override
  void initState() {
    super.initState();
    // Prefer the web-managed slides (loaded during splash); fall back to the
    // bundled assets when none are available/offline.
    final remote = Get.find<ConfigService>().slides;
    _slides = remote.isNotEmpty
        ? remote.map((s) => _Slide(imageUrl: s.imageUrl, title: s.title, body: s.subtitle)).toList()
        : _fallbackSlides;
  }

  bool get _isLast => _index == _slides.length - 1;

  Future<void> _finish() async {
    // Persist the flag before navigating so a hard-kill right after can't
    // send the user back to onboarding.
    await Get.find<StorageService>().setOnboarded();
    Get.offAllNamed(Routes.LOGIN);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageC.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _pageC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                // Top bar: skip only (clean, illustration-first).
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 4.h, 12.w, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedOpacity(
                        opacity: _isLast ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: TextButton(
                          onPressed: _isLast ? null : _finish,
                          child: Text(
                            'Lewati',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Swipeable slides
                Expanded(
                  child: PageView.builder(
                    controller: _pageC,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => _SlideContent(slide: _slides[i]),
                  ),
                ),

                // Indicator + CTA
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 20.h),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            margin: EdgeInsets.symmetric(horizontal: 4.w),
                            height: 8.w,
                            width: active ? 24.w : 8.w,
                            decoration: BoxDecoration(
                              color: active ? AppColors.primary : AppColors.border,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _next,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_isLast ? 'Mulai Sekarang' : 'Lanjut'),
                              SizedBox(width: 8.w),
                              Icon(_isLast ? Iconsax.tick_circle : Iconsax.arrow_right_3, size: 18.sp),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  final _Slide slide;
  const _SlideContent({required this.slide});

  Widget _illustration() {
    final url = slide.imageUrl;
    if (url != null && url.isNotEmpty) {
      return slide.isSvg
          ? SvgPicture.network(url, fit: BoxFit.contain, placeholderBuilder: (_) => const SizedBox.shrink())
          : Image.network(url, fit: BoxFit.contain);
    }
    return SvgPicture.asset(
      slide.asset ?? 'assets/avanahr_onboarding_growth.svg',
      fit: BoxFit.contain,
      placeholderBuilder: (_) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Column(
        children: [
          // Illustration floats large on the white background — no card.
          Expanded(
            flex: 6,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: _illustration(),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1.2, letterSpacing: -0.4),
          ),
          SizedBox(height: 14.h),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: AppColors.textMuted, height: 1.6),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}
