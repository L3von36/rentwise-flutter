import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/palette.dart';

/// RentWise motion kit — one place for the app-wide feel:
///
///  * [HoverLift]      — cards rise, glow and tint their border on hover;
///  * [PressableScale] — press-down feedback for any tappable child;
///  * [StaggerIn]      — entrance fade+slide with an index-based delay;
///  * [SectionFade]    — animated crossfade when the workspace switches
///                       sections (used by the app shell).
///
/// Durations are short (120–260 ms) and curves are eased — the goal is a
/// desk-app feel: responsive, never bouncy, never slow.

/// Wraps a card-like child: hover lifts it (translate + shadow + optional
/// border tint), press nudges it down. With [onTap] null it renders the
/// child untouched (purely informational cards stay visually static).
class HoverLift extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Vertical rise on hover, in logical pixels.
  final double lift;

  /// Extra scale on hover (1.0 = off).
  final double hoverScale;

  /// When set, the border animates to this color on hover.
  final Color? hoverBorder;

  /// Corner radius — used for the ink splash and press rounding.
  final double radius;

  const HoverLift({
    super.key,
    required this.child,
    this.onTap,
    this.lift = 2,
    this.hoverScale = 1.0,
    this.hoverBorder,
    this.radius = 14,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    if (!interactive) return widget.child;

    final dy =
        (_press ? -0.5 : (_hover ? -widget.lift : 0.0));
    final scale = (_hover ? widget.hoverScale : 1.0) *
        (_press ? 0.99 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _press = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _press = true),
        onTapUp: (_) => setState(() => _press = false),
        onTapCancel: () => setState(() => _press = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, dy, 0)..scale(scale),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: _hover
                  ? (widget.hoverBorder ?? AppPalette.primaryBorder)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: _hover
                ? AppShadow.card(opacity: AppPalette.dark ? 0.5 : 0.10)
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Press feedback: scales a tappable child down while pressed. Use for
/// chips, nav tabs and tile-like controls that already own their ink.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Hover tint for row-like items: animates the background to a soft fill
/// while the pointer is over the row (plus the standard ink splash).
class HoverFill extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color? hoverColor;

  const HoverFill({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 10,
    this.hoverColor,
  });

  @override
  State<HoverFill> createState() => _HoverFillState();
}

class _HoverFillState extends State<HoverFill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        decoration: BoxDecoration(
          color: _hover
              ? (widget.hoverColor ?? AppPalette.fill.withOpacity(0.85))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.radius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(widget.radius),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Entrance animation: fades + slides the child in, staggered by [index]
/// (60 ms per step, capped). Wrap list rows / cards so screens settle in
/// with a cascade instead of popping.
class StaggerIn extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration step;
  final double offset;

  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 55),
    this.offset = 14,
  });

  @override
  Widget build(BuildContext context) {
    final delayIndex = index.clamp(0, 9);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260) + step * delayIndex,
      curve: Interval(
        delayIndex == 0 ? 0 : (delayIndex * 0.08).clamp(0.0, 0.55),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Crossfade + slide used when the workspace switches sections. Old
/// content fades out in place; new content slides up a few pixels while
/// fading in.
class SectionFade extends StatelessWidget {
  final Object tag;
  final Widget child;

  const SectionFade({super.key, required this.tag, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topLeft,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) {
        final inAnim = Tween<Offset>(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: inAnim, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(tag), child: child),
    );
  }
}

/// Animated fraction bar used by KPI drill-downs and insights panels —
/// the fill animates from 0 to its target on first build.
class AnimatedBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;
  final Duration duration;

  const AnimatedBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 6,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: AppPalette.fill,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: t,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        ),
      ),
    );
  }
}
