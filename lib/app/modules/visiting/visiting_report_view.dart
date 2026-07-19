import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/form_fields.dart';
import 'visiting_controller.dart';
import 'widgets/visit_saved_sheet.dart';

/// "Buat Laporan" — the field visit report an employee files from site.
class VisitingReportView extends GetView<VisitingController> {
  const VisitingReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ReportForm();
  }
}

class _ReportForm extends StatefulWidget {
  const _ReportForm();

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _controller = Get.find<VisitingController>();

  final _locationC = TextEditingController();
  final _clientC = TextEditingController();
  final _purposeC = TextEditingController();
  final _notesC = TextEditingController();
  final _taskC = TextEditingController();

  final _photos = <String>[].obs;
  final _date = Rxn<DateTime>(DateTime.now());

  @override
  void initState() {
    super.initState();
    // A fresh report: no leftover checklist, and a fix taken here and now.
    _controller.resetDraft();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _controller.refreshLocation(),
    );
  }

  @override
  void dispose() {
    _locationC.dispose();
    _clientC.dispose();
    _purposeC.dispose();
    _notesC.dispose();
    _taskC.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Buat Laporan',
      subtitle: 'Kunjungan lapangan',
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
        children: [
          const _SectionLabel(Iconsax.user, 'DATA KUNJUNGAN'),
          SizedBox(height: 8.h),
          ContentCard(
            child: Column(
              children: [
                Obx(
                  () => AppDateField(
                    label: 'Tanggal Kunjungan',
                    value: _date.value,
                    onPick: (d) => _date.value = d,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now(),
                    required: true,
                  ),
                ),
                SizedBox(height: 14.h),
                AppTextField(
                  controller: _locationC,
                  label: 'Lokasi',
                  hint: 'Nama tempat / alamat kunjungan',
                  icon: Iconsax.location,
                  required: true,
                ),
                SizedBox(height: 14.h),
                AppTextField(
                  controller: _clientC,
                  label: 'Klien / Nama Toko',
                  hint: 'Masukkan nama klien',
                ),
                SizedBox(height: 14.h),
                AppTextField(
                  controller: _purposeC,
                  label: 'Tujuan Kunjungan',
                  hint: 'Contoh: Audit stok bulanan dan penawaran SKU baru',
                  maxLines: 3,
                ),
              ],
            ),
          ),

          SizedBox(height: 18.h),
          const _SectionLabel(Iconsax.location, 'LOKASI PRESISI'),
          SizedBox(height: 8.h),
          _PreciseLocationCard(controller: _controller),

          SizedBox(height: 18.h),
          _TasklistCard(controller: _controller, input: _taskC),

          SizedBox(height: 18.h),
          const _SectionLabel(Iconsax.camera, 'FOTO KUNJUNGAN'),
          SizedBox(height: 8.h),
          ContentCard(
            child: Obx(
              () => AppImagesField(
                label: 'Foto Kunjungan',
                hint: 'Maksimal 4 foto, format JPG/PNG',
                paths: _photos.toList(),
                onChanged: _photos.assignAll,
                max: 4,
              ),
            ),
          ),

          SizedBox(height: 18.h),
          const _SectionLabel(Iconsax.note_1, 'CATATAN'),
          SizedBox(height: 8.h),
          ContentCard(
            child: AppTextField(
              controller: _notesC,
              label: 'Catatan',
              hint: 'Tulis catatan penting di sini…',
              maxLines: 3,
            ),
          ),

          SizedBox(height: 24.h),
          Obx(
            () => AppSubmitButton(
              label: 'Simpan Laporan',
              loading: _controller.submitting.value,
              onPressed: _save,
            ),
          ),
          SizedBox(height: 10.h),
          TextButton(
            onPressed: () => Get.back(),
            style: TextButton.styleFrom(
              minimumSize: Size.fromHeight(48.h),
              foregroundColor: AppColors.destructive,
            ),
            child: const Text('Batalkan Kunjungan'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_date.value == null || _locationC.text.trim().isEmpty) {
      AppToast.warning('Isi tanggal & lokasi kunjungan.');

      return;
    }

    final pos = _controller.position.value;

    final ok = await _controller.submit(
      visitDate: _fmt(_date.value!),
      location: _locationC.text.trim(),
      clientName: _clientC.text.trim().isEmpty ? null : _clientC.text.trim(),
      purpose: _purposeC.text.trim().isEmpty ? null : _purposeC.text.trim(),
      notes: _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      latitude: pos?.latitude,
      longitude: pos?.longitude,
      photoPaths: _photos.toList(),
      taskDrafts: _controller.tasks.toList(),
    );

    if (!ok || !mounted) {
      return;
    }

    await showVisitSavedSheet(context);
    Get.back();
  }
}

/// A small uppercase section heading with its icon.
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionLabel(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: AppColors.primary),
        SizedBox(width: 7.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Map preview of where the employee is standing, the coordinates it resolved
/// to, and the street address behind them.
class _PreciseLocationCard extends StatelessWidget {
  final VisitingController controller;

  const _PreciseLocationCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      padding: EdgeInsets.zero,
      child: Obx(() {
        final pos = controller.position.value;
        final busy = controller.locating.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(14.r),
                  ),
                  child: SizedBox(
                    height: 150.h,
                    width: double.infinity,
                    child: pos == null
                        ? Container(
                            color: AppColors.muted,
                            alignment: Alignment.center,
                            child: Text(
                              busy
                                  ? 'Mendeteksi lokasi…'
                                  : 'Lokasi belum tersedia',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )
                        : FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                pos.latitude,
                                pos.longitude,
                              ),
                              initialZoom: 16,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'id.avanahr.mobile',
                                tileProvider: NetworkTileProvider(),
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      pos.latitude,
                                      pos.longitude,
                                    ),
                                    width: 36.w,
                                    height: 36.w,
                                    alignment: Alignment.bottomCenter,
                                    child: Icon(
                                      Icons.location_pin,
                                      color: AppColors.primary,
                                      size: 36.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                Positioned(
                  right: 10.w,
                  top: 10.h,
                  child: _RefreshChip(
                    busy: busy,
                    onTap: controller.refreshLocation,
                  ),
                ),
                if (pos != null)
                  Positioned(
                    left: 10.w,
                    bottom: 10.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        'Lat: ${pos.latitude.toStringAsFixed(4)} · Lon: ${pos.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alamat Lengkap',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    controller.address.value.isEmpty
                        ? 'Alamat belum terbaca'
                        : controller.address.value,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      height: 1.45,
                      fontStyle: controller.address.value.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: controller.address.value.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _RefreshChip extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _RefreshChip({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? SizedBox(
                    width: 12.sp,
                    height: 12.sp,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    Iconsax.refresh,
                    size: 13.sp,
                    color: AppColors.primary,
                  ),
            SizedBox(width: 6.w),
            Text(
              'Perbarui',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The job checklist for this visit: add rows here, tick them off later from
/// the visit list once the work is actually done.
class _TasklistCard extends StatelessWidget {
  final VisitingController controller;
  final TextEditingController input;

  const _TasklistCard({required this.controller, required this.input});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tasks = controller.tasks;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.task_square,
                size: 14.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 7.w),
              Text(
                'TASKLIST PEKERJAAN',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100.r),
                ),
                child: Text(
                  '${tasks.length} TUGAS',
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ContentCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: input,
                        label: '',
                        hint: 'Tambah tugas baru…',
                      ),
                    ),
                    SizedBox(width: 10.w),
                    GestureDetector(
                      onTap: () {
                        controller.addTask(input.text);
                        input.clear();
                      },
                      child: Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Iconsax.add,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                if (tasks.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 14.h),
                    child: Text(
                      'Belum ada tugas. Tugas bersifat opsional.',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                for (var i = 0; i < tasks.length; i++)
                  _TaskRow(
                    index: i,
                    draft: tasks[i],
                    controller: controller,
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// One checklist row: the task, its before/after evidence, and a caption.
class _TaskRow extends StatelessWidget {
  final int index;
  final VisitTaskDraft draft;
  final VisitingController controller;

  const _TaskRow({
    required this.index,
    required this.draft,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.tick_square,
                size: 17.sp,
                color: AppColors.border,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  draft.title,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => controller.removeTask(index),
                child: Icon(
                  Iconsax.close_circle,
                  size: 17.sp,
                  color: AppColors.destructive,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: AppImageField(
                  label: 'BEFORE',
                  path: draft.beforePath,
                  onPick: (p) => controller.setTaskPhoto(index, before: p),
                  onClear: () =>
                      controller.clearTaskPhoto(index, before: true),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: AppImageField(
                  label: 'AFTER',
                  path: draft.afterPath,
                  onPick: (p) => controller.setTaskPhoto(index, after: p),
                  onClear: () => controller.clearTaskPhoto(index, after: true),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          TextFormField(
            initialValue: draft.note,
            onChanged: (v) => controller.setTaskNote(index, v),
            style: TextStyle(fontSize: 12.sp),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Catatan Foto',
              labelStyle: TextStyle(
                fontSize: 11.sp,
                color: AppColors.textMuted,
              ),
              hintText: 'Tambahkan deskripsi foto…',
              hintStyle: TextStyle(
                fontSize: 11.5.sp,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
