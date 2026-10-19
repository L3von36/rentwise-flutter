import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/density.dart';
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
    final unread = state.unreadActivity;
    final compact = Density.compact(context);

    // Newest first, grouped by calendar day.
    final sorted = [...entries]
      ..sort((a, b) => b.at.compareTo(a.at));
    final groups = <String, List<ActivityEntry>>{};
    for (final e in sorted) {
      groups.putIfAbsent(_dayLabel(e.at), () => []).add(e);
    }

    return DetailPage(
      eyebrow: 'Workspace / Notifications',
      title: 'Notifications',
      icon: Icons.notifications_none_rounded,
      showIcon: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotificationsHero(
            unread: unread,
            today: state.actionsTodayCount,
            total: entries.length,
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const _EmptyFeed()
          else ...[
            for (final day in groups.keys) ...[
              SectionCard(
                icon: Icons.notifications_none_rounded,
                title: day,
                subtitle:
                    '${groups[day]!.length} update(s) — newest first. '
                    'Tap one to jump there.',
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(
                  children: [
                    for (var i = 0; i < groups[day]!.length; i++)
                      StaggerIn(
                        index: i,
                        child: HoverFill(
                          onTap: () => _open(context, groups[day]![i]),
                          child: _NotificationRow(
                              entry: groups[day]![i],
                              showDivider:
                                  i < groups[day]!.length - 1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
          if (compact) const SizedBox(height: 6),
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

// ---------------------------------------------------------------- hero

/// Gradient hero — mirrors the Reports / Access hero language: glass icon
/// tile, white headline, live status line and translucent stat tiles.
class _NotificationsHero extends StatelessWidget {
  final int unread;
  final int today;
  final int total;

  const _NotificationsHero({
    required this.unread,
    required this.today,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final compact = Density.compact(context);
    final state = context.read<WorkspaceState>();

    final headline = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: const Icon(Icons.notifications_none_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifications',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 3),
              Text(
                unread == 0
                    ? 'You are all caught up'
                    : '$unread unread update${unread == 1 ? '' : 's'} '
                        'waiting',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    color: Colors.white.withOpacity(0.82)),
              ),
            ],
          ),
        ),
        // LIVE pulse — same language as the dashboard / reports badges.
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(99),
            border:
                Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: AppPalette.greenBar, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              const Text('LIVE',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Colors.white)),
            ],
          ),
        ),
      ],
    );

    final stats = Row(
      children: [
        Expanded(
            child: _HeroStat(
                value: '$unread', label: 'Unread')),
        const SizedBox(width: 10),
        Expanded(
            child: _HeroStat(value: '$today', label: 'Today')),
        const SizedBox(width: 10),
        Expanded(
            child: _HeroStat(value: '$total', label: 'All time')),
      ],
    );

    final cta = _HeroAction(
      label: unread == 0 ? 'All read' : 'Mark all read',
      enabled: unread > 0,
      onTap: unread == 0
          ? null
          : () {
              state.markActivityRead();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('All notifications marked as read'),
                behavior: SnackBarBehavior.floating,
              ));
            },
    );

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppPalette.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLg),
        boxShadow:
            AppShadow.card(opacity: AppPalette.dark ? 0.5 : 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headline,
          const SizedBox(height: 14),
          stats,
          const SizedBox(height: 12),
          compact
              ? SizedBox(width: double.infinity, child: cta)
              : SizedBox(width: 190, child: cta),
        ],
      ),
    );
  }
}

/// Translucent stat tile inside the notifications hero.
class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 1),
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.white.withOpacity(0.72))),
        ],
      ),
    );
  }
}

/// Translucent white action button for use on the gradient hero.
class _HeroAction extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  const _HeroAction(
      {required this.label, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: PressableScale(
        onTap: onTap,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.white.withOpacity(0.18)
                    : Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.white.withOpacity(0.28)),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.done_all_rounded,
                      size: 15, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(label,
                      style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- row
class _NotificationRow extends StatelessWidget {
  final ActivityEntry entry;
  final bool showDivider;

  const _NotificationRow({required this.entry, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconChipLite(
              icon: entry.type.icon,
              color: entry.type.fg,
              bg: entry.type.bg,
              size: 32),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichActivityText(body: entry.body),
                const SizedBox(height: 3),
                Text(_timeLabel(entry.at),
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

/// "Today" / "Yesterday" / "Oct 17" group label for an entry timestamp.
String _dayLabel(DateTime at) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(at.year, at.month, at.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[at.month - 1]} ${at.day}';
}

/// Friendly empty state when nothing has been logged yet.
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.notifications_none_rounded,
      title: 'Nothing yet',
      subtitle: 'Workspace actions will appear here as they happen.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.done_all_rounded,
                    size: 26, color: AppPalette.primary),
              ),
              const SizedBox(height: 12),
              Text('You are all caught up',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.ink)),
              const SizedBox(height: 4),
              Text(
                'Rentals, payments and returns will show up '
                'here the moment your team logs them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppPalette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry point for the bell dialog’s “View all”.
void openNotifications(BuildContext context) {
  Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
}
