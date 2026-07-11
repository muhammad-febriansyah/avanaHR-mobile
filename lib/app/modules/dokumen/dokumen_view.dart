import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import 'dokumen_controller.dart';

class DokumenView extends GetView<DokumenController> {
  const DokumenView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Dokumen Pribadi',
      subtitle: 'Unggah & kelola dokumen',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Iconsax.document_upload, color: Colors.white),
        label: const Text('Unggah', style: TextStyle(color: Colors.white)),
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
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.document,
                      message: 'Belum ada dokumen.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 90.h),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, i) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    final d = controller.items[i];
                    return ContentCard(
                      child: Row(
                        children: [
                          const IconBubble(
                            Iconsax.document_text,
                            Color(0xFF9333EA),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                    fontSize: 13.5.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${d.type ?? 'Dokumen'} · ${_size(d.size)}',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5.sp,
                                  ),
                                ),
                              ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader('Unggah Dokumen'),
            SizedBox(height: 18.h),
            AppTextField(
              controller: nameC,
              label: 'Nama Dokumen',
              hint: 'cth. KTP',
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: typeC,
              label: 'Jenis (opsional)',
              hint: 'cth. identitas',
            ),
            SizedBox(height: 14.h),
            Obx(
              () => OutlinedButton.icon(
                onPressed: () async {
                  const typeGroup = XTypeGroup(
                    label: 'Dokumen',
                    extensions: ['pdf', 'jpg', 'jpeg', 'png'],
                  );
                  final picked = await openFile(
                    acceptedTypeGroups: [typeGroup],
                  );
                  if (picked != null) {
                    path.value = picked.path;
                    fileName.value = picked.name;
                  }
                },
                icon: const Icon(Iconsax.paperclip),
                label: Text(
                  fileName.value ?? 'Pilih file (PDF/JPG/PNG)',
                  overflow: TextOverflow.ellipsis,
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
                label: 'Unggah',
                loading: controller.submitting.value,
                onPressed: () async {
                  if (nameC.text.trim().isEmpty || path.value == null) {
                    AppToast.warning('Isi nama & pilih file.');
                    return;
                  }
                  final ok = await controller.upload(
                    name: nameC.text.trim(),
                    type: typeC.text.trim().isEmpty ? null : typeC.text.trim(),
                    filePath: path.value!,
                  );
                  if (ok) Get.back();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
