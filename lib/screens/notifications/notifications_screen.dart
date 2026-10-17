import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/activity_entry.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/detail_page.dart';
import '../../widgets/motion.dart';
import '../../widgets/top_bar.dart' show RichActivityText;
import '../../core/palette.dart';

/// Where a notification row leads when tapped.
Section _targetFor(ActivityType type) => switch (type) {
      ActivityType.payment => Section.orders,
      ActivityType.orderUpdate => Section.orders,
      ActivityType.newBooking => Section.orders,
      ActivityType.rental => Section.inventory,
      ActivityType.returnItem => Section.inventory,
      ActivityType.note => Section.activity,
    };

/// Full notifications page — the “View all” destination of the bell
/// dialog. Tapping a row jumps to the workspace area it belongs to and
/// marks everything read.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final entries = state.activity;

    return DetailPage(
      eyebrow: 'Workspace / Notifications',
      title: 'Notifications',
      subtitle:
          'Everything happening in the workspace, newest first — tap a row to jump there.',
      icon: Icons.notifications_none_rounded,
      actions: [
        OutlineButton(
          label: 'Mark all read',
          icon: Icons.done_all_rounded,
          onTap: entries.isEmpty || state.unreadActivity == 0
              ? null
              : () {
                  context.read<WorkspaceState>().markActivityRead();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('All notifications marked as read'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle_notifications_outlined,
                  size: 16, color: AppPalette.primary),
              const SizedBox(width: 7),
              Text(
                state.unreadActivity == 0
                    ? 'You are all caught up'
                    : '${state.unreadActivity} unread update(s)',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: state.unreadActivity == 0
                        ? AppPalette.green
                        : AppPalette.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            icon: Icons.notifications_none_rounded,
            title: 'Activity feed',
            subtitle: '${entries.length} update(s) in this workspace.',
            child: entries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text('Nothing has happened yet today.',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.5,
                            color: AppPalette.muted)),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        StaggerIn(
                          index: i,
                          child: HoverFill(
                            onTap: () => _open(context, entries[i]),
                            child: _NotificationRow(
                                entry: entries[i],
                                showDivider: i < entries.length - 1),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, ActivityEntry entry) {
    final section = _targetFor(entry.type);
    // close the detail page, then land on the mapped section
    Navigator.of(context).pop();
    context.read<WorkspaceState>().navigate(section);
  }
}

// ---------------------------------------------------------------- row
class _NotificationRow extends StatelessWidget {
  final ActivityEntry entry;
  final bool showDivider;

  const _NotificationRow({required this.entry, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final time = _timeLabel(entry.at);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialsAvatar(
              initials: entry.actorInitials,
              color: entry.actorColor,
              size: 30,
              fontSize: 11),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichActivityText(body: entry.body),
                const SizedBox(height: 4),
                Text(time,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: AppPalette.faint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge.custom(
            label: entry.type.label,
            fg: entry.type.fg,
            bg: entry.type.bg,
            fontSize: 10.5,
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 16, color: AppPalette.faint),
        ],
      ),
    );
  }
}

String _timeLabel(DateTime at) {
  final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final ampm = at.hour >= 12 ? 'PM' : 'AM';
  final m = at.minute.toString().padLeft(2, '0');
  return '$h:$m $ampm';
}

/// Entry point for the bell dialog’s “View all”.
void openNotifications(BuildContext context) {
  Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
}
