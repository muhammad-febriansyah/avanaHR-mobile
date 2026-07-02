import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/ui.dart';
import 'visiting_controller.dart';

class VisitingView extends GetView<VisitingController> {
  const VisitingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      appBar: AppBar(title: const Text('Visiting Pekerjaan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.location_add, color: Colors.white),
        label: const Text('Lapor', style: TextStyle(color: Colors.white)),
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const Loading();
        if (controller.items.isEmpty) {
          return const EmptyState(icon: Iconsax.location, message: 'Belum ada laporan kunjungan.');
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            padding: EdgeInsets.all(20.w),
            itemCount: controller.items.length,
            separatorBuilder: (_, i) => SizedBox(height: 10.h),
            itemBuilder: (_, i) {
              final v = controller.items[i];
              return Container(
                padding: EdgeInsets.all(14.w),
                decoration: softCard(radius: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('${v.location} · ${v.visitDate}', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 13.5.sp)),
                    ),
                    StatusChip(v.status),
                  ]),
                  if (v.clientName != null && v.clientName!.isNotEmpty)
                    Padding(padding: EdgeInsets.only(top: 3.h), child: Text('Klien: ${v.clientName}', style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp))),
                  if (v.purpose != null && v.purpose!.isNotEmpty)
                    Padding(padding: EdgeInsets.only(top: 2.h), child: Text(v.purpose!, style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp))),
                  if (v.photoUrl != null)
                    Padding(
                      padding: EdgeInsets.only(top: 10.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.r),
                        child: Image.network(v.photoUrl!, height: 120.h, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ),
                    ),
                ]),
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
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lapor Kunjungan', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 16.sp)),
            SizedBox(height: 16.h),
            Obx(() => InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(context: ctx, initialDate: date.value ?? now, firstDate: now.subtract(const Duration(days: 30)), lastDate: now);
                    if (d != null) date.value = d;
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Tanggal', border: OutlineInputBorder()),
                    child: Text(date.value == null ? 'Pilih' : fmt(date.value!), style: TextStyle(fontSize: 13.sp, color: AppColors.navy)),
                  ),
                )),
            SizedBox(height: 12.h),
            TextField(controller: locC, decoration: const InputDecoration(labelText: 'Lokasi / alamat', hintText: 'cth. Bandung', border: OutlineInputBorder())),
            SizedBox(height: 12.h),
            TextField(controller: clientC, decoration: const InputDecoration(labelText: 'Klien (opsional)', hintText: 'cth. PT ABC', border: OutlineInputBorder())),
            SizedBox(height: 12.h),
            TextField(controller: purposeC, decoration: const InputDecoration(labelText: 'Tujuan (opsional)', hintText: 'cth. Meeting', border: OutlineInputBorder())),
            SizedBox(height: 12.h),
            TextField(controller: notesC, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()), maxLines: 2),
            SizedBox(height: 12.h),
            Obx(() => OutlinedButton.icon(
                  onPressed: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
                    if (img != null) photoPath.value = img.path;
                  },
                  icon: const Icon(Iconsax.camera),
                  label: Text(photoPath.value == null ? 'Ambil foto (opsional)' : 'Foto siap ✓'),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h), minimumSize: Size(double.infinity, 0)),
                )),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              child: Obx(() => ElevatedButton(
                    onPressed: controller.submitting.value
                        ? null
                        : () async {
                            if (date.value == null || locC.text.trim().isEmpty) {
                              AppToast.error('Isi tanggal & lokasi.');
                              return;
                            }
                            final pos = await controller.currentPosition();
                            final ok = await controller.submit(
                              visitDate: fmt(date.value!),
                              location: locC.text.trim(),
                              clientName: clientC.text.trim().isEmpty ? null : clientC.text.trim(),
                              purpose: purposeC.text.trim().isEmpty ? null : purposeC.text.trim(),
                              notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                              latitude: pos?.latitude,
                              longitude: pos?.longitude,
                              photoPath: photoPath.value,
                            );
                            if (ok) Get.back();
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 14.h)),
                    child: controller.submitting.value
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan', style: TextStyle(color: Colors.white)),
                  )),
            ),
          ]),
        ),
      ),
    );
  }
}
