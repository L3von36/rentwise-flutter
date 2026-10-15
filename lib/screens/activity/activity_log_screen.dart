import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../data/seed_data.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/top_bar.dart' show RichActivityText;
import '../../models/activity_entry.dart';

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
    final now = DateTime.now();
    final entries = state.filteredActivity;
    final dateLabel = DateFormat('EEEE, MMMM d').format(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChipLite(
                  icon: Icons.show_chart,
                  color: AppColors.primary,
                  bg: AppColors.primarySoft,
                  size: 40),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('Workspace / Activity Log'),
                    SizedBox(height: 4),
                    Text('Activity Log',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: AppColors.textDark)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('A transparent history of every employee action in the workspace.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppColors.textMuted)),
          const SizedBox(height: 22),

          // stat mini-cards
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth < 900 ? 2 : 4;
            const gap = 16.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _StatCard(
                    width: w,
                    dotColor: AppColors.primary,
                    value: '${Seed.actionsToday}',
                    label: 'actions today'),
                _StatCard(
                    width: w,
                    dotColor: AppColors.green,
                    value: '${Seed.rentalUpdates}',
                    label: 'rental updates'),
                _StatCard(
                    width: w,
                    dotColor: AppColors.amber,
                    value: '${Seed.paymentsRecorded}',
                    label: 'payments recorded'),
                _StatCard(
                    width: w,
                    dotColor: AppColors.purple,
                    value: '100%',
                    label: 'logged automatically'),
              ],
            );
          }),
          const SizedBox(height: 20),

          SectionCard(
            icon: Icons.show_chart,
            title: 'Today · $dateLabel',
            subtitle:
                'Every update is time-stamped and attached to the employee who made it.',
            action: PopupMenuButton<String>(
              tooltip: 'Filter activity',
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              onSelected: state.setActivityFilter,
              offset: const Offset(0, 8),
              itemBuilder: (_) => [
                for (final f in _filters)
                  PopupMenuItem(
                    value: f,
                    height: 38,
                    child: Row(
                      children: [
                        if (f == state.activityFilter)
                          const Icon(Icons.check_rounded,
                              size: 15, color: AppColors.primary)
                        else
                          const SizedBox(width: 15),
                        const SizedBox(width: 6),
                        Text(f,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: f == state.activityFilter
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: f == state.activityFilter
                                  ? AppColors.primary
                                  : AppColors.textBody,
                            )),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 16, color: AppColors.textBody),
                    SizedBox(width: 7),
                    Text('Filter activity',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBody)),
                  ],
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // active filter chips
                if (state.activityFilter != 'All') ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusBadge.custom(
                        label: state.activityFilter,
                        fg: AppColors.primary,
                        bg: AppColors.primarySoft,
                        dot: true,
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => state.setActivityFilter('All'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            border:
                                Border.all(color: AppColors.cardBorder),
                          ),
                          child: const Text('Clear filter',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // timeline
                ..._buildTimeline(entries),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text('No activity matches this filter.',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.5,
                              color: AppColors.textMuted)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTimeline(List<ActivityEntry> entries) {
    final widgets = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      widgets.add(_TimelineEntry(
        entry: entries[i],
        isLast: i == entries.length - 1,
      ));
    }
    return widgets;
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final Color dotColor;
  final String value;
  final String label;
  const _StatCard({
    required this.width,
    required this.dotColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadow.card(opacity: 0.04),
      ),
      child: Row(
        children: [
          Dot(color: dotColor, size: 8),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Timeline entry with connecting spine.
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
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.primaryTint, width: 3),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.cardBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(time,
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: AppColors.textFaint)),
                      const Spacer(),
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
                  const SizedBox(height: 6),
                  RichActivityText(body: entry.body, fontSize: 13.5),
                  const SizedBox(height: 4),
                  const Text('Workspace action · Riverside Events',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          color: AppColors.textFaint)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
