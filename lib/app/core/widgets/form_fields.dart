import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_colors.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String _prettyDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Shared field decoration: filled, rounded, hairline border, primary on focus.
InputDecoration _decoration({String? hint, IconData? icon, String? prefixText}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: c, width: w),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
    prefixIcon: icon != null ? Icon(icon, size: 18.sp, color: AppColors.textMuted) : null,
    prefixText: prefixText,
    prefixStyle: TextStyle(color: AppColors.navy, fontSize: 14.sp, fontWeight: FontWeight.w600),
    filled: true,
    fillColor: AppColors.muted,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary, 1.5),
  );
}

Widget _label(String text) => Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy, fontSize: 12.5.sp)),
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: obscure ? 1 : maxLines,
          obscureText: obscure,
          inputFormatters: formatters,
          style: TextStyle(color: AppColors.navy, fontSize: 14.sp),
          decoration: _decoration(hint: hint, icon: icon, prefixText: prefixText),
        ),
      ],
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

  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
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
                Icon(Iconsax.calendar_1, size: 18.sp, color: AppColors.textMuted),
                SizedBox(width: 10.w),
                Text(
                  value == null ? 'Pilih tanggal' : _prettyDate(value!),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: value == null ? AppColors.textMuted : AppColors.navy,
                    fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
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

  const AppTimeField({super.key, required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
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
                    fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
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

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hint != null ? Text(hint!, style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp)) : null,
          icon: Icon(Iconsax.arrow_down_1, size: 16.sp, color: AppColors.textMuted),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        ),
        child: loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18.sp, color: Colors.white), SizedBox(width: 8.w)],
                  Text(label, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700)),
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
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4.r)),
          ),
        ),
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 17.sp, letterSpacing: -0.3)),
      ],
    );
  }
}

/// Formats digits as a Rupiah amount with thousands separators (e.g. 1000000
/// becomes "1.000.000"). Pair with a `prefixText: 'Rp '` field.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
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
int parseRupiah(String text) => int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
