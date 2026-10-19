import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'palette.dart';

/// Builds the global Material theme for RentWise (light + dark).
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Inter';

  /// Global text-size trim. The design reads slightly large at desktop
  /// sizes, so every tier of the responsive ramp in `app.dart` is
  /// multiplied by this — bump to 1.0 to restore the original scale.
  static const double textScale = 0.93;

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

    return _withEthiopicFallback(_decorate(
      base,
      scheme: scheme,
      background: AppColors.background,
      card: AppColors.card,
      stroke: AppColors.cardBorder,
      fill: AppColors.subtleFill,
      ink: AppColors.textDark,
      body: AppColors.textBody,
      muted: AppColors.textMuted,
      faint: AppColors.textFaint,
      primary: AppColors.primary,
      primarySoft: AppColors.primarySoft,
      red: AppColors.red,
      textScaleShadow: AppColors.textDark,
    ));
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: DarkTokens.primary,
      onPrimary: Colors.white,
      secondary: DarkTokens.primary,
      surface: DarkTokens.card,
      error: DarkTokens.red,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: DarkTokens.background,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.compact,
    );

    return _withEthiopicFallback(_decorate(
      base,
      scheme: scheme,
      background: DarkTokens.background,
      card: DarkTokens.card,
      stroke: DarkTokens.cardBorder,
      fill: DarkTokens.subtleFill,
      ink: DarkTokens.textDark,
      body: DarkTokens.textBody,
      muted: DarkTokens.textMuted,
      faint: DarkTokens.textFaint,
      primary: DarkTokens.primary,
      primarySoft: DarkTokens.primarySoft,
      red: DarkTokens.red,
      textScaleShadow: DarkTokens.textDark,
    ));
  }

  /// Shared theme decoration for both brightnesses — identical structure,
  /// different tokens.
  static ThemeData _decorate(
    ThemeData base, {
    required ColorScheme scheme,
    required Color background,
    required Color card,
    required Color stroke,
    required Color fill,
    required Color ink,
    required Color body,
    required Color muted,
    required Color faint,
    required Color primary,
    required Color primarySoft,
    required Color red,
    required Color textScaleShadow,
  }) {
    final dark = scheme.brightness == Brightness.dark;

    return base.copyWith(
      textTheme: _textTheme(base.textTheme,
          ink: ink, body: body, muted: muted),
      listTileTheme: ListTileThemeData(
        dense: true,
        iconColor: body,
        titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ink),
        subtitleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            fontWeight: FontWeight.w400,
            color: muted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        surfaceTintColor: card,
        elevation: 0,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: ink),
      ),
      cardTheme: CardTheme(
        color: card,
        surfaceTintColor: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: stroke),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: stroke,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? DarkTokens.subtleFill : card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: TextStyle(
            color: muted, fontSize: 13, fontWeight: FontWeight.w500),
        border: _inputBorder(stroke),
        enabledBorder: _inputBorder(stroke),
        focusedBorder: _inputBorder(primary, width: 1.6),
        errorBorder: _inputBorder(red),
        focusedErrorBorder: _inputBorder(red, width: 1.6),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ink),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: dark ? DarkTokens.subtleFill : card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: _inputBorder(stroke),
          enabledBorder: _inputBorder(stroke),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(card),
          surfaceTintColor: WidgetStateProperty.all(card),
          elevation: const WidgetStatePropertyAll(16),
          shadowColor: WidgetStateProperty.all(
              dark ? Colors.black.withOpacity(0.6) : AppColors.cardBorder.withOpacity(0.35)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: stroke),
            ),
          ),
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? DarkTokens.dialog : card,
        surfaceTintColor: dark ? DarkTokens.dialog : card,
        elevation: 16,
        shadowColor: dark ? Colors.black.withOpacity(0.6) : AppColors.cardBorder.withOpacity(0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: stroke),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? DarkTokens.tooltip : textScaleShadow,
        contentTextStyle: TextStyle(
            fontFamily: fontFamily,
            color: dark ? DarkTokens.textDark : Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: dark ? DarkTokens.dialog : card,
        surfaceTintColor: dark ? DarkTokens.dialog : card,
        elevation: dark ? 24 : 0,
        shadowColor: dark ? Colors.black.withOpacity(0.5) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: dark ? BorderSide(color: stroke) : BorderSide.none,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: dark ? DarkTokens.dialog : card,
        surfaceTintColor: dark ? DarkTokens.dialog : card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? primary
                : Colors.transparent),
        side: BorderSide(color: faint, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? DarkTokens.tooltip : textScaleShadow,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
            fontFamily: fontFamily,
            color: dark ? DarkTokens.textDark : Colors.white,
            fontSize: 12),
      ),
    );
  }

  /// Amharic UI: Ge'ez glyphs are missing from Inter, so every themed
  /// text style falls back to the bundled Noto Sans Ethiopic (per-widget
  /// explicit TextStyles get the same engine-level fallback).
  static const List<String> ethiopicFallback = ['Noto Sans Ethiopic'];

  static ThemeData _withEthiopicFallback(ThemeData t) => t.copyWith(
        textTheme: t.textTheme.apply(fontFamilyFallback: ethiopicFallback),
      );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(
    TextTheme base, {
    required Color ink,
    required Color body,
    required Color muted,
  }) {
    return base.copyWith(
      displayLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -1.0),
      displayMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 28,
          height: 1.12,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.8),
      headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 23,
          height: 1.18,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.7),
      headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          height: 1.22,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.4),
      headlineSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.3),
      titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.1),
      titleMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: ink),
      titleSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: ink),
      bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: body,
          height: 1.4),
      bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: body,
          height: 1.42),
      bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
          color: muted,
          height: 1.38),
      labelLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ink),
      labelMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: body),
      labelSmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: muted,
          letterSpacing: 0.3),
    );
  }
}
