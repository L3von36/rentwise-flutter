import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Dark-surface design tokens. Same visual language as the light pack:
/// cool slate surfaces, one indigo accent, soft status washes.
class DarkTokens {
  DarkTokens._();

  // Surfaces
  static const Color background = Color(0xFF0C0F16);
  static const Color card = Color(0xFF151A24);
  static const Color sidebar = Color(0xFF10141C);
  static const Color cardBorder = Color(0xFF272F3D);
  static const Color subtleFill = Color(0xFF1B212C);

  // Ink
  static const Color textDark = Color(0xFFE8ECF4);
  static const Color textBody = Color(0xFFA7B2C4);
  static const Color textMuted = Color(0xFF79849A);
  static const Color textFaint = Color(0xFF545F74);

  // Brand — indigo lifts slightly on dark for contrast.
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDeep = Color(0xFF4F46E5);
  static const Color primarySoft = Color(0xFF20244A);
  static const Color primaryTint = Color(0xFF272C58);
  static const Color primaryBorder = Color(0xFF3B4070);

  // Status washes — deeper fills, lighter foregrounds.
  static const Color green = Color(0xFF34D399);
  static const Color greenBg = Color(0xFF10291D);
  static const Color greenBar = Color(0xFF2FBE77);
  static const Color amber = Color(0xFFFBBF24);
  static const Color amberBg = Color(0xFF2E2510);
  static const Color amberSoft = Color(0xFF271F0E);
  static const Color blue = Color(0xFF60A5FA);
  static const Color blueBg = Color(0xFF142542);
  static const Color purple = Color(0xFFA78BFA);
  static const Color purpleBg = Color(0xFF241B3D);
  static const Color red = Color(0xFFF87171);
  static const Color redBg = Color(0xFF341B1E);

  // Auth gradients
  static const Color blobA = Color(0xFF191D38);
  static const Color blobB = Color(0xFF141827);
  static const Color blobC = Color(0xFF11241B);
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
