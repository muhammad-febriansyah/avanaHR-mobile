import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
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
                  separatorBuilder: (_, i) => SizedBox(height: 12.h),
                  itemBuilder: (_, i) => _DocCard(
                    doc: controller.items[i],
                    onTap: () => _openDetail(context, controller.items[i]),
                  ),
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

  /// Full-screen-ish detail sheet: a large preview plus the document metadata.
  void _openDetail(BuildContext context, DocumentItem doc) {
    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader('Detail Dokumen'),
            SizedBox(height: 16.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: doc.isImage && doc.url != null
                  ? CachedNetworkImage(
                      imageUrl: doc.url!,
                      width: double.infinity,
                      height: 240.h,
                      fit: BoxFit.cover,
                      memCacheHeight: 720,
                      placeholder: (_, _) => Container(
                        height: 240.h,
                        color: AppColors.muted,
                      ),
                      errorWidget: (_, _, _) => _previewFallback(
                        Iconsax.gallery_slash,
                        'Gambar gagal dimuat',
                      ),
                    )
                  : _previewFallback(
                      Iconsax.document_text,
                      'Berkas ${(doc.type ?? 'dokumen').toUpperCase()}',
                    ),
            ),
            SizedBox(height: 18.h),
            Text(
              doc.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                fontSize: 15.sp,
              ),
            ),
            SizedBox(height: 14.h),
            _metaRow('Jenis', doc.type ?? 'Dokumen'),
            _metaRow('Ukuran', _size(doc.size)),
            if (doc.uploadedAt != null && doc.uploadedAt!.isNotEmpty)
              _metaRow('Diunggah', fmtDate(doc.uploadedAt)),
            if (doc.url != null) ...[
              SizedBox(height: 8.h),
              AppSubmitButton(
                label: 'Buka / Unduh',
                loading: false,
                onPressed: () => _openFile(doc),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Hand the document URL to the OS — opens it in the browser / a viewer,
  /// which is also where the user downloads it from. Tries an external app
  /// first, then falls back to an in-app tab so a missing default browser
  /// doesn't dead-end the user.
  Future<void> _openFile(DocumentItem doc) async {
    final raw = doc.url;
    if (raw == null || raw.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      AppToast.error('URL dokumen tidak valid.');
      return;
    }
    for (final mode in const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        if (await launchUrl(uri, mode: mode)) {
          return;
        }
      } catch (_) {
        // Try the next launch mode.
      }
    }
    AppToast.error('Tidak ada aplikasi untuk membuka dokumen.');
  }

  Widget _previewFallback(IconData icon, String label) {
    return Container(
      width: double.infinity,
      height: 180.h,
      color: AppColors.muted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44.sp, color: AppColors.textMuted),
          SizedBox(height: 10.h),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
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
              icon: Iconsax.document_text,
              required: true,
            ),
            SizedBox(height: 14.h),
            AppTextField(
              controller: typeC,
              label: 'Jenis (opsional)',
              hint: 'cth. identitas',
              icon: Iconsax.category,
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
                return _dropzone(path, fileName);
              }
              final lower = fname.toLowerCase();
              final isImage =
                  lower.endsWith('.jpg') ||
                  lower.endsWith('.jpeg') ||
                  lower.endsWith('.png') ||
                  lower.endsWith('.webp');

              if (isImage && path.value != null) {
                return _imagePreview(fname, path, fileName);
              }
              return _filePill(fname, path, fileName);
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

  /// The empty "pilih file" tap target.
  Widget _dropzone(RxnString path, RxnString fileName) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: () async {
        const typeGroup = XTypeGroup(
          label: 'Dokumen',
          extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        );
        final picked = await openFile(acceptedTypeGroups: [typeGroup]);
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
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5.sp),
            ),
          ],
        ),
      ),
    );
  }

  /// Thumbnail preview of a picked image, straight from the local file.
  Widget _imagePreview(String fname, RxnString path, RxnString fileName) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: Stack(
        children: [
          Image.file(
            File(path.value!),
            width: double.infinity,
            height: 180.h,
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 8.h,
            right: 8.w,
            child: GestureDetector(
              onTap: () {
                path.value = null;
                fileName.value = null;
              },
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 16.sp, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Text(
                fname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact row for a non-image (PDF) pick.
  Widget _filePill(String fname, RxnString path, RxnString fileName) {
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
              color: AppColors.destructive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Iconsax.document_text,
              size: 18.sp,
              color: AppColors.destructive,
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
  }
}

/// A document list row: image docs show a real thumbnail, others a doc icon.
/// The whole card is tappable to open the detail sheet.
class _DocCard extends StatelessWidget {
  final DocumentItem doc;
  final VoidCallback onTap;

  const _DocCard({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      onTap: onTap,
      child: Row(
        children: [
          _thumb(),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    fontSize: 13.5.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${doc.type ?? 'Dokumen'} · ${_size(doc.size)}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Icon(
            Iconsax.arrow_right_3,
            size: 18.sp,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _thumb() {
    const purple = Color(0xFF9333EA);
    if (doc.isImage && doc.url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: CachedNetworkImage(
          imageUrl: doc.url!,
          width: 46.w,
          height: 46.w,
          fit: BoxFit.cover,
          memCacheHeight: 138,
          placeholder: (_, _) => Container(
            width: 46.w,
            height: 46.w,
            color: AppColors.muted,
          ),
          errorWidget: (_, _, _) =>
              const IconBubble(Iconsax.gallery, purple, size: 46),
        ),
      );
    }
    return const IconBubble(Iconsax.document_text, purple, size: 46);
  }

  String _size(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
