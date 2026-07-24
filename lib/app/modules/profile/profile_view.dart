import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/profile.dart';
import 'profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Profil Saya',
      subtitle: 'Akun & keamanan',
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
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            20.w,
            20.h,
            20.w,
            28.h + AppPage.bottomNavClearance(context),
          ),
          children: [
            _header(p),
            SizedBox(height: 16.h),
            _actions(p),
            SizedBox(height: 18.h),
            _section('Pekerjaan', Iconsax.briefcase, [
              InfoRow('Departemen', p.employment?.department),
              InfoRow('Posisi', p.employment?.position),
              InfoRow('Cabang', p.employment?.branch),
              InfoRow('Grade', p.employment?.jobGrade),
              InfoRow('Tipe', p.employment?.employmentType),
              InfoRow('Bergabung', formatTanggal(p.joinDate, fallback: '')),
            ]),
            SizedBox(height: 14.h),
            _section('Kontak', Iconsax.call, [
              InfoRow('Email', p.email),
              InfoRow('Telepon', p.phone),
              InfoRow('Alamat', p.address),
            ]),
            SizedBox(height: 14.h),
            _section('Data Pribadi', Iconsax.user, [
              InfoRow('NIK', p.nik),
              InfoRow('Jenis Kelamin', _genderLabel(p.gender)),
              InfoRow('Tempat Lahir', p.birthPlace),
              InfoRow(
                'Tanggal Lahir',
                formatTanggal(p.birthDate, fallback: ''),
              ),
              InfoRow('Agama', p.religion),
              InfoRow('Status Pernikahan', p.maritalStatus),
            ]),
            SizedBox(height: 20.h),
            _logoutButton(),
          ],
        );
      }),
    );
  }

  // ---- Header ---------------------------------------------------------------

  Widget _header(Profile p) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Stack(
        children: [
          // Same diagonal mesh as the page header, clipped to the card radius.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.r),
              child: CustomPaint(painter: const BrandMeshPainter()),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
              child: Column(
                children: [
                  _editableAvatar(p),
                  SizedBox(height: 12.h),
                  Text(
                    p.fullName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    _subtitleOf(p),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      _headerChip(Iconsax.card, p.employeeNo),
                      _headerChip(Iconsax.tick_circle, _statusLabel(p.status)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: Colors.white),
          SizedBox(width: 5.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5.sp,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Circular avatar with a camera badge; tap to pick + upload a new photo.
  /// Shows a spinner overlay while the upload is in flight.
  Widget _editableAvatar(Profile p) {
    return GestureDetector(
      onTap: () => _pickPhoto(Get.context!),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            child: CircleAvatar(
              radius: 40.r,
              backgroundColor: Colors.white,
              backgroundImage: p.photoUrl != null
                  ? NetworkImage(p.photoUrl!)
                  : null,
              child: p.photoUrl == null
                  ? Text(
                      p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 30.sp,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
          ),
          Positioned.fill(
            child: Obx(
              () => controller.isUploadingPhoto.value
                  ? Container(
                      margin: EdgeInsets.all(3.w),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black38,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Icon(
                Iconsax.camera,
                size: 13.sp,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickPhoto(BuildContext context) {
    showAppSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          _photoSourceTile(
            context,
            Iconsax.camera,
            'Kamera',
            ImageSource.camera,
          ),
          _photoSourceTile(
            context,
            Iconsax.gallery,
            'Galeri',
            ImageSource.gallery,
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _photoSourceTile(
    BuildContext ctx,
    IconData icon,
    String text,
    ImageSource source,
  ) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20.sp),
      ),
      title: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
          fontSize: 14.sp,
        ),
      ),
      onTap: () async {
        Navigator.pop(ctx);
        final img = await ImagePicker().pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1024,
        );
        if (img != null) await controller.updatePhoto(img.path);
      },
    );
  }

  // ---- Action buttons -------------------------------------------------------

  Widget _actions(Profile p) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            'Edit Profil',
            Iconsax.edit,
            () => _openEditSheet(p),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _actionButton(
            'Ubah Sandi',
            Iconsax.lock_1,
            _openPasswordSheet,
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 13.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17.sp, color: AppColors.primary),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Sections -------------------------------------------------------------

  Widget _section(String title, IconData icon, List<Widget> rows) {
    return ContentCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16.sp, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  fontSize: 15.sp,
                ),
              ),
            ],
          ),
          Divider(color: AppColors.border, height: 22.h),
          ...rows,
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return InkWell(
      onTap: _confirmLogout,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.logout, size: 17.sp, color: AppColors.destructive),
            SizedBox(width: 8.w),
            Text(
              'Keluar',
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Sheets ---------------------------------------------------------------

  void _openEditSheet(Profile p) {
    final phone = TextEditingController(text: p.phone ?? '');
    final address = TextEditingController(text: p.address ?? '');
    final email = TextEditingController(text: p.email ?? '');
    final nik = TextEditingController(text: p.nik ?? '');
    final birthPlace = TextEditingController(text: p.birthPlace ?? '');
    final religion = TextEditingController(text: p.religion ?? '');
    final marital = TextEditingController(text: p.maritalStatus ?? '');

    String? gender = _normalizeGender(p.gender);
    DateTime? birthDate = p.birthDate != null
        ? DateTime.tryParse(p.birthDate!)
        : null;

    _sheet(
      title: 'Edit Profil',
      subtitle: 'Perbarui data pribadi Anda.',
      children: [
        AppTextField(
          controller: phone,
          label: 'Telepon',
          hint: '0812xxxx',
          icon: Iconsax.call,
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: 14.h),
        AppTextField(
          controller: email,
          label: 'Email',
          hint: 'nama@email.com',
          icon: Iconsax.sms,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 14.h),
        AppTextField(
          controller: nik,
          label: 'NIK',
          hint: '16 digit',
          icon: Iconsax.card,
          keyboardType: TextInputType.number,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
          ],
        ),
        SizedBox(height: 14.h),
        // Gender + birth date rebuild locally on change; the rest are plain
        // text controllers.
        StatefulBuilder(
          builder: (context, setSheet) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppDropdownField<String>(
                label: 'Jenis Kelamin',
                value: gender,
                hint: 'Pilih jenis kelamin',
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Laki-laki')),
                  DropdownMenuItem(value: 'female', child: Text('Perempuan')),
                  DropdownMenuItem(
                    value: 'unspecified',
                    child: Text('Tidak disebutkan'),
                  ),
                ],
                onChanged: (v) => setSheet(() => gender = v),
              ),
              SizedBox(height: 14.h),
              AppDateField(
                label: 'Tanggal Lahir',
                value: birthDate,
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
                onPick: (d) => setSheet(() => birthDate = d),
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        AppTextField(
          controller: birthPlace,
          label: 'Tempat Lahir',
          hint: 'Kota kelahiran',
          icon: Iconsax.location,
        ),
        SizedBox(height: 14.h),
        AppTextField(
          controller: religion,
          label: 'Agama',
          hint: 'Agama',
          icon: Iconsax.book,
        ),
        SizedBox(height: 14.h),
        AppTextField(
          controller: marital,
          label: 'Status Pernikahan',
          hint: 'Belum menikah / Menikah',
          icon: Iconsax.people,
        ),
        SizedBox(height: 14.h),
        AppTextField(
          controller: address,
          label: 'Alamat',
          hint: 'Alamat tempat tinggal',
          icon: Iconsax.house,
          maxLines: 3,
        ),
        SizedBox(height: 20.h),
        Obx(
          () => AppSubmitButton(
            loading: controller.isSaving.value,
            icon: Iconsax.save_2,
            label: 'Simpan',
            onPressed: () async {
              final ok = await controller.updateProfile(
                phone: phone.text.trim(),
                address: address.text.trim(),
                email: email.text.trim(),
                nik: nik.text.trim(),
                gender: gender ?? '',
                birthPlace: birthPlace.text.trim(),
                birthDate: birthDate != null
                    ? birthDate!.toIso8601String().split('T').first
                    : '',
                religion: religion.text.trim(),
                maritalStatus: marital.text.trim(),
              );
              if (ok) Get.back();
            },
          ),
        ),
      ],
    );
  }

  /// Only the three server-accepted enum values are safe to seed into the
  /// dropdown; anything else would throw, so fall back to null (unselected).
  String? _normalizeGender(String? g) =>
      const {'male', 'female', 'unspecified'}.contains(g) ? g : null;

  void _openPasswordSheet() {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();

    _sheet(
      title: 'Ubah Kata Sandi',
      subtitle: 'Minimal 8 karakter. Anda tetap masuk setelah diganti.',
      children: [
        AppTextField(
          controller: current,
          label: 'Sandi Saat Ini',
          hint: 'Masukkan sandi saat ini',
          icon: Iconsax.lock,
          obscure: true,
        ),
        SizedBox(height: 14.h),
        AppTextField(
          controller: next,
          label: 'Sandi Baru',
          hint: 'Minimal 8 karakter',
          icon: Iconsax.lock_1,
          obscure: true,
        ),
        SizedBox(height: 14.h),
        AppTextField(
          controller: confirm,
          label: 'Ulangi Sandi Baru',
          hint: 'Ketik ulang sandi baru',
          icon: Iconsax.lock_1,
          obscure: true,
        ),
        SizedBox(height: 20.h),
        Obx(
          () => AppSubmitButton(
            loading: controller.isSaving.value,
            icon: Iconsax.shield_tick,
            label: 'Perbarui Sandi',
            onPressed: () async {
              final ok = await controller.changePassword(
                current: current.text,
                password: next.text,
                confirm: confirm.text,
              );
              if (ok) Get.back();
            },
          ),
        ),
      ],
    );
  }

  void _sheet({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    showAppSheet(
      Get.context!,
      scrollable: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  fontSize: 17.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5.sp),
              ),
              SizedBox(height: 18.h),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: Text(
          'Keluar akun?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
            color: AppColors.navy,
          ),
        ),
        content: Text(
          'Anda harus masuk kembali untuk mengakses aplikasi.',
          style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.logout();
            },
            child: Text(
              'Keluar',
              style: TextStyle(
                color: AppColors.destructive,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Helpers --------------------------------------------------------------

  String _subtitleOf(Profile p) {
    final parts = [
      p.employment?.position,
      p.employment?.department,
    ].where((e) => e != null && e.isNotEmpty).toList();
    return parts.isEmpty ? 'Karyawan' : parts.join(' · ');
  }

  String? _genderLabel(String? g) {
    switch (g) {
      case 'male':
        return 'Laki-laki';
      case 'female':
        return 'Perempuan';
      case 'unspecified':
        return 'Tidak disebutkan';
      default:
        return null;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'inactive':
        return 'Nonaktif';
      default:
        return status.isEmpty ? '-' : status;
    }
  }
}
