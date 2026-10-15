import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../data/seed_data.dart';
import '../../models/inventory_item.dart';
import '../../models/rental_order.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/inventory_views.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/rows.dart';
import '../../screens/booking/new_booking_sheet.dart';
import '../../screens/inventory/item_adjust_dialog.dart';
import '../../widgets/filters.dart';
import '../../widgets/indicators.dart';

/// Role-aware home screen.
///
/// Owners get the **business pulse** — revenue, utilization, receivables,
/// trend and health. Employees get **their shift** — task list, dispatch
/// runs, quick actions and their own logged actions. Both roles ship a
/// wide (sidebar) layout and a compact (phone) layout.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 950;
    final now = DateTime.now();

    if (state.isOwner) {
      return compact
          ? _OwnerCompactDashboard(state: state, now: now)
          : _OwnerWideDashboard(state: state, now: now);
    }
    return _EmployeeDashboard(state: state, now: now, compact: compact);
  }
}

// ------------------------------------------------------------ role helpers

String _greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _firstName(WorkspaceState state) =>
    state.account?.name.split(' ').first ?? 'there';

/// One actionable item on the employee's shift task list.
class _ShiftTask {
  final String title;
  final String meta;
  final String chip;
  final Color chipFg;
  final Color chipBg;
  const _ShiftTask(this.title, this.meta, this.chip, this.chipFg, this.chipBg);
}

/// Derives today's task feed from live order + pickup data.
List<_ShiftTask> _shiftTasks(WorkspaceState state, DateTime now) {
  final tasks = <_ShiftTask>[];
  for (final o in state.orders) {
    switch (o.status) {
      case OrderStatus.preparing:
        tasks.add(_ShiftTask(
          'Stage & pack',
          '#${o.id} · ${o.eventName} · ${o.itemCount} items',
          'Prep',
          AppColors.amber,
          AppColors.amberBg,
        ));
      case OrderStatus.outForDelivery:
        tasks.add(_ShiftTask(
          'Confirm delivery',
          '#${o.id} · ${o.eventName} · ${o.contactName}',
          'On the road',
          AppColors.blue,
          AppColors.blueBg,
        ));
      case OrderStatus.needsPayment:
        tasks.add(_ShiftTask(
          'Collect payment',
          '#${o.id} · ${o.eventName} · \$${o.total.toStringAsFixed(0)}',
          'Payment',
          AppColors.purple,
          AppColors.purpleBg,
        ));
      case OrderStatus.confirmed:
      case OrderStatus.returned:
        break;
    }
  }
  final df = DateFormat('EEE, MMM d');
  for (final p in state.pickups.take(2)) {
    tasks.add(_ShiftTask(
      'Pull & stage',
      '${p.itemCount} items · ${p.venue} · ${df.format(p.date)}',
      'Upcoming',
      AppColors.green,
      AppColors.greenBg,
    ));
  }
  return tasks;
}

// ======================================================= employee dashboard
/// Task-first home for operations staff. Wide: 4-up task KPIs + task list,
/// dispatch runs, quick actions and personal activity in a 2-column grid.
/// Compact: shift banner + mini KPI strip + stacked cards.
class _EmployeeDashboard extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;
  final bool compact;

  const _EmployeeDashboard({
    required this.state,
    required this.now,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = _shiftTasks(state, now);
    final wide = !compact;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          Density.pagePad(context), 16, Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(wide
                        ? '${DateFormat('EEEE, MMMM d, yyyy').format(now)} · Shift 9:00 AM – 6:00 PM'
                        : DateFormat('EEEE, MMMM d').format(now)),
                    const SizedBox(height: 5),
                    Text('${_greeting(now)}, ${_firstName(state)}',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    Text(
                      tasks.isEmpty
                          ? 'You are all caught up — nothing pending today.'
                          : 'You have ${tasks.length} tasks on deck today, '
                              'including ${Seed.returnsDueToday} returns due back.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 16),
                OutlineButton(
                  label: 'Check-in return',
                  icon: Icons.assignment_turned_in_outlined,
                  onTap: () => state.navigate(Section.orders),
                ),
                const SizedBox(width: 10),
                PrimaryButton(
                  label: 'New rental booking',
                  icon: Icons.add_rounded,
                  onTap: () => showNewBookingSheet(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ---- shift banner (compact only)
          if (compact) ...[
            _ShiftBanner(taskCount: tasks.length),
            const SizedBox(height: 14),
          ],

          // ---- KPIs
          if (wide)
            LayoutBuilder(builder: (context, c) {
              const cols = 4;
              const gap = 12.0;
              final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: cardW,
                    child: KpiCard(
                      icon: Icons.checklist_rounded,
                      iconColor: AppColors.primary,
                      iconBg: AppColors.primarySoft,
                      label: 'Tasks on deck',
                      value: '${tasks.length}',
                      subtitle:
                          'Pickups, deliveries & check-ins',
                      trailing: const TrendChip.flat(text: 'Today'),
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: KpiCard(
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppColors.blue,
                      iconBg: AppColors.blueBg,
                      label: 'Out for delivery',
                      value: '${state.outForDeliveryCount}',
                      subtitle:
                          'Next: ${Seed.nextDispatchVenue} · ${Seed.nextDispatchTime}',
                      trailing: const TrendChip.flat(text: 'Live'),
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: const KpiCard(
                      icon: Icons.assignment_return_outlined,
                      iconColor: AppColors.amber,
                      iconBg: AppColors.amberBg,
                      label: 'Returns to check in',
                      value: '${Seed.pendingReturns}',
                      subtitle: 'Keep an eye on 3 late items',
                      trailing: TrendChip(
                          text: '${Seed.returnsDueToday} due',
                          positive: false),
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: KpiCard(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.purple,
                      iconBg: AppColors.purpleBg,
                      label: 'To stage & pack',
                      value: '${state.preparingCount}',
                      subtitle: state.preparingCount > 0
                          ? '${state.orders.firstWhere((o) => o.status == OrderStatus.preparing).eventName} · ${Seed.nextDispatchItems} items'
                          : 'Queue is clear',
                      trailing: const TrendChip.flat(text: 'Queue'),
                    ),
                  ),
                ],
              );
            })
          else
            SizedBox(
              height: 122,
              child: Row(
                children: [
                  Expanded(
                    child: KpiTileMini(
                      icon: Icons.checklist_rounded,
                      iconColor: AppColors.primary,
                      iconBg: AppColors.primarySoft,
                      label: 'Tasks due',
                      value: '${tasks.length}',
                      subtitle: 'today',
                      trailing: const TrendChip.flat(text: 'Shift'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiTileMini(
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppColors.blue,
                      iconBg: AppColors.blueBg,
                      label: 'On delivery',
                      value: '${state.outForDeliveryCount}',
                      subtitle: 'on the road',
                      trailing: const TrendChip.flat(text: 'Live'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: KpiTileMini(
                      icon: Icons.assignment_return_outlined,
                      iconColor: AppColors.amber,
                      iconBg: AppColors.amberBg,
                      label: 'Returns',
                      value: '${Seed.pendingReturns}',
                      subtitle: 'to check in',
                      trailing: TrendChip(
                          text: '${Seed.returnsDueToday} due',
                          positive: false),
                    ),
                  ),
                ],
              ),
            ),

          // ---- main content
          if (wide) ...[
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 12,
                    child: Column(
                      children: [
                        _TaskListCard(state: state, tasks: tasks),
                        const SizedBox(height: 20),
                        _DispatchCard(state: state),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _QuickActionsCard(state: state),
                        const SizedBox(height: 20),
                        _MyActivityCard(state: state, limit: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            _TaskListCard(state: state, tasks: tasks, limit: 4),
            const SizedBox(height: 14),
            _QuickActionsCard(state: state),
            const SizedBox(height: 14),
            _MyActivityCard(state: state, limit: 3),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------- shift banner (m)
class _ShiftBanner extends StatelessWidget {
  final int taskCount;
  const _ShiftBanner({required this.taskCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withOpacity(0.55),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.timelapse_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 9),
          Text('$taskCount tasks on deck',
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDeep)),
          const SizedBox(width: 12),
          Container(width: 1, height: 14, color: AppColors.primaryBorder),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Shift runs 9:00 AM – 6:00 PM',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppColors.textBody)),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.primary),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ task list
class _TaskListCard extends StatelessWidget {
  final WorkspaceState state;
  final List<_ShiftTask> tasks;
  final int? limit;

  const _TaskListCard({required this.state, required this.tasks, this.limit});

  @override
  Widget build(BuildContext context) {
    final shown = limit == null ? tasks : tasks.take(limit!).toList();
    return SectionCard(
      icon: Icons.checklist_rounded,
      title: 'Your task list',
      subtitle: tasks.isEmpty
          ? 'Nothing pending — nice work.'
          : 'Ordered by priority — work top to bottom.',
      action: LinkChip(
        label: 'Open orders',
        onTap: () => state.navigate(Section.orders),
      ),
      child: tasks.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined,
                      size: 18, color: AppColors.green),
                  SizedBox(width: 8),
                  Text('All clear — every task is done for today.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppColors.textMuted)),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  _TaskRow(
                    task: shown[i],
                    showDivider: i < shown.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final _ShiftTask task;
  final bool showDivider;

  const _TaskRow({required this.task, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.textFaint.withOpacity(0.6), width: 1.5),
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
                        style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(task.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11.5,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge.custom(
                  label: task.chip, fg: task.chipFg, bg: task.chipBg),
            ],
          ),
          if (showDivider)
            const Padding(
              padding: EdgeInsets.only(left: 28),
              child: Divider(height: 18),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- dispatch
class _DispatchCard extends StatelessWidget {
  final WorkspaceState state;
  const _DispatchCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final prep = state.orders
        .where((o) => o.status == OrderStatus.preparing)
        .toList();
    final df = DateFormat('EEE, MMM d');
    return SectionCard(
      icon: Icons.local_shipping_outlined,
      title: "Today's dispatch",
      subtitle: 'Runs scheduled for the rest of the day.',
      action: LinkChip(
        label: 'Open orders',
        onTap: () => state.navigate(Section.orders),
      ),
      child: Column(
        children: [
          _RunRow(
            time: Seed.nextDispatchTime,
            title: Seed.nextDispatchVenue,
            meta:
                '${Seed.nextDispatchItems} items · ${prep.isNotEmpty ? prep.first.customerName : 'Team pickup'}',
            chip: 'In progress',
            chipFg: AppColors.blue,
            chipBg: AppColors.blueBg,
          ),
          if (prep.isNotEmpty) ...[
            const Divider(height: 18),
            _RunRow(
              time: '5:15 PM',
              title: prep.first.eventName,
              meta:
                  '${prep.first.itemCount} items · ${df.format(prep.first.eventDate)}',
              chip: 'Staging',
              chipFg: AppColors.amber,
              chipBg: AppColors.amberBg,
            ),
          ],
          if (state.pickups.isNotEmpty) ...[
            const Divider(height: 18),
            _RunRow(
              time: DateFormat('EEE h:mm a')
                  .format(state.pickups.first.date),
              title: state.pickups.first.title,
              meta:
                  '${state.pickups.first.itemCount} items · ${state.pickups.first.venue}',
              chip: 'Scheduled',
              chipFg: AppColors.green,
              chipBg: AppColors.greenBg,
            ),
          ],
        ],
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  final String time;
  final String title;
  final String meta;
  final String chip;
  final Color chipFg;
  final Color chipBg;

  const _RunRow({
    required this.time,
    required this.title,
    required this.meta,
    required this.chip,
    required this.chipFg,
    required this.chipBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDeep)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        StatusBadge.custom(label: chip, fg: chipFg, bg: chipBg),
      ],
    );
  }
}

// --------------------------------------------------------- quick actions
class _QuickActionsCard extends StatelessWidget {
  final WorkspaceState state;
  const _QuickActionsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.add_rounded,
        AppColors.primary,
        AppColors.primarySoft,
        'New booking',
        () => showNewBookingSheet(context)
      ),
      (
        Icons.payments_outlined,
        AppColors.purple,
        AppColors.purpleBg,
        'Record payment',
        () => state.navigate(Section.orders)
      ),
      (
        Icons.assignment_turned_in_outlined,
        AppColors.green,
        AppColors.greenBg,
        'Check-in return',
        () => state.navigate(Section.orders)
      ),
      (
        Icons.person_add_alt_1_outlined,
        AppColors.blue,
        AppColors.blueBg,
        'Add customer',
        () => state.navigate(Section.customers)
      ),
    ];
    return SectionCard(
      icon: Icons.bolt_rounded,
      title: 'Quick actions',
      subtitle: 'One tap, straight to work.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _QuickActionTile(action: actions[0])),
              const SizedBox(width: 8),
              Expanded(child: _QuickActionTile(action: actions[1])),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _QuickActionTile(action: actions[2])),
              const SizedBox(width: 8),
              Expanded(child: _QuickActionTile(action: actions[3])),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final (IconData, Color, Color, String, VoidCallback) action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg, label, onTap) = action;
    return Material(
      color: AppColors.subtleFill.withOpacity(0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconChipLite(icon: icon, color: color, bg: bg, size: 30),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBody)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------- my activity
class _MyActivityCard extends StatelessWidget {
  final WorkspaceState state;
  final int limit;

  const _MyActivityCard({required this.state, required this.limit});

  @override
  Widget build(BuildContext context) {
    final mine = state.myActivity.take(limit).toList();
    return SectionCard(
      icon: Icons.history_rounded,
      title: 'My recent actions',
      subtitle: 'Everything you have logged today.',
      action: LinkChip(
        label: 'View all',
        onTap: () => state.navigate(Section.activity),
      ),
      child: mine.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No actions logged yet today.',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppColors.textMuted)),
            )
          : Column(
              children: [
                for (var i = 0; i < mine.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i < mine.length - 1 ? 12 : 0),
                    child:
                        ActivityRow(entry: mine[i], showDivider: false),
                  ),
              ],
            ),
    );
  }
}

// ========================================================= owner dashboard
/// Business-pulse home for owners. Wide: financial KPIs (revenue, MTD,
/// utilization, receivables), revenue trend sparkline, inventory snapshot,
/// pickups, live activity and workspace health.
class _OwnerWideDashboard extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;

  const _OwnerWideDashboard({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final snapshot = state.inventory.take(6).toList();
    final awaiting = state.awaitingPaymentTotal;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          Density.pagePad(context), 18, Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(DateFormat('EEEE, MMMM d, yyyy').format(now)),
                    const SizedBox(height: 6),
                    Text('Welcome back, ${_firstName(state)}',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 6),
                    const Text(
                        "Here's the pulse of ${Seed.workspaceName} today.",
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlineButton(
                label: 'View reports',
                icon: Icons.bar_chart_rounded,
                onTap: () => state.navigate(Section.reports),
              ),
              const SizedBox(width: 10),
              PrimaryButton(
                label: 'New rental booking',
                icon: Icons.add_rounded,
                onTap: () => showNewBookingSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ---- business open banner
          const _BusinessOpenBanner(),
          const SizedBox(height: 14),

          // ---- financial KPI grid
          LayoutBuilder(builder: (context, c) {
            const cols = 4;
            const gap = 12.0;
            final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: cardW,
                  child: const KpiCard(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primarySoft,
                    label: "Today's revenue",
                    value: '\$2,480',
                    subtitle: 'vs. \$2,200 yesterday',
                    trailing: TrendChip(text: '12.8%', positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.purple,
                    iconBg: AppColors.purpleBg,
                    label: 'Month to date',
                    value:
                        '\$${Seed.grossRevenueMonth.toStringAsFixed(1)}k',
                    subtitle: 'Gross bookings · October',
                    trailing: const TrendChip(
                        text: '${Seed.grossRevenueTrend}%',
                        positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.donut_large_rounded,
                    iconColor: AppColors.amber,
                    iconBg: AppColors.amberBg,
                    label: 'Fleet utilization',
                    value: '${Seed.utilizationPct}%',
                    subtitle: '${state.totalUnits} units on hand',
                    trailing: const TrendChip(
                        text: '${Seed.utilizationTrend}%',
                        positive: true),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.red,
                    iconBg: AppColors.redBg,
                    label: 'Awaiting payment',
                    value: '\$${awaiting.toStringAsFixed(0)}',
                    subtitle:
                        '${state.needsPaymentCount} order(s) pending',
                    trailing: const TrendChip.flat(text: 'Follow up'),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 14),

          // ---- main grid
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 12,
                  child: Column(
                    children: [
                      _SnapshotCard(
                          state: state, snapshot: snapshot, compact: false),
                      const SizedBox(height: 20),
                      _UpcomingPickups(state: state, now: now),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _RevenueTrendCard(now: now),
                      const SizedBox(height: 20),
                      _RecentActivity(state: state),
                      const SizedBox(height: 20),
                      _WorkspaceHealth(state: state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- revenue trend
class _RevenueTrendCard extends StatelessWidget {
  final DateTime now;
  const _RevenueTrendCard({required this.now});

  @override
  Widget build(BuildContext context) {
    final points = Seed.revenueTrend(now);
    final maxV = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return SectionCard(
      icon: Icons.show_chart,
      title: 'Revenue trend',
      subtitle: 'Gross bookings · last 2 weeks',
      action: const TrendChip(
          text: '${Seed.grossRevenueTrend}%', positive: true),
      child: Column(
        children: [
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < points.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FractionallySizedBox(
                        heightFactor:
                            (points[i].value / maxV).clamp(0.18, 1.0),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: i == points.length - 1
                                ? AppColors.primary
                                : AppColors.primaryTint,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMM d').format(points.first.day),
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      color: AppColors.textFaint)),
              const Text('Today',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      color: AppColors.textFaint)),
            ],
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------- business open banner
class _BusinessOpenBanner extends StatelessWidget {
  const _BusinessOpenBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greenBg.withOpacity(0.55),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.greenBg),
      ),
      child: Row(
        children: [
          const Dot(color: AppColors.green),
          const SizedBox(width: 9),
          const Text('Business Open',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green)),
          const SizedBox(width: 12),
          Container(width: 1, height: 14, color: AppColors.greenBg),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Closes at ${Seed.businessCloseTime}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppColors.textBody)),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: AppColors.green),
        ],
      ),
    );
  }
}

// ========================================================== owner compact
class _OwnerCompactDashboard extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;

  const _OwnerCompactDashboard({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final entries = state.activity.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(DateFormat('EEEE, MMMM d').format(now)),
                    const SizedBox(height: 5),
                    Text('Welcome back, ${_firstName(state)}',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 4),
                    const Text("Here's the pulse of Riverside Events.",
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.5,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const InitialsAvatar(
                  initials: 'OW',
                  color: AppColors.avatarIndigo,
                  size: 36,
                  fontSize: 12.5),
            ],
          ),
          const SizedBox(height: 18),

          // business open banner
          const _BusinessOpenBanner(),
          const SizedBox(height: 14),

          // Today at a glance
          Row(
            children: [
              const Text('Today at a glance',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const Spacer(),
              LinkChip(
                label: 'Details',
                onTap: () => state.navigate(Section.orders),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(
            height: 122,
            child: Row(
              children: [
                Expanded(
                  child: KpiTileMini(
                    icon: Icons.payments_outlined,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primarySoft,
                    label: "Today's revenue",
                    value: '\$2,480',
                    subtitle: 'vs. yesterday',
                    trailing: TrendChip(text: '12.8%', positive: true),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: KpiTileMini(
                    icon: Icons.event_available_outlined,
                    iconColor: AppColors.purple,
                    iconBg: AppColors.purpleBg,
                    label: 'Active rentals',
                    value: '24',
                    subtitle: 'since yesterday',
                    trailing: TrendChip(text: '+4', positive: true),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: KpiTileMini(
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.amber,
                    iconBg: AppColors.amberBg,
                    label: 'Pending returns',
                    value: '8',
                    subtitle: 'today',
                    trailing: TrendChip(
                        text: '2 due', positive: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Live activity
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppShadow.card(opacity: 0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text('Live activity',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                    ),
                    StatusBadge.custom(
                      label: 'Live',
                      fg: AppColors.green,
                      bg: AppColors.greenBg,
                      dot: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text('Employee actions, in real time.',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppColors.textMuted)),
                const SizedBox(height: 12),
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ActivityRow(entry: e, showDivider: false),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LinkChip(
                    label: 'View activity log',
                    onTap: () => state.navigate(Section.activity),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Next dispatch
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppShadow.card(opacity: 0.04),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconChipLite(
                        icon: Icons.local_shipping_outlined,
                        color: AppColors.blue,
                        bg: AppColors.blueBg,
                        size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow('Next dispatch'),
                          SizedBox(height: 3),
                          Text('Oakwood Estate',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark)),
                        ],
                      ),
                    ),
                    Text('3:30 PM',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ],
                ),
                SizedBox(height: 11),
                Divider(),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.event_outlined,
                        size: 15, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('Sat, Oct 18',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppColors.textMuted)),
                    SizedBox(width: 14),
                    Icon(Icons.inventory_2_outlined,
                        size: 15, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('12 items',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppColors.textMuted)),
                    SizedBox(width: 14),
                    Icon(Icons.person_outline,
                        size: 15, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('Mia Chen',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppColors.textMuted)),
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

// ============================================================ shared cards
// ------------------------------------------------------------ snapshot card
class _SnapshotCard extends StatelessWidget {
  final WorkspaceState state;
  final List<InventoryItem> snapshot;
  final bool compact;

  const _SnapshotCard({
    required this.state,
    required this.snapshot,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'Inventory snapshot',
      subtitle: 'Monitor availability before the next pickup.',
      action: LinkChip(
        label: 'View inventory',
        onTap: () => state.navigate(Section.inventory),
      ),
      child: Column(
        children: [
          Row(
            children: [
              PopupFilterButton(
                value: state.categoryFilter,
                items: Seed.categories,
                onChanged: (v) => state.setCategoryFilter(v),
              ),
              const Spacer(),
              Text('${snapshot.length} items',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          if (compact)
            for (final item in state.filteredInventory.take(6))
              InventoryListTile(
                item: item,
                onTap: () => state.navigate(Section.inventory),
              )
          else
            InventoryTable(
              items: state.filteredInventory.take(6).toList(),
              compactMode: false,
              onRent: (item) => showNewBookingSheet(context, prefill: item),
              onEdit: (item) => showItemAdjustDialog(context, item),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- pickups card
class _UpcomingPickups extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;
  const _UpcomingPickups({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.calendar_month_outlined,
      title: 'Upcoming pickups',
      subtitle: 'Next three bookings on the calendar',
      action: LinkChip(
        label: 'Open calendar',
        onTap: () => state.navigate(Section.orders),
      ),
      child: Column(
        children: [
          for (var i = 0; i < state.pickups.length; i++)
            PickupRow(
              pickup: state.pickups[i],
              now: now,
              showDivider: i < state.pickups.length - 1,
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- activity card
class _RecentActivity extends StatelessWidget {
  final WorkspaceState state;
  const _RecentActivity({required this.state});

  @override
  Widget build(BuildContext context) {
    final entries = state.activity.take(4).toList();
    return SectionCard(
      icon: Icons.show_chart,
      title: 'Recent activity',
      subtitle: "What's happening in the workspace.",
      action: const Icon(Icons.more_horiz, size: 20, color: AppColors.textMuted),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ActivityRow(entry: entries[i], showDivider: false),
            ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: LinkChip(
              label: 'View all activity',
              onTap: () => state.navigate(Section.activity),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- health card
class _WorkspaceHealth extends StatelessWidget {
  final WorkspaceState state;
  const _WorkspaceHealth({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadow.card(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Workspace health'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Running smoothly',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                    color: AppColors.greenBg, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    size: 16, color: AppColors.green),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const HealthBar(fraction: 0.98),
          const SizedBox(height: 10),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('24 active rentals',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppColors.textMuted)),
                Text('98% on time',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Dot(color: AppColors.green),
                SizedBox(width: 8),
                Text('Sync is up to date',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppColors.textMuted)),
                SizedBox(width: 18),
                Text('Just now',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppColors.textFaint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
