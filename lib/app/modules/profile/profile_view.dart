import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import 'profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      appBar: AppBar(title: const Text('Profil Saya')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final p = controller.profile.value;
        if (p == null) {
          return const Center(child: Text('Gagal memuat profil.'));
        }
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsets.all(20.w),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44.r,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
                        child: p.photoUrl == null
                            ? Text(
                                p.fullName.isNotEmpty ? p.fullName[0] : '?',
                                style: TextStyle(fontSize: 32.sp, color: AppColors.primary, fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      SizedBox(height: 12.h),
                      Text(p.fullName, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: AppColors.navy)),
                      Text(p.employeeNo, style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp)),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(p.status, style: TextStyle(color: AppColors.success, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                _section('Pekerjaan', [
                  _row('Departemen', p.employment?.department),
                  _row('Posisi', p.employment?.position),
                  _row('Grade', p.employment?.jobGrade),
                  _row('Tipe', p.employment?.employmentType),
                  _row('Bergabung', p.joinDate),
                ]),
                SizedBox(height: 16.h),
                _section('Kontak', [
                  _row('Email', p.email),
                  _row('Telepon', p.phone),
                  _row('Alamat', p.address),
                ]),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 15.sp)),
          SizedBox(height: 8.h),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110.w, child: Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp))),
          Expanded(child: Text(value ?? '-', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w500, fontSize: 13.sp))),
        ],
      ),
    );
  }
}
