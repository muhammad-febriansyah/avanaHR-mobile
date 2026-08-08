import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/services/auth_service.dart';
import '../../routes/app_pages.dart';

/// Full-screen stop for an account that has no employee record behind it.
///
/// Every screen in this app is employee self-service, so such an account can
/// use none of it. It used to land on the dashboard anyway: a dismissible red
/// toast, empty counters, and a WhatsApp screenshot asking why the app is
/// "blank". This screen replaces that guesswork with the actual instruction —
/// ask HR to link the account — and re-checks on demand so the fix takes
/// effect without reinstalling or signing back in.
class AccountUnlinkedView extends StatefulWidget {
  const AccountUnlinkedView({super.key});

  @override
  State<AccountUnlinkedView> createState() => _AccountUnlinkedViewState();
}

class _AccountUnlinkedViewState extends State<AccountUnlinkedView> {
  final AuthService _auth = Get.find();
  bool _checking = false;

  /// Re-pull /auth/me; when HR has linked the employee in the meantime, the
  /// [Obx] in [MainView] swaps this screen out for the real shell by itself.
  Future<void> _recheck() async {
    setState(() => _checking = true);
    await _auth.loadMe();
    if (!mounted) return;
    setState(() => _checking = false);

    if (_auth.user.value?.employee == null) {
      AppToast.info(
        'Akun masih belum tertaut. Hubungi HR perusahaan kamu, lalu coba lagi.',
      );
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    Get.offAllNamed(Routes.LOGIN);
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.user.value?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.muted,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: EdgeInsets.all(22.w),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.user_remove,
                  size: 40.sp,
                  color: AppColors.destructive,
                ),
              ),
              SizedBox(height: 22.h),
              Text(
                'Akun Belum Terhubung\nke Data Karyawan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  letterSpacing: -0.3,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                email.isEmpty
                    ? 'Akun ini belum ditautkan ke data karyawan, jadi absensi dan menu karyawan belum bisa dipakai.'
                    : 'Akun $email belum ditautkan ke data karyawan, jadi absensi dan menu karyawan belum bisa dipakai.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 18.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Iconsax.message_question,
                      size: 20.sp,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'Minta HR atau admin perusahaan menautkan akun ini ke '
                        'data karyawan kamu (menu Pengguna di web admin). '
                        'Setelah itu tekan "Periksa Ulang".',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: AppColors.navy,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton.icon(
                  onPressed: _checking ? null : _recheck,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: _checking
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Iconsax.refresh, size: 18.sp),
                  label: Text(
                    'Periksa Ulang',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: TextButton.icon(
                  onPressed: _logout,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: Icon(Iconsax.logout, size: 18.sp),
                  label: Text(
                    'Keluar',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
            ],
          ),
        ),
      ),
    );
  }
}
