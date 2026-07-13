import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/services/config_service.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = Get.find<ConfigService>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _header(cfg),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: 0.6.sh),
                  color: AppColors.background,
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                  // The form card straddles the blue header / white seam, the
                  // same overlap as the home hero card.
                  child: Transform.translate(
                    offset: Offset(0, -44.h),
                    child: _formCard(cfg),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Solid-primary panel: welcome copy only (logo sits on the white sheet).
  Widget _header(ConfigService cfg) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: CustomPaint(painter: const BrandMeshPainter()),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 36.h, 24.w, 64.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brandMark(cfg),
                  SizedBox(height: 20.h),
                  Text(
                    'Selamat datang kembali',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Masuk untuk kelola absensi, cuti & slip gaji Anda.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13.sp,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Brand logo shown directly on the blue header (no background). The
  /// no-logo fallback uses white marks so it still reads on blue.
  Widget _brandMark(ConfigService cfg) {
    return Obx(() {
      final c = cfg.config.value;
      final logo = c.logoUrl;
      final hasLogo = logo != null && logo.isNotEmpty;
      return hasLogo
          ? Image.network(
              logo,
              height: 42.h,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              semanticLabel: c.siteName,
              errorBuilder: (context, error, stack) =>
                  _markFallback(c.siteName),
            )
          : _markFallback(c.siteName);
    });
  }

  Widget _markFallback(String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 40.w,
          width: 40.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(Iconsax.briefcase, color: Colors.white, size: 20.sp),
        ),
        SizedBox(width: 10.w),
        Text(
          name,
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _formCard(ConfigService cfg) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.r),
      ),
      padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 24.h),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Masuk ke akun',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Gunakan email & kata sandi terdaftar',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5.sp),
            ),
            SizedBox(height: 24.h),
            _Label('Email'),
            TextField(
              controller: controller.emailC,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              decoration: const InputDecoration(
                hintText: 'nama@perusahaan.co.id',
                prefixIcon: Icon(Iconsax.sms, size: 20),
              ),
            ),
            SizedBox(height: 16.h),
            _Label('Kata Sandi'),
            Obx(
              () => TextField(
                controller: controller.passwordC,
                obscureText: controller.obscure.value,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) =>
                    controller.isLoading.value ? null : controller.submit(),
                decoration: InputDecoration(
                  hintText: 'Masukkan kata sandi',
                  prefixIcon: const Icon(Iconsax.lock, size: 20),
                  suffixIcon: IconButton(
                    tooltip: controller.obscure.value
                        ? 'Tampilkan sandi'
                        : 'Sembunyikan sandi',
                    icon: Icon(
                      controller.obscure.value
                          ? Iconsax.eye_slash
                          : Iconsax.eye,
                      size: 20,
                    ),
                    onPressed: controller.obscure.toggle,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            _rememberRow(),
            SizedBox(height: 22.h),
            _submitButton(),
            SizedBox(height: 18.h),
            _trustFooter(),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Widget _rememberRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Obx(
          () => GestureDetector(
            onTap: controller.rememberMe.toggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 22.w,
                  width: 22.w,
                  child: Checkbox(
                    value: controller.rememberMe.value,
                    onChanged: (_) => controller.rememberMe.toggle(),
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Ingat saya',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: controller.forgotPassword,
          style: TextButton.styleFrom(
            minimumSize: Size(44.w, 44.h),
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            foregroundColor: AppColors.primary,
          ),
          child: Text(
            'Lupa sandi?',
            style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _submitButton() {
    return Obx(
      () => SizedBox(
        height: 54.h,
        child: ElevatedButton(
          onPressed: controller.isLoading.value ? null : controller.submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
          child: controller.isLoading.value
              ? SizedBox(
                  height: 20.w,
                  width: 20.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Text(
                  'Masuk',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _trustFooter() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.shield_tick, size: 14.sp, color: AppColors.success),
          SizedBox(width: 6.w),
          Text(
            'Koneksi aman & terenkripsi',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
          fontSize: 13.5.sp,
        ),
      ),
    );
  }
}
