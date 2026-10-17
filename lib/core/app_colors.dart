import 'package:flutter/material.dart';

import 'palette.dart';

/// RentWise design tokens — extracted from the screen design pack.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDeep = Color(0xFF4338CA);
  static const Color primarySoft = Color(0xFFEEF2FF);
  static const Color primaryBorder = Color(0xFFDDE3FB);
  static const Color primaryTint = Color(0xFFE0E7FF);

  // Surfaces
  static const Color background = Color(0xFFF6F7FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFEAEDF5);
  static const Color sidebar = Color(0xFFFFFFFF);
  static const Color subtleFill = Color(0xFFF4F5FA);

  // Text
  static const Color textDark = Color(0xFF101828);
  static const Color textBody = Color(0xFF475467);
  static const Color textMuted = Color(0xFF8A94A6);
  static const Color textFaint = Color(0xFFB4BCCB);

  // Status — green (success / in stock)
  static const Color green = Color(0xFF079455);
  static const Color greenBg = Color(0xFFE7F6EF);
  static const Color greenBar = Color(0xFF12B76A);

  // Status — amber (maintenance / pending)
  static const Color amber = Color(0xFFD97706);
  static const Color amberBg = Color(0xFFFDF1DF);
  static const Color amberSoft = Color(0xFFFFFBEB);

  // Status — blue (info / preparing)
  static const Color blue = Color(0xFF2563EB);
  static const Color blueBg = Color(0xFFEAF1FE);

  // Status — purple (order updates)
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleBg = Color(0xFFF2ECFE);

  // Status — red / danger
  static const Color red = Color(0xFFDC2626);
  static const Color redBg = Color(0xFFFDECEC);

  // Avatar pastels
  static const Color avatarGreen = Color(0xFF66967C);
  static const Color avatarPurple = Color(0xFF8F7CE8);
  static const Color avatarTeal = Color(0xFF5FA8A0);
  static const Color avatarOrange = Color(0xFFE09B54);
  static const Color avatarIndigo = Color(0xFF6470E4);
  static const Color avatarBlue = Color(0xFF6E8FD6);

  // Auth gradients
  static const Color blobA = Color(0xFFE5E8FA);
  static const Color blobB = Color(0xFFF2F3FD);
  static const Color blobC = Color(0xFFEEF9F4);
}

/// Rounded corner scale used across the app.
class AppRadius {
  AppRadius._();
  static const double card = 16;
  static const double cardLg = 20;
  static const double chip = 10;
  static const double pill = 999;
  static const double input = 10;
}

/// App-wide shadows — soft in light; deep, real depth in dark.
class AppShadow {
  AppShadow._();
  static List<BoxShadow> card({double? opacity}) => [
        BoxShadow(
          color: AppPalette.dark
              ? Colors.black.withOpacity(0.36)
              : const Color(0xFF1B2B4B).withOpacity(opacity ?? 0.05),
          blurRadius: AppPalette.dark ? 20 : 18,
          offset: const Offset(0, 6),
        ),
      ];
  static List<BoxShadow> pop({double? opacity}) => [
        BoxShadow(
          color: AppPalette.dark
              ? Colors.black.withOpacity(0.55)
              : const Color(0xFF1B2B4B).withOpacity(opacity ?? 0.12),
          blurRadius: AppPalette.dark ? 34 : 30,
          offset: const Offset(0, 12),
        ),
      ];
  /// Soft indigo glow under primary actions (dark mode only; empty in light).
  static List<BoxShadow> glow({Color? color, double blur = 18}) => AppPalette.dark
      ? [
          BoxShadow(
            color: (color ?? AppPalette.primary).withOpacity(0.32),
            blurRadius: blur,
            offset: const Offset(0, 4),
          ),
        ]
      : const [];
}
