import 'dart:math' as math;

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
/// (`viewInsets.bottom`) padding or a bottom [SafeArea]: both are applied here.
///
/// Pass [scrollable] `true` when [child] contains a scrollable (e.g. a
/// `SingleChildScrollView`/`ListView`) so the sheet stretches and coordinates
/// its drag with the inner scroll. Leave it `false` (default) for short content
/// that should size the sheet to fit.
///
/// **For a sheet that contains input fields, use [showAppFormSheet] instead** —
/// it guarantees the two things a form needs (a scrollable body and a sheet
/// tall enough to hold it) rather than leaving them to each call site.
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
      // Inset the content by the keyboard height so fields at the bottom of a
      // form stay reachable, falling back to the home-indicator inset while the
      // keyboard is closed. smooth_sheets does NOT do this on its own — without
      // it the sheet stays put and the keyboard covers whatever is underneath.
      //
      // The `padding` property is used rather than a Padding widget on purpose:
      // the blank space it creates is not counted in the content's size, so the
      // sheet's own offsets do not shift as the keyboard opens and closes.
      padding: EdgeInsets.only(
        bottom: math.max(
          MediaQuery.viewInsetsOf(context).bottom,
          MediaQuery.viewPaddingOf(context).bottom,
        ),
      ),
      decoration: MaterialSheetDecoration(
        size: scrollable ? SheetSize.stretch : SheetSize.fit,
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        clipBehavior: Clip.antiAlias,
      ),
      child: SheetKeyboardDismissible(
        dismissBehavior: const SheetKeyboardDismissBehavior.onDragDown(),
        // `padding` above already carries the bottom inset; a bottom SafeArea
        // here would apply it a second time.
        child: SafeArea(top: false, bottom: false, child: child),
      ),
    ),
  );
}

/// Presents a form as a modal sheet: [children] are laid out in a column that
/// scrolls, inside a sheet that stretches to the space the keyboard leaves.
///
/// Use this for every sheet holding input fields. Building one out of
/// [showAppSheet] by hand is what let the keyboard cover the lower half of a
/// form: a sheet sized to fit its content, with scrolling switched off, has no
/// way to reach the fields the keyboard pushes out of view.
///
/// [children] should be the form's rows only — the surface, corner radius,
/// padding, keyboard inset and safe area all come from the sheet.
Future<T?> showAppFormSheet<T>(
  BuildContext context, {
  required List<Widget> children,
  EdgeInsetsGeometry? padding,
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
}) {
  return showAppSheet<T>(
    context,
    scrollable: true,
    child: SingleChildScrollView(
      padding: padding ?? EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      ),
    ),
  );
}
