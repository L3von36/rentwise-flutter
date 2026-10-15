import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/density.dart';

/// White section card with icon + title (+ subtitle) and trailing action.
class SectionCard extends StatelessWidget {
  final IconData? icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsets padding;
  final Widget child;

  const SectionCard({
    super.key,
    this.icon,
    this.iconColor = AppColors.primary,
    this.iconBg = AppColors.primarySoft,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: Density.compact(context)
          ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
          : padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadow.card(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                IconChipLite(icon: icon!, color: iconColor, bg: iconBg),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 10), action!],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Smaller icon chip for card headers (no border).
class IconChipLite extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final double size;
  const IconChipLite({
    super.key,
    required this.icon,
    required this.color,
    required this.bg,
    this.size = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }
}

/// Uppercase micro label (eyebrow) used above page titles and KPI values.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const Eyebrow(this.text, {super.key, this.color = AppColors.textMuted});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color,
      ),
    );
  }
}

/// Primary indigo action button with icon.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final bool expanded;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 40,
    this.fontSize = 13,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: onTap == null ? AppColors.textFaint : AppColors.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 4, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Secondary outlined button.
class OutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color fg;
  final double height;

  const OutlineButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.fg = AppColors.textBody,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
