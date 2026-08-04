import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/form_fields.dart';
import 'two_factor_setup_controller.dart';

class TwoFactorSetupView extends GetView<TwoFactorSetupController> {
  const TwoFactorSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Verifikasi Dua Langkah',
      subtitle: 'Lapisan kedua setelah kata sandi',
      onRefresh: controller.load,
      child: Obx(() {
        if (controller.isLoading.value) {
          return _centered(const CircularProgressIndicator());
        }

        if (controller.loadError.value != null) {
          return _centered(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.warning_2,
                  size: 40.sp,
                  color: AppColors.textMuted,
                ),
                SizedBox(height: 12.h),
                Text(
                  controller.loadError.value!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                OutlinedButton(
                  onPressed: controller.load,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          );
        }

        final status = controller.status.value;

        return ListView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
          children: [
            if (status.enabled)
              ..._enabled()
            else if (status.confirming)
              ..._confirming()
            else
              ..._off(),
          ],
        );
      }),
    );
  }

  Widget _centered(Widget child) =>
      ListView(children: [SizedBox(height: 0.3.sh), Center(child: child)]);

  // ---- Off ------------------------------------------------------------------

  List<Widget> _off() {
    return [
      _card(
        icon: Iconsax.shield_cross,
        tone: AppColors.textMuted,
        title: 'Belum aktif',
        body:
            'Saat ini akun hanya dijaga kata sandi. Dengan verifikasi dua '
            'langkah, masuk juga butuh kode 6 digit dari aplikasi '
            'autentikator di HP Anda.',
      ),
      SizedBox(height: 20.h),
      _primaryButton(
        icon: Iconsax.shield_tick,
        label: 'Aktifkan',
        onPressed: () => _askPassword(
          title: 'Aktifkan Verifikasi Dua Langkah',
          subtitle: 'Masukkan kata sandi Anda untuk melanjutkan.',
          action: 'Lanjutkan',
          onSubmit: controller.enable,
        ),
      ),
    ];
  }

  // ---- Half enrolled --------------------------------------------------------

  List<Widget> _confirming() {
    final status = controller.status.value;
    final codeC = TextEditingController();

    return [
      _card(
        icon: Iconsax.scan_barcode,
        tone: AppColors.primary,
        title: 'Tinggal satu langkah',
        body:
            'Pindai kode di bawah dengan aplikasi autentikator '
            '(Google Authenticator, Authy, dan sejenisnya), lalu masukkan '
            '6 digit yang muncul.',
      ),
      SizedBox(height: 20.h),
      if (status.qrSvg != null)
        Center(
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.border),
            ),
            child: SvgPicture.string(
              status.qrSvg!,
              width: 180.w,
              height: 180.w,
            ),
          ),
        ),
      SizedBox(height: 18.h),
      if (status.setupUrl != null)
        OutlinedButton.icon(
          onPressed: () => _openAuthenticator(status.setupUrl!),
          icon: Icon(Iconsax.export_3, size: 17.sp),
          label: const Text('Buka di aplikasi autentikator'),
        ),
      SizedBox(height: 14.h),
      if (status.setupKey != null) _setupKey(status.setupKey!),
      SizedBox(height: 22.h),
      AppTextField(
        controller: codeC,
        label: 'Kode 6 Digit',
        hint: '000000',
        icon: Iconsax.password_check,
        keyboardType: TextInputType.number,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
      ),
      SizedBox(height: 18.h),
      Obx(
        () => AppSubmitButton(
          loading: controller.isWorking.value,
          icon: Iconsax.shield_tick,
          label: 'Konfirmasi & Aktifkan',
          onPressed: () {
            final code = codeC.text.trim();
            if (code.length < 6) {
              AppToast.warning('Masukkan 6 digit kode.');
              return;
            }
            controller.confirm(code);
          },
        ),
      ),
      SizedBox(height: 10.h),
      TextButton(
        onPressed: () => _askPassword(
          title: 'Batalkan Aktivasi',
          subtitle: 'Kode yang sudah dipindai akan dibuang.',
          action: 'Batalkan',
          danger: true,
          onSubmit: controller.cancelSetup,
        ),
        child: const Text('Batalkan'),
      ),
    ];
  }

  Widget _setupKey(String key) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tidak bisa memindai? Masukkan kunci ini manual:',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  key,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.sp,
                    letterSpacing: 1.1,
                    color: AppColors.navy,
                  ),
                ),
              ),
              IconButton(
                onPressed: controller.copySetupKey,
                tooltip: 'Salin kunci',
                icon: Icon(Iconsax.copy, size: 18.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- On -------------------------------------------------------------------

  List<Widget> _enabled() {
    final codes = controller.status.value.recoveryCodes;

    return [
      _card(
        icon: Iconsax.shield_tick,
        tone: AppColors.success,
        title: 'Aktif',
        body:
            'Setiap kali masuk, Anda akan diminta kode dari aplikasi '
            'autentikator setelah kata sandi.',
      ),
      SizedBox(height: 22.h),
      if (codes.isNotEmpty) _recoveryCodes(codes),
      SizedBox(height: 18.h),
      OutlinedButton.icon(
        onPressed: () => _askPassword(
          title: 'Buat Ulang Kode Pemulihan',
          subtitle: 'Kode lama langsung hangus setelah ini.',
          action: 'Buat Ulang',
          onSubmit: controller.regenerateRecoveryCodes,
        ),
        icon: Icon(Iconsax.refresh, size: 17.sp),
        label: const Text('Buat ulang kode pemulihan'),
      ),
      SizedBox(height: 10.h),
      TextButton.icon(
        onPressed: () => _askPassword(
          title: 'Matikan Verifikasi Dua Langkah',
          subtitle:
              'Akun kembali dijaga kata sandi saja. Kode pemulihan ikut hangus.',
          action: 'Matikan',
          danger: true,
          onSubmit: controller.disable,
        ),
        icon: Icon(Iconsax.shield_cross, size: 17.sp, color: AppColors.danger),
        label: Text(
          'Matikan',
          style: TextStyle(color: AppColors.danger),
        ),
      ),
    ];
  }

  Widget _recoveryCodes(List<String> codes) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kode Pemulihan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                    color: AppColors.navy,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: controller.copyRecoveryCodes,
                icon: Icon(Iconsax.copy, size: 16.sp),
                label: const Text('Salin'),
              ),
            ],
          ),
          Text(
            'Simpan di tempat aman. Tiap kode hanya bisa dipakai sekali, untuk '
            'masuk saat aplikasi autentikator tidak bisa diakses.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.sp,
              height: 1.45,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 8.h,
            children: codes
                .map(
                  (code) => Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5.sp,
                      color: AppColors.navy,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ---- Shared ---------------------------------------------------------------

  Widget _card({
    required IconData icon,
    required Color tone,
    required String title,
    required String body,
  }) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22.sp, color: tone),
              SizedBox(width: 10.w),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.sp,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            body,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Obx(
      () => AppSubmitButton(
        loading: controller.isWorking.value,
        icon: icon,
        label: label,
        onPressed: onPressed,
      ),
    );
  }

  Future<void> _openAuthenticator(String url) async {
    final uri = Uri.parse(url);
    // No authenticator installed means nothing can handle otpauth://; say so
    // rather than let the tap do nothing.
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      AppToast.info(
        'Tidak ada aplikasi autentikator terpasang. Pindai QR atau salin '
        'kuncinya.',
      );
    }
  }

  /// The password gate every state change goes through. A phone found unlocked
  /// is exactly what the second factor is there to survive, so turning it off
  /// must cost more than a tap.
  void _askPassword({
    required String title,
    required String subtitle,
    required String action,
    required Future<bool> Function(String password) onSubmit,
    bool danger = false,
  }) {
    final passwordC = TextEditingController();

    showAppSheet(
      Get.context!,
      scrollable: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5.sp),
            ),
            SizedBox(height: 18.h),
            AppTextField(
              controller: passwordC,
              label: 'Kata Sandi',
              hint: 'Masukkan kata sandi Anda',
              icon: Iconsax.lock,
              obscure: true,
            ),
            SizedBox(height: 20.h),
            Obx(
              () => AppSubmitButton(
                loading: controller.isWorking.value,
                icon: danger ? Iconsax.shield_cross : Iconsax.shield_tick,
                label: action,
                onPressed: () async {
                  if (passwordC.text.isEmpty) {
                    AppToast.warning('Kata sandi wajib diisi.');
                    return;
                  }

                  if (await onSubmit(passwordC.text)) {
                    Get.back();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
