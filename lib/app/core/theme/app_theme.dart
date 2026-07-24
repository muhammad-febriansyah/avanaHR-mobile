import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Poppins + brand colors, light mode only (matches the AvanaHR web app).
class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.destructive,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.navy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.navy,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.muted,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: Size.fromHeight(52.h),
          elevation: 0,
          textStyle: GoogleFonts.poppins(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
