import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/motion.dart';
import '../../widgets/top_bar.dart' show RichActivityText;
import '../../models/activity_entry.dart';
import '../../core/palette.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  static const List<String> _filters = [
    'All',
    'Rental',
    'Payment',
    'Order update',
    'Return',
    'Note',
    'New booking',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final compact = Density.compact(context);
    final entries = state.filteredActivity;

    // Newest first, grouped by calendar day — a bare time next to an
    // entry from yesterday read as "later today" before grouping.
    final sorted = [...entries]
      ..sort((a, b) => b.at.compareTo(a.at));
    final groups = <String, List<ActivityEntry>>{};
    for (final e in sorted) {
      groups.putIfAbsent(_dayLabel(e.at), () => []).add(e);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(Density.pagePad(context), 18,
          Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivityHero(
            today: state.actionsTodayCount,
            rentals: state.rentalUpdatesCount,
            payments: state.paymentsTodayCount,
          ),
          const SizedBox(height: 14),

          // Filter chips — always visible, one horizontal swipe away.
          _FilterChips(
            filters: _filters,
            selected: state.activityFilter,
            onSelected: state.setActivityFilter,
          ),
          const SizedBox(height: 14),

            if (entries.isEmpty)
            _EmptyTimeline(filter: state.activityFilter)
          else
            for (final day in groups.keys) ...[
              SectionCard(
                icon: Icons.show_chart,
                title: day,
                subtitle: '${groups[day]!.length} '
                    '${groups[day]!.length == 1 ? 'update' : 'updates'}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._buildTimeline(groups[day]!),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          if (compact) const SizedBox(height: 6),
        ],
      ),
    );
  }

  List<Widget> _buildTimeline(List<ActivityEntry> entries) {
    return [
      for (var i = 0; i < entries.length; i++)
        StaggerIn(
          index: i,
          child: _TimelineEntry(
            entry: entries[i],
            isLast: i == entries.length - 1,
          ),
        ),
    ];
  }
}

// ---------------------------------------------------------------- hero

/// Gradient hero — same language as Reports / Access / Notifications:
/// glass icon tile, white headline and translucent stats.
class _ActivityHero extends StatelessWidget {
  final int today;
  final int rentals;
  final int payments;

  const _ActivityHero({
    required this.today,
    required this.rentals,
    required this.payments,
  });

  @override
  Widget build(BuildContext context) {
    final compact = Density.compact(context);

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
          child: const Icon(Icons.show_chart,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Text('Activity Log',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      ],
    );

    final statRow = Row(
      children: [
        Expanded(
            child: _HeroStat(value: '$today', label: 'Actions')),
        const SizedBox(width: 10),
        Expanded(
            child: _HeroStat(value: '$rentals', label: 'Rentals')),
        const SizedBox(width: 10),
        Expanded(
            child: _HeroStat(value: '$payments', label: 'Payments')),
      ],
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
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headline,
                const SizedBox(height: 14),
                statRow,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 5, child: headline),
                const SizedBox(width: 18),
                SizedBox(width: 280, child: statRow),
              ],
            ),
    );
  }
}

/// Translucent stat tile used inside the activity hero.
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
          // Safety net: values scale down instead of wrapping.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                maxLines: 1,
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
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

// ---------------------------------------------------------------- filter

/// Horizontal chip strip — replaces the old popup-menu filter, which
/// hid the most-used control one tap too deep on phones.
class _FilterChips extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final active = f == selected;
          return PressableScale(
            onTap: () => onSelected(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppPalette.primarySoft : AppPalette.surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                    color:
                        active ? AppPalette.primaryBorder : AppPalette.stroke),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active) ...[
                    Dot(color: AppPalette.primary, size: 6),
                    const SizedBox(width: 6),
                  ],
                  Text(f,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: active
                              ? AppPalette.primary
                              : AppPalette.body)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- timeline

/// Timeline entry with connecting spine. The dot is tinted with the
/// entry type so the day reads as colored rhythm, not gray static.
class _TimelineEntry extends StatelessWidget {
  final ActivityEntry entry;
  final bool isLast;
  const _TimelineEntry({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final h = entry.at.hour % 12 == 0 ? 12 : entry.at.hour % 12;
    final ampm = entry.at.hour >= 12 ? 'PM' : 'AM';
    final m = entry.at.minute.toString().padLeft(2, '0');
    final time = '$h:$m $ampm';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // spine
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: entry.type.fg.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: entry.type.fg, width: 2.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppPalette.stroke,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichActivityText(body: entry.body, fontSize: 13.5),
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
                    fontSize: 11,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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

/// Friendly empty state (no entries at all, or nothing after filtering).
class _EmptyTimeline extends StatelessWidget {
  final String filter;
  const _EmptyTimeline({required this.filter});

  @override
  Widget build(BuildContext context) {
    final filtered = filter != 'All';
    return SectionCard(
      icon: Icons.show_chart,
      title: filtered ? 'Nothing matches "$filter"' : 'No activity yet',
      subtitle: filtered
          ? 'Try another filter or clear it to see the full log.'
          : 'Actions will appear here as your team works.',
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
                child: Icon(
                    filtered
                        ? Icons.filter_alt_off_outlined
                        : Icons.history_rounded,
                    size: 26,
                    color: AppPalette.primary),
              ),
              const SizedBox(height: 12),
              Text(filtered ? 'No "$filter" entries' : 'A fresh start',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.ink)),
              const SizedBox(height: 4),
              Text(
                'Every rental, payment and note lands in this '
                'log automatically — nothing to write by hand.',
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
