import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/activity_entry.dart';
import '../models/pickup.dart';
import 'chips.dart';
import 'motion.dart';
import 'top_bar.dart' show RichActivityText;
import '../core/palette.dart';

/// Avatar + rich text + time + type badge row (dashboard feed & activity log).
/// With [onTap] set the whole row is tappable with a hover fill.
class ActivityRow extends StatelessWidget {
  final ActivityEntry entry;
  final bool showTimeAbove;
  final bool showDivider;
  final VoidCallback? onTap;

  const ActivityRow({
    super.key,
    required this.entry,
    this.showTimeAbove = false,
    this.showDivider = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time = _timeLabel(entry.at);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialsAvatar(
          initials: entry.actorInitials,
          color: entry.actorColor,
          size: 30,
          fontSize: 11,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTimeAbove)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(time,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: AppPalette.faint,
                      )),
                ),
              RichActivityText(body: entry.body),
              if (!showTimeAbove) ...[
                const SizedBox(height: 4),
                Text(time,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppPalette.faint,
                    )),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        StatusBadge.custom(
          label: entry.type.label,
          fg: entry.type.fg,
          bg: entry.type.bg,
          fontSize: 10.5,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
              size: 15, color: AppPalette.faint),
        ],
      ],
    );

    final wrapped = onTap == null
        ? row
        : HoverFill(onTap: onTap, radius: 9, child: row);

    if (!showDivider) return wrapped;
    return Column(
      children: [
        wrapped,
        const SizedBox(height: 11),
        const Divider(),
        const SizedBox(height: 11),
      ],
    );
  }
}

String _timeLabel(DateTime at) => Fmt.timeOfDay(at);

/// "18 OCT" date block + title + venue + "In N days" (upcoming pickups).
/// With [onTap] set the whole row opens its target (the calendar).
class PickupRow extends StatelessWidget {
  final Pickup pickup;
  final DateTime now;
  final bool showDivider;
  final VoidCallback? onTap;

  const PickupRow({
    super.key,
    required this.pickup,
    required this.now,
    this.showDivider = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String inDays;
    inDays = Fmt.inDays(pickup.date, now);

    final content = Row(
      children: [
        Container(
          width: 38,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppPalette.fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppPalette.stroke),
          ),
          child: Column(
            children: [
              Text(Fmt.dayNumber(pickup.date),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.ink,
                    height: 1.1,
                  )),
              Text(
                Fmt.monthUpper(pickup.date),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppPalette.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  )),
              const SizedBox(height: 2),
              Text('${pickup.venue} · ${Fmt.items(pickup.itemCount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppPalette.muted,
                  )),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(inDays,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppPalette.muted,
            )),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
              size: 15, color: AppPalette.faint),
        ],
      ],
    );

    final wrapped = onTap == null
        ? content
        : HoverFill(onTap: onTap, radius: 9, child: content);

    if (!showDivider) return wrapped;
    return Column(
      children: [
        wrapped,
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
      ],
    );
  }
}

