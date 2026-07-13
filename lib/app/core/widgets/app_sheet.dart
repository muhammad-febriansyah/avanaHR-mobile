import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../theme/app_colors.dart';

/// Presents [child] as a swipe-dismissible modal sheet with the app's
/// rounded-top surface styling. Wraps `smooth_sheets` so every sheet across the
/// app shares the same smooth drag, swipe-to-dismiss, and keyboard behaviour —
/// use this instead of `showModalBottomSheet` / `Get.bottomSheet`.
///
/// [child] must NOT paint its own background or top rounded corners — the sheet
/// decoration provides them. It also should not add manual keyboard
/// (`viewInsets.bottom`) padding: the sheet viewport lifts content above the
/// keyboard automatically. Fields still get a safe-area bottom inset.
///
/// Pass [scrollable] `true` when [child] contains a scrollable (e.g. a
/// `SingleChildScrollView`/`ListView`) so the sheet stretches and coordinates
/// its drag with the inner scroll. Leave it `false` (default) for short content
/// that should size the sheet to fit.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,
  bool scrollable = false,
}) {
  return showModalSheet<T>(
    context: context,
    swipeDismissible: true,
    builder: (context) => Sheet(
      scrollConfiguration: scrollable
          ? const SheetScrollConfiguration()
          : SheetScrollConfiguration.disabled,
      decoration: MaterialSheetDecoration(
        size: scrollable ? SheetSize.stretch : SheetSize.fit,
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        clipBehavior: Clip.antiAlias,
      ),
      child: SheetKeyboardDismissible(
        dismissBehavior: const SheetKeyboardDismissBehavior.onDragDown(),
        child: SafeArea(top: false, child: child),
      ),
    ),
  );
}
