import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Dark-surface design tokens — "Midnight Indigo" pack.
///
/// Designed as a real dark theme, not a mirrored one:
///  * a readable elevation ramp (canvas → panel → card → raise) so layers
///    separate instead of melting into one gray;
///  * strokes that actually read against cards;
///  * brighter ink ramp for crisp text;
///  * lifted, slightly violet brand indigo + deep tinted status washes so
///    chips and charts keep their light-mode vibrancy.
class DarkTokens {
  DarkTokens._();

  // Surfaces — elevation ramp (each step clearly lighter than the last).
  static const Color background = Color(0xFF0A0D14); // canvas (deepest)
  static const Color sidebar = Color(0xFF0E121C); // panel / nav chrome
  static const Color card = Color(0xFF141A28); // cards / sheets
  static const Color raise = Color(0xFF1C2434); // selected / elevated fills
  static const Color subtleFill = Color(0xFF1A2130); // subtle inputs/fills
  static const Color cardBorder = Color(0xFF263048); // stroke that reads

  // Ink — crisp, high-contrast ramp.
  static const Color textDark = Color(0xFFF3F6FC);
  static const Color textBody = Color(0xFFBAC3D9);
  static const Color textMuted = Color(0xFF8B95B0);
  static const Color textFaint = Color(0xFF5E6982);

  // Brand — indigo lifts + gains a violet edge on dark for gradients.
  static const Color primary = Color(0xFF6E7BF2);
  static const Color primaryDeep = Color(0xFF5A50EA);
  static const Color primarySoft = Color(0xFF1D2447);
  static const Color primaryTint = Color(0xFF2C3468);
  static const Color primaryBorder = Color(0xFF434C8F);

  /// Vertical gradient for hero/primary surfaces on dark.
  static const List<Color> primaryGradient = [Color(0xFF6E7BF2), Color(0xFF8B5CF6)];

  // Status — luminous foregrounds over deep tinted washes.
  static const Color green = Color(0xFF34D399);
  static const Color greenBg = Color(0xFF12332A);
  static const Color greenBar = Color(0xFF2DD48F);
  static const Color amber = Color(0xFFFBBF24);
  static const Color amberBg = Color(0xFF393014);
  static const Color amberSoft = Color(0xFF2C2512);
  static const Color blue = Color(0xFF60A5FA);
  static const Color blueBg = Color(0xFF1A2D52);
  static const Color purple = Color(0xFFA78BFA);
  static const Color purpleBg = Color(0xFF2B2150);
  static const Color red = Color(0xFFF87171);
  static const Color redBg = Color(0xFF3B1E26);

  // Elevated chrome (dialogs / menus / tooltips) — sits above cards.
  static const Color dialog = Color(0xFF19202F);
  static const Color tooltip = Color(0xFF232C40);

  // Auth gradients — nebula glows.
  static const Color blobA = Color(0xFF1C2247);
  static const Color blobB = Color(0xFF12151F);
  static const Color blobC = Color(0xFF11271F);
}

/// Theme-aware access to the design tokens used by custom-painted chrome.
///
/// `AppColors` keeps the compile-time light values; every widget that
/// previously referenced it directly now resolves through [AppPalette],
/// which reads the global [brightness] mirror kept in sync by `ShellState`
/// (the single writer — see `setThemeMode`). Static getters instead of
/// `Theme.of(context)` so helper builders without a context stay simple;
/// `ShellState` bumps [brightness] and notifies, and the MaterialApp is
/// re-keyed so the whole tree rebuilds with fresh values.
class AppPalette {
  AppPalette._();

  /// Mirrors the active MaterialApp brightness. Written only by ShellState.
  static Brightness brightness = Brightness.light;

  static bool get dark => brightness == Brightness.dark;

  // Surfaces
  static Color get canvas => dark ? DarkTokens.background : AppColors.background;
  static Color get surface => dark ? DarkTokens.card : AppColors.card;
  static Color get panel => dark ? DarkTokens.sidebar : AppColors.sidebar;
  static Color get stroke => dark ? DarkTokens.cardBorder : AppColors.cardBorder;
  static Color get fill => dark ? DarkTokens.subtleFill : AppColors.subtleFill;

  /// Elevated/selectable surface — white in light, lifted slate in dark.
  static Color get raise => dark ? DarkTokens.raise : Colors.white;

  // Ink
  static Color get ink => dark ? DarkTokens.textDark : AppColors.textDark;
  static Color get body => dark ? DarkTokens.textBody : AppColors.textBody;
  static Color get muted => dark ? DarkTokens.textMuted : AppColors.textMuted;
  static Color get faint => dark ? DarkTokens.textFaint : AppColors.textFaint;

  // Brand
  static Color get primary => dark ? DarkTokens.primary : AppColors.primary;
  static Color get primaryDeep =>
      dark ? DarkTokens.primaryDeep : AppColors.primaryDeep;
  static Color get primarySoft =>
      dark ? DarkTokens.primarySoft : AppColors.primarySoft;
  static Color get primaryTint =>
      dark ? DarkTokens.primaryTint : AppColors.primaryTint;
  static Color get primaryBorder =>
      dark ? DarkTokens.primaryBorder : AppColors.primaryBorder;

  /// Vertical indigo→violet gradient used by hero/primary surfaces on dark;
  /// light mode gets a subtle same-hue deepen so gradients stay legal (≥2
  /// colors) and visually near-flat.
  static List<Color> get primaryGradient => dark
      ? DarkTokens.primaryGradient
      : const [AppColors.primary, AppColors.primaryDeep];

  // Status
  static Color get green => dark ? DarkTokens.green : AppColors.green;
  static Color get greenBg => dark ? DarkTokens.greenBg : AppColors.greenBg;
  static Color get greenBar => dark ? DarkTokens.greenBar : AppColors.greenBar;
  static Color get amber => dark ? DarkTokens.amber : AppColors.amber;
  static Color get amberBg => dark ? DarkTokens.amberBg : AppColors.amberBg;
  static Color get amberSoft =>
      dark ? DarkTokens.amberSoft : AppColors.amberSoft;
  static Color get blue => dark ? DarkTokens.blue : AppColors.blue;
  static Color get blueBg => dark ? DarkTokens.blueBg : AppColors.blueBg;
  static Color get purple => dark ? DarkTokens.purple : AppColors.purple;
  static Color get purpleBg => dark ? DarkTokens.purpleBg : AppColors.purpleBg;
  static Color get red => dark ? DarkTokens.red : AppColors.red;
  static Color get redBg => dark ? DarkTokens.redBg : AppColors.redBg;

  // Auth gradients
  static Color get blobA => dark ? DarkTokens.blobA : AppColors.blobA;
  static Color get blobB => dark ? DarkTokens.blobB : AppColors.blobB;
  static Color get blobC => dark ? DarkTokens.blobC : AppColors.blobC;
}
