import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/density.dart';
import '../core/palette.dart';
import 'motion.dart';

/// White section card with icon + title (+ subtitle) and trailing action.
class SectionCard extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBg;
  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsets padding;
  final Widget child;

  const SectionCard({
    super.key,
    this.icon,
    this.iconColor,
    this.iconBg,
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppPalette.stroke),
        boxShadow: AppShadow.card(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: title row with the action inline when there is room.
          // On phones the action drops BELOW the title — the old
          // always-inline Row overflowed when a card carried two
          // buttons (e.g. Team members: Refresh + Add employee).
          // NOTE: no LayoutBuilder here — SectionCard is wrapped in
          // IntrinsicHeight on the dashboard, and LayoutBuilder cannot
          // answer intrinsic-dimension queries.
          Builder(builder: (context) {
            final titleColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            );
            final below = Density.compact(context);
            final header = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  IconChipLite(
                      icon: icon!,
                      color: iconColor ?? AppPalette.primary,
                      bg: iconBg ?? AppPalette.primarySoft),
                  const SizedBox(width: 10),
                ],
                Expanded(child: titleColumn),
                if (action != null && !below) ...[
                  const SizedBox(width: 10),
                  action!,
                ],
              ],
            );
            if (action == null || !below) return header;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 10),
                action!,
              ],
            );
          }),
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
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color ?? AppPalette.muted,
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
    final gradient =
        onTap == null ? null : LinearGradient(colors: AppPalette.primaryGradient);
    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: onTap == null ? null : AppShadow.glow(),
      ),
      child: Material(
        color: onTap == null ? AppPalette.faint : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: onTap == null ? AppPalette.faint : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(10),
          ),
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
        ),
      ),
    );
    final lifted = onTap == null
        ? button
        : PressableScale(
            onTap: onTap,
            child: _ButtonHover(
              radius: 10,
              child: button,
            ),
          );
    if (expanded) {
      return SizedBox(width: double.infinity, child: lifted);
    }
    return lifted;
  }
}

/// Subtle brighten on hover for the filled primary button (the gradient
/// stays put — only the shadow grows).
class _ButtonHover extends StatefulWidget {
  final Widget child;
  final double radius;
  const _ButtonHover({required this.child, required this.radius});

  @override
  State<_ButtonHover> createState() => _ButtonHoverState();
}

class _ButtonHoverState extends State<_ButtonHover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: _hover
              ? AppShadow.glow(blur: 18)
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Secondary outlined button — border tints toward the brand on hover.
class OutlineButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? fg;
  final double height;

  const OutlineButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.fg,
    this.height = 36,
  });

  @override
  State<OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<OutlineButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.fg ?? AppPalette.body;
    final onTap = widget.onTap;
    return PressableScale(
      onTap: onTap,
      child: MouseRegion(
        cursor:
            onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            boxShadow: _hover && onTap != null
                ? AppShadow.card(opacity: AppPalette.dark ? 0.4 : 0.08)
              : const [],
          ),
          child: Material(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                height: widget.height,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: _hover && onTap != null
                          ? AppPalette.primaryBorder
                          : AppPalette.stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 15, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.label,
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
          ),
        ),
      ),
    );
  }
}
