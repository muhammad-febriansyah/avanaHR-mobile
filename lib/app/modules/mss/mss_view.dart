import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/models/mss.dart';
import 'mss_controller.dart';

class MssView extends GetView<MssController> {
  const MssView({super.key});

  static const _typeColors = {
    'leave': AppColors.success,
    'lembur': AppColors.warning,
    'izin': Color(0xFF9333EA),
    'wfh': Color(0xFF0EA5E9),
    'koreksi': Color(0xFF4F46E5),
    'reimburse': Color(0xFFDB2777),
  };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppPage(
        title: 'Persetujuan Tim',
        subtitle: 'Manager Self-Service',
        child: Column(
          children: [
            _tabBar(),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                return TabBarView(
                  children: [_approvalsTab(), _historyTab(), _teamTab()],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        padding: EdgeInsets.all(4.w),
        tabs: [
          Obx(() => Tab(
                height: 38.h,
                child: Text(controller.approvals.isEmpty
                    ? 'Persetujuan'
                    : 'Persetujuan (${controller.approvals.length})'),
              )),
          const Tab(height: 38, child: Text('Riwayat')),
          const Tab(height: 38, child: Text('Tim')),
        ],
      ),
    );
  }

  // ---- Approvals ------------------------------------------------------------

  Widget _approvalsTab() {
    return Obx(() {
      final items = controller.approvals;
      return Column(
        children: [
          if (controller.selectionMode) _bulkBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: items.isEmpty
                  ? _empty(
                      Iconsax.tick_circle,
                      'Tidak ada persetujuan',
                      'Semua permintaan tim sudah diproses.',
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (_, i) => _approvalCard(items[i]),
                    ),
            ),
          ),
        ],
      );
    });
  }

  Widget _bulkBar() {
    return Obx(() {
      final n = controller.selected.length;
      return Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: controller.clearSelection,
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Icon(Iconsax.close_square,
                    size: 20.sp, color: AppColors.textMuted),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text('$n dipilih',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
            ),
            _bulkBtn('Tolak', AppColors.destructive, false,
                () => controller.bulk('reject')),
            SizedBox(width: 8.w),
            _bulkBtn('Setujui', AppColors.success, true,
                () => controller.bulk('approve')),
          ],
        ),
      );
    });
  }

  Widget _bulkBtn(String label, Color color, bool filled, VoidCallback onTap) {
    return GestureDetector(
      onTap: controller.acting.value ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(9.r),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : color,
            )),
      ),
    );
  }

  Widget _approvalCard(MssApproval a) {
    final typeColor = _typeColors[a.type] ?? AppColors.primary;
    return Obx(() {
      final isSelected = controller.selected.contains(a.id);
      return Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => controller.toggle(a.id),
                  child: _avatar(a, isSelected),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.employeeName,
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          _typeChip(a.typeLabel, typeColor),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        a.title,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Iconsax.calendar_1,
                              size: 12.sp, color: AppColors.textMuted),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              a.detail,
                              style: TextStyle(
                                  fontSize: 12.sp, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      if (a.reason != null && a.reason!.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(
                          '“${a.reason}”',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _actBtn('Tolak', Iconsax.close_circle,
                      AppColors.destructive, false, () => _reject(a)),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _actBtn('Setujui', Iconsax.tick_circle,
                      AppColors.success, true, () => controller.act(a.id, 'approve')),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _avatar(MssApproval a, bool selected) {
    return Container(
      width: 44.w,
      height: 44.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : a.avatarColor,
      ),
      child: selected
          ? Icon(Iconsax.tick_circle, color: Colors.white, size: 22.sp)
          : Text(
              a.initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14.sp,
              ),
            ),
    );
  }

  Widget _typeChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _actBtn(String label, IconData icon, Color color, bool filled,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: controller.acting.value ? null : onTap,
      child: Container(
        height: 42.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11.r),
          border: filled ? null : Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: filled ? Colors.white : color),
            SizedBox(width: 6.w),
            Text(label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : color,
                )),
          ],
        ),
      ),
    );
  }

  void _reject(MssApproval a) {
    final ctrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.background,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Tolak permintaan?',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${a.employeeName} · ${a.title}',
                style:
                    TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted)),
            SizedBox(height: 12.h),
            TextField(
              controller: ctrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Alasan (opsional)',
                filled: true,
                fillColor: AppColors.muted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive,
                foregroundColor: Colors.white),
            onPressed: () {
              Get.back();
              controller.act(a.id, 'reject',
                  reason: ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
            },
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  // ---- History --------------------------------------------------------------

  Widget _historyTab() {
    return Obx(() {
      final items = controller.history;
      return RefreshIndicator(
        onRefresh: controller.load,
        child: items.isEmpty
            ? _empty(
                Iconsax.clock,
                'Belum ada riwayat',
                'Keputusan yang kamu buat akan tampil di sini.',
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, i) => _historyCard(items[i]),
              ),
      );
    });
  }

  Widget _historyCard(MssApproval a) {
    final typeColor = _typeColors[a.type] ?? AppColors.primary;
    final approved = a.status == 'approved';
    final statusColor = approved ? AppColors.success : AppColors.destructive;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: a.avatarColor),
            child: Text(a.initials,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.sp)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.employeeName,
                          style: TextStyle(
                              fontSize: 13.5.sp, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    ),
                    _typeChip(a.typeLabel, typeColor),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(a.title,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                SizedBox(height: 2.h),
                Text(a.detail, style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted)),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(approved ? Iconsax.tick_circle : Iconsax.close_circle,
                              size: 12.sp, color: statusColor),
                          SizedBox(width: 4.w),
                          Text(approved ? 'Disetujui' : 'Ditolak',
                              style: TextStyle(
                                  fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: statusColor)),
                        ],
                      ),
                    ),
                    if (a.decidedAt != null) ...[
                      const Spacer(),
                      Text(a.decidedAt!,
                          style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Team -----------------------------------------------------------------

  Widget _teamTab() {
    return Obx(() {
      final members = controller.team;
      if (members.isEmpty) {
        return _empty(Iconsax.people, 'Belum ada anggota tim',
            'Anda belum menjadi atasan siapa pun.');
      }
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          itemCount: members.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (_, i) => _teamCard(members[i]),
        ),
      );
    });
  }

  Widget _teamCard(MssTeamMember m) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: m.avatarColor),
            child: Text(m.initials,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
                SizedBox(height: 2.h),
                Text(
                  [m.position, m.department].where((e) => e != null).join(' · '),
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
                ),
                if (m.employeeNumber != null) ...[
                  SizedBox(height: 2.h),
                  Text('NIK ${m.employeeNumber}',
                      style:
                          TextStyle(fontSize: 11.sp, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          _statusChip(m.status),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final active = status.toLowerCase() == 'active';
    final color = active ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(active ? 'Aktif' : status,
          style: TextStyle(
              fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ---- Shared ---------------------------------------------------------------

  Widget _empty(IconData icon, String title, String hint) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 80.h),
        Icon(icon, size: 56.sp, color: AppColors.border),
        SizedBox(height: 16.h),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
        SizedBox(height: 6.h),
        Text(hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted)),
      ],
    );
  }
}
