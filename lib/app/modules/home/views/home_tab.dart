import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ess_models.dart';
import '../../../routes/app_pages.dart';
import '../../main/main_controller.dart';
import '../controllers/home_controller.dart';

/// Beranda tab — same visual language as the login screen: a solid-primary
/// header panel with a white rounded content sheet underneath.
class HomeTab extends GetView<HomeController> {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Column(
          children: [
            _header(),
            Expanded(child: _sheet()),
          ],
        ),
      ),
    );
  }

  String get _initials {
    final parts = controller.name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  Widget _header() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 16.w, 20.h),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14.r)),
              alignment: Alignment.center,
              child: Obx(() => Text(
                    controller.name.isEmpty ? '' : _initials,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16.sp),
                  )),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${controller.greeting},', style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5.sp)),
                  Obx(() => Text(
                        controller.name.isEmpty ? '—' : controller.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3),
                      )),
                  SizedBox(height: 2.h),
                  Text(controller.todayLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.sp)),
                ],
              ),
            ),
            Obx(() => _iconButton(Iconsax.notification, () => Get.toNamed(Routes.NOTIFICATION), badge: controller.unread.value)),
            SizedBox(width: 8.w),
            _iconButton(Iconsax.logout, controller.logout),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, {int badge = 0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Stack(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12.r)),
            child: Icon(icon, color: Colors.white, size: 20.sp),
          ),
          if (badge > 0)
            Positioned(
              right: 3.w,
              top: 3.h,
              child: Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(color: AppColors.destructive, shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 1.5)),
                constraints: BoxConstraints(minWidth: 15.w, minHeight: 15.w),
                child: Text('$badge', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 8.5.sp, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      child: RefreshIndicator(
        onRefresh: controller.refreshAll,
        color: AppColors.primary,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 24.h),
          children: [
            _attendanceCard(),
            SizedBox(height: 14.h),
            _locationCard(),
            SizedBox(height: 14.h),
            _statsRow(),
            SizedBox(height: 26.h),
            _sectionHeader('Menu Cepat'),
            SizedBox(height: 14.h),
            _actionsGrid(),
            SizedBox(height: 26.h),
            _sectionHeader('Pengumuman Terbaru', onTap: () => Get.find<MainController>().changeTab(2)),
            SizedBox(height: 12.h),
            _announcements(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.navy)),
        if (onTap != null)
          InkWell(
            onTap: onTap,
            child: Text('Lihat semua', style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
      ],
    );
  }

  Widget _attendanceCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Obx(() {
        final t = controller.today.value;
        final clockIn = t?.clockIn ?? '--:--';
        final clockOut = t?.clockOut ?? '--:--';
        final next = t?.canClockIn ?? true;
        final status = t?.status;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Absensi Hari Ini', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5.sp, fontWeight: FontWeight.w600)),
                if (status != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(100.r)),
                    child: Text(status, style: TextStyle(color: Colors.white, fontSize: 10.5.sp, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                _clockStat(Iconsax.login, 'Masuk', clockIn),
                Container(width: 1, height: 34.h, color: Colors.white.withValues(alpha: 0.25), margin: EdgeInsets.symmetric(horizontal: 16.w)),
                _clockStat(Iconsax.logout, 'Pulang', clockOut),
              ],
            ),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13.r)),
                ),
                onPressed: () => Get.toNamed(Routes.ATTENDANCE),
                icon: Icon(next ? Iconsax.finger_scan : Iconsax.logout, size: 20.sp),
                label: Text(next ? 'Clock In Sekarang' : 'Clock Out', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _clockStat(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20.sp),
          SizedBox(width: 9.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.sp)),
              Text(value, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  /// Auto-detected geofence status card.
  Widget _locationCard() {
    return Obx(() {
      final state = controller.locState.value;
      final IconData icon;
      final Color color;
      final String title;
      final String sub;

      switch (state) {
        case LocState.loading:
          icon = Iconsax.location;
          color = AppColors.textMuted;
          title = 'Mendeteksi lokasi…';
          sub = 'Mohon tunggu';
        case LocState.inside:
          icon = Iconsax.location_tick;
          color = AppColors.success;
          title = controller.nearestOffice.value;
          sub = 'Dalam radius kantor · ${controller.distanceMeters.value.round()} m';
        case LocState.outside:
          icon = Iconsax.location_cross;
          color = AppColors.warning;
          title = controller.nearestOffice.value;
          sub = '${controller.distanceMeters.value.round()} m di luar area kantor';
        case LocState.denied:
          icon = Iconsax.location_slash;
          color = AppColors.destructive;
          title = 'Izin lokasi ditolak';
          sub = 'Aktifkan izin lokasi untuk absen';
        case LocState.gpsOff:
          icon = Iconsax.gps_slash;
          color = AppColors.destructive;
          title = 'GPS nonaktif';
          sub = 'Nyalakan GPS untuk absen';
        case LocState.noOffice:
          icon = Iconsax.location;
          color = AppColors.textMuted;
          title = 'Lokasi kerja belum diatur';
          sub = 'Hubungi HR';
        case LocState.error:
          icon = Iconsax.location;
          color = AppColors.textMuted;
          title = 'Gagal deteksi lokasi';
          sub = 'Ketuk untuk coba lagi';
      }

      return InkWell(
        onTap: controller.detectLocation,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12.r)),
                child: Icon(icon, color: color, size: 21.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lokasi Anda', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5.sp)),
                    SizedBox(height: 1.h),
                    Text(
                      title.isEmpty ? '—' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13.5.sp),
                    ),
                    SizedBox(height: 1.h),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11.5.sp, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (state == LocState.loading)
                SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Iconsax.refresh, size: 16.sp, color: AppColors.textMuted),
            ],
          ),
        ),
      );
    });
  }

  /// Three at-a-glance dashboard stats.
  Widget _statsRow() {
    return Obx(() {
      final s = controller.summary.value;

      return Row(
        children: [
          Expanded(child: _statCard(Iconsax.sun_1, const Color(0xFF16A34A), 'Sisa Cuti', s == null ? '—' : '${s.leaveAvailable.toInt()} hari')),
          SizedBox(width: 10.w),
          Expanded(child: _statCard(Iconsax.clock, AppColors.primary, 'Jam Bln Ini', s == null ? '—' : '${s.workHoursMonth.toStringAsFixed(0)} jam')),
          SizedBox(width: 10.w),
          Expanded(child: _statCard(Iconsax.task_square, AppColors.warning, 'Pending', s == null ? '—' : '${s.pendingCount}')),
        ],
      );
    });
  }

  Widget _statCard(IconData icon, Color color, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10.r)),
            child: Icon(icon, color: color, size: 17.sp),
          ),
          SizedBox(height: 8.h),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 15.sp)),
          SizedBox(height: 2.h),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp)),
        ],
      ),
    );
  }

  Widget _actionsGrid() {
    final items = [
      _Action('Cuti', Iconsax.sun_1, Routes.LEAVE, const Color(0xFF16A34A)),
      _Action('Lembur', Iconsax.timer_1, Routes.OVERTIME, const Color(0xFFD97706)),
      _Action('Izin', Iconsax.calendar_remove, Routes.PERMISSION, const Color(0xFF7C3AED)),
      _Action('WFH', Iconsax.house, Routes.WFH, const Color(0xFF0EA5E9)),
      _Action('Reimburse', Iconsax.wallet_money, Routes.REIMBURSEMENT, const Color(0xFFDB2777)),
      _Action('Slip Gaji', Iconsax.receipt_2, Routes.PAYSLIP, const Color(0xFF0891B2)),
      _Action('Absensi', Iconsax.finger_scan, Routes.ATTENDANCE, const Color(0xFF2F54C9)),
      _Action('Notifikasi', Iconsax.notification, Routes.NOTIFICATION, const Color(0xFF475569)),
    ];
    // Chunk into rows of 4 (Column of Rows avoids GridView's phantom height
    // inside a scroll view).
    final rows = <List<_Action>>[];
    for (var i = 0; i < items.length; i += 4) {
      rows.add(items.sublist(i, (i + 4).clamp(0, items.length)));
    }
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: EdgeInsets.only(bottom: 18.h),
          child: Row(
            children: List.generate(4, (i) {
              if (i >= row.length) {
                return const Expanded(child: SizedBox.shrink());
              }
              return Expanded(child: _actionTile(row[i]));
            }),
          ),
        );
      }).toList(),
    );
  }

  Widget _actionTile(_Action a) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => Get.toNamed(a.route),
      child: Column(
        children: [
          Container(
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(color: a.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16.r)),
            child: Icon(a.icon, color: a.color, size: 25.sp),
          ),
          SizedBox(height: 7.h),
          Text(a.label, maxLines: 1, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 11.sp)),
        ],
      ),
    );
  }

  Widget _announcements() {
    return Obx(() {
      final items = controller.announcements;
      if (items.isEmpty) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
          decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(16.r)),
          child: Row(
            children: [
              Icon(Iconsax.volume_high, size: 20.sp, color: AppColors.textMuted),
              SizedBox(width: 10.w),
              Text('Belum ada pengumuman.', style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp)),
            ],
          ),
        );
      }
      return Column(
        children: items.map(_announcementCard).toList(),
      );
    });
  }

  Widget _announcementCard(AnnouncementItem a) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11.r)),
            child: Icon(a.pinned ? Iconsax.paperclip2 : Iconsax.volume_high, color: AppColors.primary, size: 19.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13.5.sp)),
                if (a.body != null && a.body!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Text(a.body!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp)),
                  ),
              ],
            ),
          ),
          if (a.publishedAt != null)
            Text(a.publishedAt!.split('T').first, style: TextStyle(color: AppColors.textMuted, fontSize: 10.5.sp)),
        ],
      ),
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final String route;
  final Color color;
  _Action(this.label, this.icon, this.route, this.color);
}
