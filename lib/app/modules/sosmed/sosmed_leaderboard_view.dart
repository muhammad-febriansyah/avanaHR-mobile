import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import 'sosmed_controller.dart';

/// Top idea contributors: a podium for the first three, then the ranked rest.
class SosmedLeaderboardView extends GetView<SosmedController> {
  const SosmedLeaderboardView({super.key});

  static const _ranges = [
    ('all', 'Semua'),
    ('month', 'Bulan Ini'),
    ('week', 'Minggu Ini'),
    ('today', 'Hari Ini'),
  ];

  @override
  Widget build(BuildContext context) {
    // Loaded on open rather than in onInit: the feed is the common entry point
    // and most sessions never reach this screen.
    if (controller.leaders.isEmpty && !controller.loadingLeaders.value) {
      controller.loadLeaderboard();
    }

    return AppPage(
      title: 'Leaderboard',
      subtitle: 'Kontributor ide terbaik',
      child: Obx(() {
        if (controller.loadingLeaders.value) {
          return const Loading();
        }

        final leaders = controller.leaders;
        final podium = leaders.take(3).toList();
        final rest = leaders.skip(3).toList();

        return RefreshIndicator(
          onRefresh: () => controller.loadLeaderboard(),
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 32.h),
            children: [
              _rangeChips(),
              SizedBox(height: 16.h),
              if (leaders.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 60.h),
                  child: const EmptyState(
                    icon: Iconsax.crown_1,
                    message: 'Belum ada kontributor bulan ini.',
                  ),
                )
              else ...[
                _podium(podium),
                SizedBox(height: 16.h),
                ...rest.map(
                  (leader) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _row(leader),
                  ),
                ),
                if (!controller.showAllLeaders.value && leaders.length >= 20)
                  Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: GestureDetector(
                      onTap: () => controller.loadLeaderboard(showAll: true),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          'Lihat semua',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 14.h),
                Text(
                  'Poin dihitung dari jumlah ide, like, dan komentar yang diterima.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _rangeChips() {
    return SizedBox(
      height: 34.h,
      child: Obx(
        () => ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _ranges.length,
          separatorBuilder: (_, _) => SizedBox(width: 8.w),
          itemBuilder: (_, i) {
            final (value, label) = _ranges[i];
            final selected = controller.leaderRange.value == value;

            return GestureDetector(
              onTap: () => controller.loadLeaderboard(range: value),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.muted,
                  borderRadius: BorderRadius.circular(99.r),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Rendered 2nd — 1st — 3rd, so the winner sits in the middle and tallest.
  Widget _podium(List<SocialLeaderItem> podium) {
    if (podium.isEmpty) {
      return const SizedBox.shrink();
    }

    final ordered = <SocialLeaderItem?>[
      podium.length > 1 ? podium[1] : null,
      podium[0],
      podium.length > 2 ? podium[2] : null,
    ];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: ordered.map((leader) {
          if (leader == null) {
            return const Expanded(child: SizedBox.shrink());
          }

          final isFirst = leader.rank == 1;
          final size = isFirst ? 62.0 : 50.0;

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFirst)
                  Icon(Iconsax.crown5, size: 20.sp, color: Colors.amber),
                SizedBox(height: 4.h),
                _avatar(leader, size),
                SizedBox(height: 8.h),
                Text(
                  leader.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${leader.points} pts',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _row(SocialLeaderItem leader) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: leader.isMe
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24.w,
            child: Text(
              '${leader.rank}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          _avatar(leader, 34),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leader.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${leader.posts} ide · ${leader.likes} suka',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${leader.points} pts',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(SocialLeaderItem leader, double size) {
    if (leader.photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99.r),
        child: CachedNetworkImage(
          imageUrl: leader.photo!,
          width: size.w,
          height: size.w,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _initials(leader, size),
        ),
      );
    }

    return _initials(leader, size);
  }

  Widget _initials(SocialLeaderItem leader, double size) {
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Text(
        leader.name.isEmpty ? '?' : leader.name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: (size * 0.38).sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
