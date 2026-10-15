import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Builds the global Material theme for RentWise.
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Inter';

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primary,
      surface: AppColors.card,
      error: AppColors.red,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.compact,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      listTileTheme: const ListTileThemeData(
        dense: true,
        iconColor: AppColors.textBody,
        titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark),
        subtitleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.textDark),
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500),
        border: _inputBorder(AppColors.cardBorder),
        enabledBorder: _inputBorder(AppColors.cardBorder),
        focusedBorder: _inputBorder(AppColors.primary, width: 1.6),
        errorBorder: _inputBorder(AppColors.red),
        focusedErrorBorder: _inputBorder(AppColors.red, width: 1.6),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: _inputBorder(AppColors.cardBorder),
          enabledBorder: _inputBorder(AppColors.cardBorder),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(Colors.white),
          surfaceTintColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.all(16),
          shadowColor: WidgetStateProperty.all(
              AppColors.textDark.withOpacity(0.18)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 16,
        shadowColor: AppColors.textDark.withOpacity(0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textDark,
        contentTextStyle: const TextStyle(
            fontFamily: fontFamily,
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : Colors.transparent),
        side: const BorderSide(color: AppColors.textFaint, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textDark,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
            fontFamily: fontFamily, color: Colors.white, fontSize: 12),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(TextTheme base) {
    const dark = AppColors.textDark;
    return base.copyWith(
      displayLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w800,
          color: dark,
          letterSpacing: -1.0),
      displayMedium: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 28,
          height: 1.12,
          fontWeight: FontWeight.w800,
          color: dark,
          letterSpacing: -0.8),
      headlineLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 23,
          height: 1.18,
          fontWeight: FontWeight.w800,
          color: dark,
          letterSpacing: -0.7),
      headlineMedium: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          height: 1.22,
          fontWeight: FontWeight.w800,
          color: dark,
          letterSpacing: -0.4),
      headlineSmall: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: dark,
          letterSpacing: -0.3),
      titleLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: dark,
          letterSpacing: -0.1),
      titleMedium: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: dark),
      titleSmall: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: dark),
      bodyLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textBody,
          height: 1.4),
      bodyMedium: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textBody,
          height: 1.42),
      bodySmall: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
          height: 1.38),
      labelLarge: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: dark),
      labelMedium: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textBody),
      labelSmall: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.3),
    );
  }
}
