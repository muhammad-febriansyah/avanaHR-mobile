import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formats.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ess_models.dart';
import 'kasbon_controller.dart';
import 'widgets/kasbon_status_chip.dart';

/// One cash advance in full: the amount, why it was asked for, and how far
/// along the request → approval → disbursement trail it has got.
class KasbonDetailView extends GetView<KasbonController> {
  const KasbonDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final id = Get.arguments as int;

    return AppPage(
      title: 'Detail Uang Muka',
      child: FutureBuilder<CashAdvanceDetail>(
        future: controller.detail(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loading();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const EmptyState(
              icon: Iconsax.warning_2,
              message: 'Uang muka tidak dapat dimuat.',
            );
          }

          return _Body(snapshot.data!, context: context);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final CashAdvanceDetail data;
  final BuildContext context;

  const _Body(this.data, {required this.context});

  @override
  Widget build(BuildContext _) {
    final header = data.header;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        AppPage.bottomNavClearance(context),
      ),
      children: [
        ContentCard(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'JUMLAH UANG MUKA',
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .7,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  KasbonStatusChip(header.status, label: header.statusLabel),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                formatRupiah(header.amount),
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: -.5,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                header.purpose,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        ContentCard(
          child: Column(
            children: [
              InfoRow('Diajukan', header.requestDate),
              InfoRow('Dibutuhkan', header.neededDate),
              if (data.reason != null) InfoRow('Alasan', data.reason),
              if (data.disbursementMethod != null)
                InfoRow('Metode Cair', data.disbursementMethod),
              if (data.disbursementReference != null)
                InfoRow('Referensi', data.disbursementReference),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        Text(
          'ALUR PROSES',
          style: TextStyle(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(height: 8.h),
        ContentCard(
          child: Column(
            children: [
              for (var i = 0; i < data.timeline.length; i++)
                _Step(
                  data.timeline[i],
                  isLast: i == data.timeline.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final SettlementStep step;
  final bool isLast;

  const _Step(this.step, {required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = step.done ? AppColors.success : AppColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 18.w,
                height: 18.w,
                decoration: BoxDecoration(
                  color: step.done ? AppColors.success : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                  shape: BoxShape.circle,
                ),
                child: step.done
                    ? Icon(Icons.check, size: 11.sp, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2.w, color: AppColors.border),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: step.done
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                  if (step.at != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      formatTanggalJam(step.at),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
