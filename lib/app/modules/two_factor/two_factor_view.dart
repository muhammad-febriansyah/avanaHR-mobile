import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import 'two_factor_controller.dart';

class TwoFactorView extends GetView<TwoFactorController> {
  const TwoFactorView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [_header(), _sheet()],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: BoxDecoration(
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
              padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 70.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: Get.back,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
                    alignment: Alignment.centerLeft,
                    icon: Icon(
                      Iconsax.arrow_left_2,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                    tooltip: 'Kembali ke halaman masuk',
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Verifikasi dua langkah',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Kata sandi sudah benar. Satu langkah lagi untuk masuk.',
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

  Widget _sheet() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 0.5.sh),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 28.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Transform.translate(
              offset: Offset(0, -40.h),
              child: _formCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Obx(() {
        final recovery = controller.useRecoveryCode.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 54.w,
              width: 54.w,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(15.r),
              ),
              child: Icon(
                Iconsax.shield_tick,
                color: AppColors.primary,
                size: 28.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              recovery ? 'Kode pemulihan' : 'Kode autentikator',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              recovery
                  ? 'Masukkan salah satu kode cadangan yang Anda simpan saat mengaktifkan verifikasi dua langkah. Setiap kode hanya berlaku sekali.'
                  : 'Buka aplikasi autentikator Anda, lalu masukkan 6 digit yang sedang ditampilkan.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5.sp,
                height: 1.45,
              ),
            ),
            SizedBox(height: 24.h),
            TextField(
              controller: controller.codeC,
              autofocus: true,
              keyboardType: recovery
                  ? TextInputType.text
                  : TextInputType.number,
              inputFormatters: recovery
                  ? null
                  : [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
              textInputAction: TextInputAction.done,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              autofillHints: const [AutofillHints.oneTimeCode],
              onSubmitted: (_) =>
                  controller.isLoading.value ? null : controller.submit(),
              textAlign: recovery ? TextAlign.start : TextAlign.center,
              style: recovery
                  ? null
                  : TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10.w,
                      color: AppColors.navy,
                    ),
              decoration: InputDecoration(
                hintText: recovery ? 'xxxxxxxxxx-xxxxxxxxxx' : '000000',
                prefixIcon: Icon(
                  recovery ? Iconsax.key : Iconsax.password_check,
                  size: 20,
                ),
              ),
            ),
            SizedBox(height: 22.h),
            _submitButton(),
            SizedBox(height: 6.h),
            TextButton(
              onPressed: controller.isLoading.value
                  ? null
                  : controller.toggleMode,
              style: TextButton.styleFrom(
                minimumSize: Size(44.w, 44.h),
                foregroundColor: AppColors.primary,
              ),
              child: Text(
                recovery
                    ? 'Gunakan kode dari aplikasi autentikator'
                    : 'Tidak bisa akses aplikasi? Pakai kode pemulihan',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      }),
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
                  'Verifikasi',
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
}
