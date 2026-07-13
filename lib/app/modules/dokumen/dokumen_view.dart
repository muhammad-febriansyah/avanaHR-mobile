import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
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
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    SizedBox(height: 80.h),
                    const EmptyState(
                      icon: Iconsax.document,
                      message: 'Belum ada dokumen.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
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

    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
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
              required: true,
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: typeC,
              label: 'Jenis (opsional)',
              hint: 'cth. identitas',
            ),
            SizedBox(height: 14.h),
            Text.rich(
              TextSpan(
                text: 'Berkas',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                  fontSize: 12.5.sp,
                ),
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: AppColors.destructive,
                      fontSize: 12.5.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 6.h),
            Obx(() {
              final fname = fileName.value;
              if (fname == null) {
                return InkWell(
                  borderRadius: BorderRadius.circular(14.r),
                  onTap: () async {
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
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 22.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Iconsax.document_upload,
                          size: 26.sp,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Pilih File',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.sp,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'PDF, JPG, atau PNG',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final isPdf = fname.toLowerCase().endsWith('.pdf');
              return Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color:
                            (isPdf ? AppColors.destructive : AppColors.primary)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        isPdf ? Iconsax.document_text : Iconsax.gallery,
                        size: 18.sp,
                        color: isPdf
                            ? AppColors.destructive
                            : AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        fname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        path.value = null;
                        fileName.value = null;
                      },
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Icon(
                          Iconsax.close_circle,
                          size: 20.sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
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
