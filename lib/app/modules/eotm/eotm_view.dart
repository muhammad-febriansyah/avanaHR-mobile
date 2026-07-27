import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import '../sosmed/sosmed_view.dart' show hexColor;
import 'eotm_controller.dart';

/// Employee of the Month: the open period, the live tally, and the ballot.
class EotmView extends GetView<EotmController> {
  const EotmView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Employee of the Month',
      subtitle: 'Apresiasi rekan kerja terbaik',
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Loading();
        }

        final period = controller.period.value;

        if (period == null) {
          return Padding(
            padding: EdgeInsets.only(top: 60.h),
            child: const EmptyState(
              icon: Iconsax.crown_1,
              message: 'Belum ada periode voting yang dibuka.',
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 32.h),
            children: [
              _periodBanner(period),
              SizedBox(height: 14.h),
              if (controller.canVote) _ballotButton(context),
              if (controller.canVote) SizedBox(height: 16.h),
              _standingsHeader(period),
              SizedBox(height: 10.h),
              if (controller.standings.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 30.h),
                  child: Center(
                    child: Text(
                      'Belum ada suara masuk.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                ...controller.standings.map(
                  (row) => Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _standingRow(row),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _periodBanner(EotmPeriodItem period) {
    final closed = !period.isOpen;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        // Flat fill, no gradient: the colour alone says open (brand) vs closed
        // (navy), matching every other surface in the app.
        color: closed ? AppColors.navy : AppColors.primary,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.crown5, size: 20.sp, color: Colors.amber),
              SizedBox(width: 8.w),
              Text(
                period.label,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99.r),
                ),
                child: Text(
                  closed ? 'DITUTUP' : 'BERLANGSUNG',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            closed && period.winner != null
                ? 'Pemenang: ${period.winner} (${period.winnerVotes} suara)'
                : '${period.totalVotes} suara masuk',
            style: TextStyle(
              fontSize: 12.5.sp,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          if (period.description != null) ...[
            SizedBox(height: 6.h),
            Text(
              period.description!,
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ballotButton(BuildContext context) {
    return Obx(() {
      final vote = controller.myVote.value;

      return GestureDetector(
        onTap: () => _openBallot(context),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            // A brand tint carries the "not voted yet" cue; the app uses fills
            // rather than outlines, so an border here would stand out wrongly.
            color: vote == null
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            children: [
              Icon(
                vote == null ? Iconsax.star : Iconsax.tick_circle,
                size: 20.sp,
                color: vote == null ? AppColors.primary : AppColors.success,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vote == null ? 'Beri vote kamu' : 'Kamu memilih',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      vote == null
                          ? 'Pilih rekan kerja terbaik bulan ini'
                          : '${vote.nominee ?? '-'}${vote.coreValue != null ? ' · ${vote.coreValue}' : ''}',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                size: 16.sp,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _standingsHeader(EotmPeriodItem period) {
    return Row(
      children: [
        Text(
          'Perolehan Sementara',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          '${period.totalVotes} suara',
          style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _standingRow(EotmStandingItem row) {
    final accent = hexColor(row.coreValueColor);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 22.w,
                child: Text(
                  '${row.rank}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: row.rank <= 3 ? Colors.amber[700] : AppColors.textMuted,
                  ),
                ),
              ),
              _avatar(row),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (row.coreValue != null)
                      Text(
                        row.coreValue!,
                        style: TextStyle(fontSize: 11.sp, color: accent),
                      ),
                  ],
                ),
              ),
              Text(
                '${row.votes} suara',
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(99.r),
            child: LinearProgressIndicator(
              value: row.percent / 100,
              minHeight: 5.h,
              backgroundColor: AppColors.muted,
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(EotmStandingItem row) {
    if (row.photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99.r),
        child: CachedNetworkImage(
          imageUrl: row.photo!,
          width: 34.w,
          height: 34.w,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _initials(row.name),
        ),
      );
    }

    return _initials(row.name);
  }

  Widget _initials(String name) {
    return Container(
      width: 34.w,
      height: 34.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// The ballot: search a colleague, pick a core value, add an optional reason.
  void _openBallot(BuildContext context) {
    final searchC = TextEditingController();
    final reasonC = TextEditingController();

    controller.loadNominees();

    showAppSheet(
      context,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader('Voting Employee of the Month'),
            SizedBox(height: 14.h),

            TextField(
              controller: searchC,
              onChanged: controller.searchNominees,
              style: TextStyle(fontSize: 13.5.sp),
              decoration: InputDecoration(
                hintText: 'Ketik nama karyawan…',
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textMuted,
                ),
                prefixIcon: Icon(Iconsax.search_normal, size: 17.sp),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.4),
                ),
              ),
            ),

            SizedBox(height: 10.h),
            Obx(() {
              if (controller.loadingNominees.value) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: const Loading(),
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 190.h),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: controller.nominees.length,
                  separatorBuilder: (_, _) => SizedBox(height: 6.h),
                  itemBuilder: (_, i) {
                    final nominee = controller.nominees[i];
                    final selected =
                        controller.selectedNominee.value?.id == nominee.id;

                    return GestureDetector(
                      onTap: () => controller.selectedNominee.value = nominee,
                      child: Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.muted,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                nominee.name,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Iconsax.tick_circle5,
                                size: 17.sp,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            SizedBox(height: 14.h),
            Text(
              'Core value yang paling dia tunjukkan',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Obx(
              () => Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: controller.coreValues.map((value) {
                  final selected = controller.selectedValueId.value == value.id;
                  final accent = hexColor(value.color);

                  return GestureDetector(
                    onTap: () => controller.selectedValueId.value = selected
                        ? null
                        : value.id,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 7.h,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.12)
                            : AppColors.muted,
                        borderRadius: BorderRadius.circular(99.r),
                      ),
                      child: Text(
                        value.name,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: selected ? accent : AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: 14.h),
            TextField(
              controller: reasonC,
              maxLines: 3,
              maxLength: 500,
              style: TextStyle(fontSize: 13.5.sp),
              decoration: InputDecoration(
                hintText: 'Kenapa dia pantas? (opsional)',
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textMuted,
                ),
                counterText: '',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: EdgeInsets.all(12.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.4),
                ),
              ),
            ),

            SizedBox(height: 16.h),
            Obx(
              () => AppSubmitButton(
                label: 'Kirim Vote',
                loading: controller.submitting.value,
                onPressed: () async {
                  final ok = await controller.submitVote(
                    reason: reasonC.text.trim(),
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
