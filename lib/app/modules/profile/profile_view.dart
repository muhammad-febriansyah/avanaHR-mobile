import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/ui.dart';
import 'profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Profil Saya',
      subtitle: 'Data karyawan',
      showBack: false,
      onRefresh: controller.load,
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }
        final p = controller.profile.value;
        if (p == null) {
          return const Center(child: Text('Gagal memuat profil.'));
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20.w),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44.r,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage: p.photoUrl != null
                        ? NetworkImage(p.photoUrl!)
                        : null,
                    child: p.photoUrl == null
                        ? Text(
                            p.fullName.isNotEmpty ? p.fullName[0] : '?',
                            style: TextStyle(
                              fontSize: 32.sp,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    p.fullName,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    p.employeeNo,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      p.status,
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            _section('Pekerjaan', [
              InfoRow('Departemen', p.employment?.department),
              InfoRow('Posisi', p.employment?.position),
              InfoRow('Grade', p.employment?.jobGrade),
              InfoRow('Tipe', p.employment?.employmentType),
              InfoRow('Bergabung', p.joinDate),
            ]),
            SizedBox(height: 16.h),
            _section('Kontak', [
              InfoRow('Email', p.email),
              InfoRow('Telepon', p.phone),
              InfoRow('Alamat', p.address),
            ]),
          ],
        );
      }),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              fontSize: 15.sp,
            ),
          ),
          SizedBox(height: 8.h),
          ...rows,
        ],
      ),
    );
  }
}
