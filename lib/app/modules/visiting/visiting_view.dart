import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import 'visiting_controller.dart';

class VisitingView extends GetView<VisitingController> {
  const VisitingView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Visiting Pekerjaan',
      subtitle: 'Catat kunjungan kerja',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.location_add, color: Colors.white),
        label: const Text('Lapor', style: TextStyle(color: Colors.white)),
      ),
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          color: AppColors.primary,
          child: controller.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.location,
                      message: 'Belum ada kunjungan.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, i) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final v = controller.items[i];
                    return ContentCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const IconBubble(
                                Iconsax.location,
                                Color(0xFFE11D48),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.location,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy,
                                        fontSize: 13.5.sp,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      v.visitDate,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                    if (v.clientName != null &&
                                        v.clientName!.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 2.h),
                                        child: Text(
                                          'Klien: ${v.clientName}',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ),
                                    if (v.purpose != null &&
                                        v.purpose!.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 2.h),
                                        child: Text(
                                          v.purpose!,
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              StatusChip(v.status),
                            ],
                          ),
                          if (v.photoUrl != null)
                            Padding(
                              padding: EdgeInsets.only(top: 10.h),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.r),
                                child: Image.network(
                                  v.photoUrl!,
                                  height: 120.h,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        );
      }),
    );
  }

  void _openSheet(BuildContext context) {
    final date = Rxn<DateTime>(DateTime.now());
    final locC = TextEditingController();
    final clientC = TextEditingController();
    final purposeC = TextEditingController();
    final notesC = TextEditingController();
    final photoPath = RxnString();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 14.h,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24.h,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHeader('Lapor Kunjungan'),
              SizedBox(height: 18.h),
              Obx(
                () => AppDateField(
                  label: 'Tanggal Kunjungan',
                  value: date.value,
                  onPick: (d) => date.value = d,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                ),
              ),
              SizedBox(height: 14.h),
              AppTextField(
                controller: locC,
                label: 'Lokasi',
                hint: 'Nama tempat/alamat',
              ),
              SizedBox(height: 14.h),
              AppTextField(controller: clientC, label: 'Klien (opsional)'),
              SizedBox(height: 14.h),
              AppTextField(controller: purposeC, label: 'Tujuan (opsional)'),
              SizedBox(height: 14.h),
              AppTextField(
                controller: notesC,
                label: 'Catatan (opsional)',
                maxLines: 2,
              ),
              SizedBox(height: 14.h),
              Obx(
                () => OutlinedButton.icon(
                  onPressed: () async {
                    final img = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                      imageQuality: 70,
                    );
                    if (img != null) photoPath.value = img.path;
                  },
                  icon: const Icon(Iconsax.camera),
                  label: Text(
                    photoPath.value == null
                        ? 'Ambil foto (opsional)'
                        : 'Foto siap ✓',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    minimumSize: Size(double.infinity, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 22.h),
              Obx(
                () => AppSubmitButton(
                  label: 'Simpan',
                  loading: controller.submitting.value,
                  onPressed: () async {
                    if (date.value == null || locC.text.trim().isEmpty) {
                      AppToast.warning('Isi tanggal & lokasi.');
                      return;
                    }
                    final pos = await controller.currentPosition();
                    final ok = await controller.submit(
                      visitDate: fmt(date.value!),
                      location: locC.text.trim(),
                      clientName: clientC.text.trim().isEmpty
                          ? null
                          : clientC.text.trim(),
                      purpose: purposeC.text.trim().isEmpty
                          ? null
                          : purposeC.text.trim(),
                      notes: notesC.text.trim().isEmpty
                          ? null
                          : notesC.text.trim(),
                      latitude: pos?.latitude,
                      longitude: pos?.longitude,
                      photoPath: photoPath.value,
                    );
                    if (ok) Get.back();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
