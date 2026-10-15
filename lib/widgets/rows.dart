import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../models/activity_entry.dart';
import '../models/pickup.dart';
import 'chips.dart';
import 'top_bar.dart' show RichActivityText;

/// Avatar + rich text + time + type badge row (dashboard feed & activity log).
class ActivityRow extends StatelessWidget {
  final ActivityEntry entry;
  final bool showTimeAbove;
  final bool showDivider;

  const ActivityRow({
    super.key,
    required this.entry,
    this.showTimeAbove = false,
    this.showDivider = true,
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
          size: 34,
          fontSize: 12,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTimeAbove)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(time,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppColors.textFaint,
                      )),
                ),
              RichActivityText(body: entry.body),
              if (!showTimeAbove) ...[
                const SizedBox(height: 4),
                Text(time,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      color: AppColors.textFaint,
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
          fontSize: 11,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        ),
      ],
    );

    if (!showDivider) return row;
    return Column(
      children: [
        row,
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 14),
      ],
    );
  }
}

String _timeLabel(DateTime at) {
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final ampm = at.hour >= 12 ? 'PM' : 'AM';
  final m = at.minute.toString().padLeft(2, '0');
  return '$h:$m $ampm';
}

/// "18 OCT" date block + title + venue + "In N days" (upcoming pickups).
class PickupRow extends StatelessWidget {
  final Pickup pickup;
  final DateTime now;
  final bool showDivider;

  const PickupRow({
    super.key,
    required this.pickup,
    required this.now,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    String inDays;
    final diff = DateTime(pickup.date.year, pickup.date.month, pickup.date.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    inDays = diff <= 0 ? 'Today' : 'In $diff days';

    final content = Row(
      children: [
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.subtleFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Text('${pickup.date.day}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    height: 1.1,
                  )),
              Text(
                _monthUpper(pickup.date),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  )),
              const SizedBox(height: 2),
              Text('${pickup.venue} · ${pickup.itemCount} items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppColors.textMuted,
                  )),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(inDays,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            )),
      ],
    );

    if (!showDivider) return content;
    return Column(
      children: [
        content,
        const SizedBox(height: 13),
        const Divider(),
        const SizedBox(height: 13),
      ],
    );
  }
}

String _monthUpper(DateTime d) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];
  return months[d.month - 1];
}
