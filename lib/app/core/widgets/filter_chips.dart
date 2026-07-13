import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// One selectable option in a [FilterChips] row.
class FilterOption {
  final String value;
  final String label;

  const FilterOption(this.value, this.label);
}

/// A horizontal row of flat choice chips for filtering a list. Client-side only
/// — the caller decides what [selected] filters. Reused across the request and
/// activity history pages so every filter reads the same.
class FilterChips extends StatelessWidget {
  final List<FilterOption> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (_, i) {
          final o = options[i];
          final active = o.value == selected;
          return GestureDetector(
            onTap: () => onSelected(o.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(100.r),
              ),
              child: Text(
                o.label,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Normalises a raw request status into one of three filter groups —
/// `pending` | `approved` | `rejected` — mirroring [StatusChip]'s grouping so
/// the filter and the chip always agree.
String statusGroup(String status) {
  final s = status.toLowerCase();
  if (s == 'approved' || s == 'completed' || s == 'paid') {
    return 'approved';
  }
  if (s == 'rejected' || s == 'cancelled') {
    return 'rejected';
  }
  return 'pending';
}

/// The standard status filter options for request-history pages.
const List<FilterOption> kStatusFilterOptions = [
  FilterOption('all', 'Semua'),
  FilterOption('pending', 'Menunggu'),
  FilterOption('approved', 'Disetujui'),
  FilterOption('rejected', 'Ditolak'),
];
