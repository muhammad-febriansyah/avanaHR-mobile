import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/ui.dart';
import 'dokumen_controller.dart';

class DokumenView extends GetView<DokumenController> {
  const DokumenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.muted,
      appBar: AppBar(title: const Text('Dokumen Pribadi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.document_upload, color: Colors.white),
        label: const Text('Unggah', style: TextStyle(color: Colors.white)),
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const Loading();
        if (controller.items.isEmpty) {
          return const EmptyState(icon: Iconsax.document, message: 'Belum ada dokumen. Unggah KTP, ijazah, dll.');
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView.separated(
            padding: EdgeInsets.all(20.w),
            itemCount: controller.items.length,
            separatorBuilder: (_, i) => SizedBox(height: 10.h),
            itemBuilder: (_, i) {
              final d = controller.items[i];
              return Container(
                padding: EdgeInsets.all(14.w),
                decoration: softCard(radius: 14),
                child: Row(children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10.r)),
                    child: Icon(Iconsax.document_text, size: 20.sp, color: AppColors.primary),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 13.5.sp)),
                      Text('${d.type ?? 'Dokumen'} · ${_size(d.size)}', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5.sp)),
                    ]),
                  ),
                ]),
              );
            },
          ),
        );
      }),
    );
  }

  String _size(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  void _openSheet(BuildContext context) {
    final nameC = TextEditingController();
    final typeC = TextEditingController();
    final path = RxnString();
    final fileName = RxnString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Unggah Dokumen', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 16.sp)),
          SizedBox(height: 16.h),
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama dokumen', hintText: 'cth. KTP', border: OutlineInputBorder())),
          SizedBox(height: 12.h),
          TextField(controller: typeC, decoration: const InputDecoration(labelText: 'Jenis (opsional)', hintText: 'cth. identitas', border: OutlineInputBorder())),
          SizedBox(height: 12.h),
          Obx(() => OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
                  final picked = result?.files.single;
                  if (picked?.path != null) {
                    path.value = picked!.path;
                    fileName.value = picked.name;
                  }
                },
                icon: const Icon(Iconsax.paperclip),
                label: Text(fileName.value ?? 'Pilih file (PDF/JPG/PNG)', overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h), minimumSize: Size(double.infinity, 0)),
              )),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton(
                  onPressed: controller.submitting.value
                      ? null
                      : () async {
                          if (nameC.text.trim().isEmpty || path.value == null) {
                            AppToast.error('Isi nama & pilih file.');
                            return;
                          }
                          final ok = await controller.upload(name: nameC.text.trim(), type: typeC.text.trim().isEmpty ? null : typeC.text.trim(), filePath: path.value!);
                          if (ok) Get.back();
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: EdgeInsets.symmetric(vertical: 14.h)),
                  child: controller.submitting.value
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Unggah', style: TextStyle(color: Colors.white)),
                )),
          ),
        ]),
      ),
    );
  }
}
