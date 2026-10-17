import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/rental_order.dart';
import '../../models/shift_task.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/detail_page.dart';
import '../../widgets/filters.dart';
import '../../widgets/motion.dart';
import '../calendar/calendar_screen.dart';
import '../orders/order_detail_screen.dart';
import '../../core/palette.dart';

/// Entry point used by the dashboard task list and KPI cards.
void openTasks(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const TasksScreen()));
}

/// The full shift task board — every actionable item for the day, with
/// filters, real status transitions and deep links into the source order
/// or the calendar. Opened from the dashboard task list.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String? _kind; // null = all buckets

  static const _filters = [
    ('All', null),
    ('Prep', 'prep'),
    ('Deliveries', 'delivery'),
    ('Payments', 'payment'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final now = DateTime.now();
    final tasks = state.shiftTasks(now);
    final filtered =
        _kind == null ? tasks : tasks.where((t) => t.kind == _kind).toList();

    return DetailPage(
      eyebrow: 'Workspace / Tasks',
      title: 'Shift tasks',
      subtitle:
          '${tasks.length} on deck · ordered by priority — work top to bottom.',
      icon: Icons.checklist_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // summary strip
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SummaryChip(
                  label: 'Prep',
                  count: tasks.where((t) => t.kind == 'prep').length,
                  color: AppPalette.amber),
              _SummaryChip(
                  label: 'On the road',
                  count: tasks.where((t) => t.kind == 'delivery').length,
                  color: AppPalette.blue),
              _SummaryChip(
                  label: 'Payments',
                  count: tasks.where((t) => t.kind == 'payment').length,
                  color: AppPalette.purple),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            icon: Icons.checklist_rounded,
            title: 'Your task list',
            subtitle: filtered.isEmpty
                ? 'Nothing in this bucket — all clear.'
                : 'Tap a task to open its order, or advance it with the action button.',
            action: LinkChip(
              label: 'Open calendar',
              onTap: () => openCalendar(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (label, kind) in _filters)
                      _FilterPill(
                        label: label,
                        count: kind == null
                            ? tasks.length
                            : tasks.where((t) => t.kind == kind).length,
                        selected: _kind == kind,
                        onTap: () => setState(() => _kind = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      children: [
                        Icon(Icons.verified_outlined,
                            size: 18, color: AppPalette.green),
                        const SizedBox(width: 8),
                        Text('All clear — every task is done for today.',
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                color: AppPalette.muted)),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < filtered.length; i++)
                        StaggerIn(
                          index: i,
                          child: _TaskCard(
                            task: filtered[i],
                            index: i,
                            isLast: i == filtered.length - 1,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One task row: opens the source order (or calendar) on tap; the
/// trailing action button advances the underlying order where a real
/// next step exists.
class _TaskCard extends StatelessWidget {
  final ShiftTask task;
  final int index;
  final bool isLast;

  const _TaskCard({
    required this.task,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final order = task.orderId == null ? null : state.orderById(task.orderId!);
    final isFirst = index == 0;
    final next = order == null ? null : _nextFor(task.kind, order.status);

    return HoverFill(
      onTap: () => _openSource(context),
      radius: 11,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                vertical: isFirst ? 10 : 11, horizontal: 10),
            decoration: isFirst
                ? BoxDecoration(
                    color: AppPalette.primarySoft.withOpacity(0.42),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: AppPalette.primaryBorder.withOpacity(0.55)),
                  )
                : null,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color:
                            isFirst ? AppPalette.primary : AppPalette.faint),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isFirst
                            ? AppPalette.primary.withOpacity(0.8)
                            : AppPalette.faint.withOpacity(0.6),
                        width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.ink)),
                      const SizedBox(height: 2),
                      Text(task.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11.5,
                              color: AppPalette.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge.custom(
                    label: task.chip, fg: task.chipFg, bg: task.chipBg),
                const SizedBox(width: 6),
                if (next != null)
                  _AdvanceButton(order: order!, next: next, label: _labelFor(next))
                else
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppPalette.faint),
              ],
            ),
          ),
          if (!isLast)
            const Padding(
              padding: EdgeInsets.only(left: 46),
              child: Divider(height: 14),
            ),
        ],
      ),
    );
  }

  void _openSource(BuildContext context) {
    if (task.orderId != null) {
      final state = context.read<WorkspaceState>();
      final order = state.orderById(task.orderId!);
      if (order != null) {
        openOrderDetail(context, order);
        return;
      }
    }
    openCalendar(context);
  }

  /// The real next step this task kind can advance the order to.
  OrderStatus? _nextFor(String kind, OrderStatus status) => switch (kind) {
        'delivery' => OrderStatus.needsPayment,
        'payment' => OrderStatus.confirmed,
        _ => null,
      };

  String _labelFor(OrderStatus next) => switch (next) {
        OrderStatus.needsPayment => 'Delivered',
        OrderStatus.confirmed => 'Mark paid',
        _ => 'Advance',
      };
}

/// The indigo “do it now” button on a task row — performs the real
/// status write for the task kind.
class _AdvanceButton extends StatelessWidget {
  final RentalOrder order;
  final OrderStatus next;
  final String label;

  const _AdvanceButton({
    required this.order,
    required this.next,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<WorkspaceState>();
    return PressableScale(
      onTap: () {
        state.updateOrderStatus(order, next);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${order.id} marked “${next.label}”'),
          behavior: SnackBarBehavior.floating,
        ));
      },
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppPalette.primarySoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppPalette.primaryBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 13, color: AppPalette.primary),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.primary)),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.fill.withOpacity(0.7),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppPalette.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Dot(color: color),
          const SizedBox(width: 6),
          Text('$count $label',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.body)),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Material(
        color: selected
            ? AppPalette.primarySoft
            : AppPalette.fill.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected
                      ? AppPalette.primaryBorder
                      : Colors.transparent),
            ),
            child: Text(
              count == 0 ? label : '$label · $count',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color:
                      selected ? AppPalette.primaryDeep : AppPalette.body),
            ),
          ),
        ),
      ),
    );
  }
}
