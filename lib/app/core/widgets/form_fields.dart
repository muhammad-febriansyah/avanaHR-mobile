import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import 'app_sheet.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _prettyDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Shared field decoration: filled, rounded, hairline border, primary on focus.
InputDecoration _decoration({
  String? hint,
  IconData? icon,
  String? prefixText,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14.r),
    borderSide: BorderSide(color: c, width: w),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
    prefixIcon: icon != null
        ? Icon(icon, size: 18.sp, color: AppColors.textMuted)
        : null,
    prefixText: prefixText,
    prefixStyle: TextStyle(
      color: AppColors.navy,
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: AppColors.muted,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary, 1.5),
  );
}

Widget _label(String text, {bool required = false}) => Padding(
  padding: EdgeInsets.only(bottom: 6.h),
  child: RichText(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
        fontSize: 12.5.sp,
      ),
      children: required
          ? [
              TextSpan(
                text: ' *',
                style: TextStyle(
                  color: AppColors.destructive,
                  fontSize: 12.5.sp,
                ),
              ),
            ]
          : null,
    ),
  ),
);

/// Small helper/error caption shown under a field.
Widget _helper(String text) => Padding(
  padding: EdgeInsets.only(top: 6.h, left: 2.w),
  child: Text(
    text,
    style: TextStyle(color: AppColors.textMuted, fontSize: 11.5.sp),
  ),
);

/// Labelled text input matching the app's card style.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscure;
  final List<TextInputFormatter>? formatters;
  final bool required;
  final String? helper;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.prefixText,
    this.keyboardType,
    this.maxLines = 1,
    this.obscure = false,
    this.formatters,
    this.required = false,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: obscure ? 1 : maxLines,
          obscureText: obscure,
          inputFormatters: formatters,
          style: TextStyle(color: AppColors.navy, fontSize: 14.sp),
          decoration: _decoration(
            hint: hint,
            icon: icon,
            prefixText: prefixText,
          ),
        ),
        if (helper != null) _helper(helper!),
      ],
    );
  }
}

/// Rupiah amount input: number keypad, a `Rp ` prefix, a leading wallet icon,
/// and live thousands grouping (1000000 → "1.000.000"). Read the value back
/// with `parseRupiah(controller.text)`. Standardizes every money field so they
/// look and behave identically across the app.
class AppMoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool required;
  final String? helper;

  const AppMoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon = Iconsax.wallet_money,
    this.required = false,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint ?? '0',
      icon: icon,
      prefixText: 'Rp ',
      keyboardType: TextInputType.number,
      formatters: [RupiahInputFormatter()],
      required: required,
      helper: helper,
    );
  }
}

/// Tappable date field that opens a date picker.
class AppDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool required;

  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.firstDate,
    this.lastDate,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: firstDate ?? now.subtract(const Duration(days: 365)),
              lastDate: lastDate ?? now.add(const Duration(days: 365)),
            );
            if (picked != null) {
              onPick(picked);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.calendar_1,
                  size: 18.sp,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 10.w),
                Text(
                  value == null ? 'Pilih tanggal' : _prettyDate(value!),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: value == null ? AppColors.textMuted : AppColors.navy,
                    fontWeight: value == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tappable time field that opens a time picker. Returns "HH:mm".
class AppTimeField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String> onPick;
  final bool required;

  const AppTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              final h = picked.hour.toString().padLeft(2, '0');
              final m = picked.minute.toString().padLeft(2, '0');
              onPick('$h:$m');
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Iconsax.clock, size: 18.sp, color: AppColors.textMuted),
                SizedBox(width: 10.w),
                Text(
                  value ?? 'Pilih jam',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: value == null ? AppColors.textMuted : AppColors.navy,
                    fontWeight: value == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Labelled dropdown matching the field style.
class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool required;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hint != null
              ? Text(
                  hint!,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
                )
              : null,
          icon: Icon(
            Iconsax.arrow_down_1,
            size: 16.sp,
            color: AppColors.textMuted,
          ),
          style: TextStyle(color: AppColors.navy, fontSize: 14.sp),
          decoration: _decoration(),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Full-width primary submit button with a loading state.
class AppSubmitButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  const AppSubmitButton({
    super.key,
    required this.loading,
    required this.onPressed,
    this.label = 'Kirim',
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: EdgeInsets.symmetric(vertical: 15.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18.sp, color: Colors.white),
                    SizedBox(width: 8.w),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The title row of a bottom-sheet form (drag handle + title).
class SheetHeader extends StatelessWidget {
  final String title;

  const SheetHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            fontSize: 17.sp,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// Image picker field with an inline preview. Empty state is a tappable
/// dropzone; once an image is chosen it previews full-width with change/remove
/// controls. Sourced from the camera or the gallery.
class AppImageField extends StatelessWidget {
  final String label;
  final String? path;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;
  final String? hint;
  final bool required;

  const AppImageField({
    super.key,
    required this.label,
    required this.path,
    required this.onPick,
    required this.onClear,
    this.hint,
    this.required = false,
  });

  Future<void> _pick(ImageSource source) async {
    final img = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (img != null) onPick(img.path);
  }

  void _chooseSource(BuildContext context) {
    showAppSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          _sourceTile(context, Iconsax.camera, 'Kamera', ImageSource.camera),
          _sourceTile(context, Iconsax.gallery, 'Galeri', ImageSource.gallery),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _sourceTile(
    BuildContext ctx,
    IconData icon,
    String text,
    ImageSource src,
  ) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20.sp),
      ),
      title: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
          fontSize: 14.sp,
        ),
      ),
      onTap: () {
        Navigator.pop(ctx);
        _pick(src);
      },
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: EdgeInsets.all(7.w),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15.sp, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        if (path == null)
          InkWell(
            onTap: () => _chooseSource(context),
            borderRadius: BorderRadius.circular(14.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 22.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Iconsax.gallery_add,
                    size: 26.sp,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Tambah Foto',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.sp,
                    ),
                  ),
                  if (hint != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      hint!,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5.sp,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: Stack(
              children: [
                Image.file(
                  File(path!),
                  width: double.infinity,
                  height: 170.h,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 8.h,
                  right: 8.w,
                  child: Row(
                    children: [
                      _circleButton(
                        Iconsax.edit_2,
                        () => _chooseSource(context),
                      ),
                      SizedBox(width: 8.w),
                      _circleButton(Iconsax.trash, onClear),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Picks several photos as evidence: a thumbnail strip plus an add tile that
/// disappears once [max] is reached. Camera adds one shot at a time; gallery
/// takes a multi-select. Kept separate from [AppImageField], which backs
/// single-file fields like a reimbursement receipt.
class AppImagesField extends StatelessWidget {
  final String label;
  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final String? hint;
  final bool required;
  final int max;

  const AppImagesField({
    super.key,
    required this.label,
    required this.paths,
    required this.onChanged,
    this.hint,
    this.required = false,
    this.max = 5,
  });

  int get _remaining => max - paths.length;

  Future<void> _addFromCamera() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (img != null) onChanged([...paths, img.path]);
  }

  Future<void> _addFromGallery() async {
    final imgs = await ImagePicker().pickMultiImage(
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (imgs.isEmpty) return;

    // Silently dropping the overflow would look like a failed pick, so only
    // take what fits and let the caller surface the cap.
    onChanged([...paths, ...imgs.take(_remaining).map((e) => e.path)]);
  }

  void _remove(int index) {
    final next = [...paths]..removeAt(index);
    onChanged(next);
  }

  void _chooseSource(BuildContext context) {
    showAppSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          _sourceTile(context, Iconsax.camera, 'Kamera', _addFromCamera),
          _sourceTile(context, Iconsax.gallery, 'Galeri', _addFromGallery),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _sourceTile(
    BuildContext ctx,
    IconData icon,
    String text,
    Future<void> Function() pick,
  ) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20.sp),
      ),
      title: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
          fontSize: 14.sp,
        ),
      ),
      onTap: () {
        Navigator.pop(ctx);
        pick();
      },
    );
  }

  Widget _thumb(int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Stack(
        children: [
          Image.file(
            File(paths[index]),
            width: 92.w,
            height: 92.w,
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 4.h,
            right: 4.w,
            child: InkWell(
              onTap: () => _remove(index),
              customBorder: const CircleBorder(),
              child: Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(Iconsax.trash, size: 13.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addTile(BuildContext context) {
    return InkWell(
      onTap: () => _chooseSource(context),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 92.w,
        height: 92.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.gallery_add, size: 22.sp, color: AppColors.primary),
            SizedBox(height: 4.h),
            Text(
              'Tambah Foto',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: required),
        if (hint != null && paths.isEmpty) ...[
          Text(
            hint!,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5.sp),
          ),
          SizedBox(height: 8.h),
        ],
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (var i = 0; i < paths.length; i++) _thumb(i),
            if (_remaining > 0) _addTile(context),
          ],
        ),
        if (paths.isNotEmpty) ...[
          SizedBox(height: 6.h),
          Text(
            '${paths.length}/$max foto',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
          ),
        ],
      ],
    );
  }
}

/// Formats digits as a Rupiah amount with thousands separators (e.g. 1000000
/// becomes "1.000.000"). Pair with a `prefixText: 'Rp '` field.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Parse a Rupiah-formatted string back to an integer.
int parseRupiah(String text) =>
    int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
