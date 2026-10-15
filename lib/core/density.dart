import 'package:flutter/material.dart';

/// Compact, mobile-first density tokens (Instagram/Telegram feel).
class Density {
  Density._();

  /// Horizontal page padding: 16 on phones, 20 on tablets, 26 on desktop.
  static double pagePad(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return 16;
    if (w < 1000) return 20;
    return 26;
  }
}
