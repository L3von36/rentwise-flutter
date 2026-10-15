import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Rounded-square tinted icon container used across cards, tables and lists.
class IconChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final double size;
  final double radius;
  final double iconScale;

  const IconChip({
    super.key,
    required this.icon,
    required this.color,
    required this.bg,
    this.size = 32,
    this.radius = 9,
    this.iconScale = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withOpacity(0.10)),
      ),
      child: Icon(icon, size: size * iconScale, color: color),
    );
  }
}

/// Colored dot used inside status pills.
class Dot extends StatelessWidget {
  final Color color;
  final double size;
  const Dot({super.key, required this.color, this.size = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Pill badge: dot + label, tinted background (status vocabulary of the pack).
class StatusBadge extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final bool dot;
  final double fontSize;
  final EdgeInsets padding;

  const StatusBadge({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
    this.dot = true,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  });

  const StatusBadge.custom({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
    this.dot = false,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Dot(color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular initials avatar.
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  final double fontSize;

  const InitialsAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 30,
    this.fontSize = 11.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
