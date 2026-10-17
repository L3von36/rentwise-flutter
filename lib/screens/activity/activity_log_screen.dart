import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
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
    final now = DateTime.now();
    final entries = state.filteredActivity;
    final dateLabel = DateFormat('EEEE, MMMM d').format(now);

    return Padding(
      padding: EdgeInsets.fromLTRB(Density.pagePad(context), 18,
          Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChipLite(
                  icon: Icons.show_chart,
                  color: AppPalette.primary,
                  bg: AppPalette.primarySoft,
                  size: 40),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Workspace / Activity Log'),
                    const SizedBox(height: 4),
                    Text('Activity Log',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: Density.compact(context) ? 17 : 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: AppPalette.ink)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('A transparent history of every employee action in the workspace.',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppPalette.muted)),
          const SizedBox(height: 14),

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
                    dotColor: AppPalette.primary,
                    value: '${state.actionsTodayCount}',
                    label: 'actions today'),
                _StatCard(
                    width: w,
                    dotColor: AppPalette.green,
                    value: '${state.rentalUpdatesCount}',
                    label: 'rental updates'),
                _StatCard(
                    width: w,
                    dotColor: AppPalette.amber,
                    value: '${state.paymentsTodayCount}',
                    label: 'payments recorded'),
                _StatCard(
                    width: w,
                    dotColor: AppPalette.purple,
                    value: '100%',
                    label: 'logged automatically'),
              ],
            );
          }),
          const SizedBox(height: 14),

          SectionCard(
            icon: Icons.show_chart,
            title: 'Today · $dateLabel',
            subtitle:
                'Every update is time-stamped and attached to the employee who made it.',
            action: PopupMenuButton<String>(
              tooltip: 'Filter activity',
              color: AppPalette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
                side: BorderSide(color: AppPalette.stroke),
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
                          Icon(Icons.check_rounded,
                              size: 15, color: AppPalette.primary)
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
                                  ? AppPalette.primary
                                  : AppPalette.body,
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
                  border: Border.all(color: AppPalette.stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 16, color: AppPalette.body),
                    const SizedBox(width: 7),
                    Text('Filter activity',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.body)),
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
                        fg: AppPalette.primary,
                        bg: AppPalette.primarySoft,
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
                                Border.all(color: AppPalette.stroke),
                          ),
                          child: Text('Clear filter',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.muted)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // timeline
                ..._buildTimeline(entries),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text('No activity matches this filter.',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.5,
                              color: AppPalette.muted)),
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppPalette.stroke),
        boxShadow: AppShadow.card(opacity: 0.04),
      ),
      child: Row(
        children: [
          Dot(color: dotColor, size: 8),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: Density.compact(context) ? 15 : 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppPalette.ink)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppPalette.muted)),
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
    final ws = context.watch<WorkspaceState>().workspace;
    final wsLabel = ws.isEmpty ? 'Workspace' : ws;

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
                    color: AppPalette.raise,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppPalette.primaryTint, width: 3),
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
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(time,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: AppPalette.faint)),
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
                  Text('Workspace action · $wsLabel',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          color: AppPalette.faint)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
