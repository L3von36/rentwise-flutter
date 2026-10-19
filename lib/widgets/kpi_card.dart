import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/density.dart';
import 'cards.dart';
import 'motion.dart';
import '../core/palette.dart';

/// The 4-up metric card used on Dashboard / Inventory / Orders / Customers.
/// With [onTap] set it becomes a live drill-in: hover lift + press + ink.
class KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: onTap != null ? AppPalette.stroke : AppPalette.stroke),
        boxShadow: AppShadow.card(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChipLite(icon: icon, color: iconColor, bg: iconBg),
              if (trailing != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: trailing!,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppPalette.body,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: Density.compact(context) ? 18 : 21,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 16,
                      color: AppPalette.faint),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11.5,
              color: AppPalette.muted,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return HoverLift(
      onTap: onTap,
      radius: AppRadius.card,
      lift: 2,
      child: card,
    );
  }
}

/// Horizontal phone strip of KPI tiles with a built-in scroll affordance.
///
/// Tiles keep a fixed readable [tileWidth] instead of being squeezed into
/// thirds. When the row overflows the viewport it becomes swipeable and a
/// soft edge fade + partial "peek" of the next tile hint at the hidden
/// content; when everything fits, tiles expand to share the width exactly
/// like a plain [Row] of [Expanded]s.
class KpiStrip extends StatefulWidget {
  final List<Widget> children;
  final double tileWidth;
  final double gap;

  const KpiStrip({
    super.key,
    required this.children,
    this.tileWidth = 124,
    this.gap = 12,
  });

  @override
  State<KpiStrip> createState() => _KpiStripState();
}

class _KpiStripState extends State<KpiStrip> {
  final _controller = ScrollController();
  double _offset = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.horizontal) return false;
    if ((_offset - n.metrics.pixels).abs() < 0.5) return false;
    setState(() => _offset = n.metrics.pixels);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, c) {
      final n = widget.children.length;
      final gap = widget.gap;
      final fits =
          n * widget.tileWidth + (n - 1) * gap <= c.maxWidth + 0.5;

      // Everything fits: expand tiles to share the width — same look as
      // the old Expanded row, no scroll, no affordance.
      if (fits) {
        return Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(width: gap),
              Expanded(child: widget.children[i]),
            ],
          ],
        );
      }

      // Overflow: fixed-width tiles in a swipeable strip. The next tile
      // peeks past the right edge and a gradient fade marks the scroll.
      final maxOffset = n * widget.tileWidth + (n - 1) * gap - c.maxWidth;
      final canRight = _offset < maxOffset - 0.5;
      final canLeft = _offset > 0.5;

      return NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: [
                  for (var i = 0; i < n; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(
                        width: widget.tileWidth, child: widget.children[i]),
                  ],
                ],
              ),
            ),
            // Right fade — "there is more" affordance.
            if (canRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppPalette.canvas.withOpacity(0),
                          AppPalette.canvas.withOpacity(0.9),
                        ],
                        stops: const [0, 1],
                      ),
                    ),
                  ),
                ),
              ),
            // Left fade — appears once scrolled so users can find their
            // way back.
            if (canLeft)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 20,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          AppPalette.canvas.withOpacity(0),
                          AppPalette.canvas.withOpacity(0.9),
                        ],
                        stops: const [0, 1],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// Compact KPI tile for the mobile "Today at a glance" strip.
class KpiTileMini extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const KpiTileMini({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.stroke),
        boxShadow: AppShadow.card(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconChipLite(icon: icon, color: iconColor, bg: iconBg, size: 26),
              if (trailing != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: trailing!,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: AppPalette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: Density.compact(context) ? 16 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              color: AppPalette.faint,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return tile;
    return HoverLift(onTap: onTap, radius: 12, lift: 1.5, child: tile);
  }
}
