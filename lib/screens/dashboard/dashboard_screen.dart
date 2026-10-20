import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart'; // AppRadius / AppShadow
import '../../core/density.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../data/catalog.dart';
import '../../models/inventory_item.dart';
import '../../models/shift_task.dart';
import '../../models/rental_order.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/inventory_views.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/rows.dart';
import '../../widgets/motion.dart';
import '../../screens/booking/new_booking_sheet.dart';
import '../../screens/inventory/item_adjust_dialog.dart';
import '../../screens/tasks/tasks_screen.dart';
import '../../screens/calendar/calendar_screen.dart';
import '../../screens/orders/order_detail_screen.dart';
import '../../widgets/filters.dart';
import '../../widgets/indicators.dart';
import '../../core/palette.dart';
import '../../core/app_locale.dart';

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
  if (now.hour < 12) return AppLocale.t('Good morning');
  if (now.hour < 17) return AppLocale.t('Good afternoon');
  return AppLocale.t('Good evening');
}

String _firstName(WorkspaceState state) =>
    state.account?.name.split(' ').first ?? 'there';

/// Opens the record behind a task: the order detail for order tasks,
/// the calendar for pickup runs.
void _openTaskSource(BuildContext context, ShiftTask task) {
  final state = context.read<WorkspaceState>();
  final order = task.orderId == null ? null : state.orderById(task.orderId!);
  if (order != null) {
    openOrderDetail(context, order);
  } else {
    openCalendar(context);
  }
}

// ======================================================= employee dashboard
/// Task-first home for operations staff. The shift hero is the single summary
/// for the day; the rest of the screen is reserved for work that can be
/// acted on now. This avoids repeating the same counts in multiple cards.
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
    final tasks = state.shiftTasks(now);
    final wide = !compact;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          Density.pagePad(context), 16, Density.pagePad(context), 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- shift hero (greeting + live progress + actions)
          _ShiftHero(
            state: state,
            now: now,
            tasks: tasks,
            compact: compact,
          ),
          const SizedBox(height: 14),

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
            _DispatchCard(state: state),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ shift hero
/// The employee's morning anchor: a full-width brand-gradient panel with
/// greeting, live shift progress, the next task up, and the two primary
/// actions. Both modes get a designed gradient: Noir indigo→violet + glow
/// on dark, a deeper indigo→violet "morning" variant on light.
class _ShiftHero extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;
  final List<ShiftTask> tasks;
  final bool compact;

  const _ShiftHero({
    required this.state,
    required this.now,
    required this.tasks,
    required this.compact,
  });

  // Honest progress: every returned order is a completed touchpoint,
  // every open task is one still to do.
  int get _done =>
      state.orders.where((o) => o.status == OrderStatus.returned).length;

  @override
  Widget build(BuildContext context) {
    final total = _done + tasks.length;
    final fraction = total == 0 ? 1.0 : (_done / total).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 18, compact ? 14 : 16,
          compact ? 14 : 18, compact ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppPalette.heroGradient,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadow.glow(blur: 26),
      ),
      child: Stack(
        children: [
          // decorative depth: two soft highlight orbs
          Positioned(
            right: -34,
            top: -42,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 66,
            bottom: -58,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ---- greeting block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compact
                          ? Fmt.weekdayMonth(now).toUpperCase()
                          : Fmt.longDate(now).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white.withOpacity(0.72),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${_greeting(now)}, ${_firstName(state)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: compact ? 19 : 23,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(
                      tasks.isEmpty
                          ? AppLocale.t(
                              'You are all caught up — nothing pending today.')
                          : state.returnsTodayCount == 0
                              ? AppLocale.tf(
                                  'You have {n} tasks on deck today.',
                                  {'n': tasks.length})
                              : AppLocale.tf(
                                  'You have {n} tasks on deck today, including {m} return check-ins.',
                                  {
                                      'n': tasks.length,
                                      'm': state.returnsTodayCount
                                    }),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: Colors.white.withOpacity(0.85)),
                    ),
                    const SizedBox(height: 12),
                    // ---- progress rail
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 6,
                              backgroundColor: Colors.white.withOpacity(0.25),
                              valueColor:
                                  const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          total == 0
                              ? AppLocale.t('All clear')
                              : '$_done of $total done',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                    if (compact) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _HeroPill(
                            icon: Icons.timelapse_rounded,
                            text: AppLocale.tf('Until {n}',
                                {'n': AppLocale.t(Catalog.businessCloseTime)}),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Frosted pill used inside the compact hero.
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.95))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ task list
/// Filter buckets for the shift task list.
class _TaskFilter {
  final String label;
  final String? kind;
  const _TaskFilter(this.label, [this.kind]);
}

List<_TaskFilter> _kTaskFilters() => [
      _TaskFilter(AppLocale.t('All')),
      _TaskFilter(AppLocale.t('Prep'), 'prep'),
      _TaskFilter(AppLocale.t('On rent'), 'delivery'),
      _TaskFilter(AppLocale.t('Payments'), 'payment'),
    ];

class _TaskListCard extends StatefulWidget {
  final WorkspaceState state;
  final List<ShiftTask> tasks;
  final int? limit;

  const _TaskListCard({required this.state, required this.tasks, this.limit});

  @override
  State<_TaskListCard> createState() => _TaskListCardState();
}

class _TaskListCardState extends State<_TaskListCard> {
  String? _kind; // null = all buckets

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final filtered =
        _kind == null ? tasks : tasks.where((t) => t.kind == _kind).toList();
    final shown =
        widget.limit == null ? filtered : filtered.take(widget.limit!).toList();
    return SectionCard(
      icon: Icons.checklist_rounded,
      title: AppLocale.t('Your task list'),
      subtitle: filtered.isEmpty
          ? AppLocale.t('Nothing in this bucket — all clear.')
          : null,
      action: LinkChip(
        label: AppLocale.t('All tasks'),
        onTap: () => openTasks(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- filter pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in _kTaskFilters())
                _FilterPill(
                  label: f.label,
                  count: f.kind == null
                      ? tasks.length
                      : tasks.where((t) => t.kind == f.kind).length,
                  selected: _kind == f.kind,
                  onTap: () => setState(() => _kind = f.kind),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined,
                      size: 18, color: AppPalette.green),
                  const SizedBox(width: 8),
                  Text(AppLocale.t('All clear — every task is done for today.'),
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
                for (var i = 0; i < shown.length; i++)
                  _TaskRow(
                    widget: widget,
                    task: shown[i],
                    index: i,
                    showDivider: i < shown.length - 1,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Small choice pill used by the task-list filters.
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
    return Material(
      color:
          selected ? AppPalette.primarySoft : AppPalette.fill.withOpacity(0.7),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color:
                    selected ? AppPalette.primaryBorder : Colors.transparent),
          ),
          child: Text(
            count == 0 ? label : '$label · $count',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppPalette.primaryDeep : AppPalette.body),
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final _TaskListCard widget;
  final ShiftTask task;
  final int index;
  final bool showDivider;

  const _TaskRow({
    required this.widget,
    required this.task,
    required this.index,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = index == 0;
    final row = Padding(
      padding: EdgeInsets.symmetric(
          vertical: isFirst ? 8 : 9, horizontal: isFirst ? 10 : 0),
      child: Row(
        children: [
          // priority number — 01, 02, …
          SizedBox(
            width: 20,
            child: Text(
              (index + 1).toString().padLeft(2, '0'),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isFirst ? AppPalette.primary : AppPalette.faint),
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
          const SizedBox(width: 10),
          StatusBadge.custom(
              label: task.chip, fg: task.chipFg, bg: task.chipBg),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 15, color: AppPalette.faint),
        ],
      ),
    );

    // The top of the list gets a gentle "work me first" treatment.
    final highlighted = isFirst
        ? Container(
            decoration: BoxDecoration(
              color: AppPalette.primarySoft.withOpacity(0.42),
              borderRadius: BorderRadius.circular(11),
              border:
                  Border.all(color: AppPalette.primaryBorder.withOpacity(0.55)),
            ),
            child: row,
          )
        : row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HoverFill(
          onTap: () => _openTaskSource(context, task),
          radius: 11,
          child: highlighted,
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 46),
            child: Divider(height: 18),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- dispatch
class _DispatchCard extends StatelessWidget {
  final WorkspaceState state;
  const _DispatchCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final prep =
        state.orders.where((o) => o.status == OrderStatus.preparing).toList();
    final df = DateFormat('EEE, MMM d');
    final next = state.nextDispatch;
    final runs = [
      if (prep.isNotEmpty)
        (
          time: Fmt.timeOfDay(prep.first.eventDate),
          title: prep.first.eventName,
          meta:
              '${Fmt.items(prep.first.itemCount)} · ${prep.first.customerName}',
          chip: AppLocale.t('In progress'),
          chipFg: AppPalette.blue,
          chipBg: AppPalette.blueBg,
          orderId: prep.first.id,
        ),
      if (prep.skip(1).isNotEmpty)
        (
          time: Fmt.timeOfDay(prep.skip(1).first.eventDate),
          title: prep.skip(1).first.eventName,
          meta:
              '${Fmt.items(prep.skip(1).first.itemCount)} · ${df.format(prep.skip(1).first.eventDate)}',
          chip: AppLocale.t('Staging'),
          chipFg: AppPalette.amber,
          chipBg: AppPalette.amberBg,
          orderId: prep.skip(1).first.id,
        ),
      if (next != null)
        (
          time: Fmt.shortWeekdayTime(next.date),
          title: next.venue,
          meta: '${Fmt.items(next.itemCount)} · ${next.contactName}',
          chip: AppLocale.t('Scheduled'),
          chipFg: AppPalette.green,
          chipBg: AppPalette.greenBg,
          orderId: null,
        ),
    ];
    return SectionCard(
      icon: Icons.local_shipping_outlined,
      title: "Today's pickups",
      action: LinkChip(
        label: AppLocale.t('Open calendar'),
        onTap: () => openCalendar(context),
      ),
      child: runs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                    AppLocale.t('No runs scheduled — the board is clear.'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppPalette.muted)),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < runs.length; i++)
                  _TimelineTile(
                    isLast: i == runs.length - 1,
                    dotColor: runs[i].chipFg,
                    child: _RunRow(
                      time: runs[i].time,
                      title: runs[i].title,
                      meta: runs[i].meta,
                      chip: runs[i].chip,
                      chipFg: runs[i].chipFg,
                      chipBg: runs[i].chipBg,
                      orderId: runs[i].orderId,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Timeline rail + content row — shared by dispatch runs and activity.
class _TimelineTile extends StatelessWidget {
  final bool isLast;
  final Color dotColor;
  final Widget child;

  const _TimelineTile({
    required this.isLast,
    required this.dotColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                    color: AppPalette.raise,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 3),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppPalette.stroke,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
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
  final String? orderId;

  const _RunRow({
    required this.time,
    required this.title,
    required this.meta,
    required this.chip,
    required this.chipFg,
    required this.chipBg,
    this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.primaryDeep)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                const SizedBox(height: 2),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusBadge.custom(label: chip, fg: chipFg, bg: chipBg),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 15, color: AppPalette.faint),
        ],
      ),
    );

    if (orderId == null) return row;
    return HoverFill(
      onTap: () {
        final state = context.read<WorkspaceState>();
        final order = state.orderById(orderId!);
        if (order != null) {
          openOrderDetail(context, order);
        } else {
          openCalendar(context);
        }
      },
      radius: 10,
      child: row,
    );
  }
}

/// One-tap shortcuts, tuned per role:
///  - employee: booking flow + counter work (payments, returns, customers)
///  - owner: business levers (reports, access & roles) + shared flow entry
class _QuickActionsCard extends StatelessWidget {
  final WorkspaceState state;
  const _QuickActionsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final actions = state.isOwner
        ? [
            (
              Icons.add_rounded,
              AppPalette.primary,
              AppPalette.primarySoft,
              AppLocale.t('New booking'),
              () => showNewBookingSheet(context)
            ),
            (
              Icons.bar_chart_rounded,
              AppPalette.purple,
              AppPalette.purpleBg,
              AppLocale.t('Reports'),
              () => state.navigate(Section.reports)
            ),
            (
              Icons.person_add_alt_1_outlined,
              AppPalette.green,
              AppPalette.greenBg,
              AppLocale.t('Add customer'),
              () => state.navigate(Section.customers)
            ),
            (
              Icons.shield_outlined,
              AppPalette.blue,
              AppPalette.blueBg,
              AppLocale.t('Access & roles'),
              () => state.navigate(Section.access)
            ),
          ]
        : [
            (
              Icons.add_rounded,
              AppPalette.primary,
              AppPalette.primarySoft,
              AppLocale.t('New booking'),
              () => showNewBookingSheet(context)
            ),
            (
              Icons.payments_outlined,
              AppPalette.purple,
              AppPalette.purpleBg,
              AppLocale.t('Record payment'),
              () => state.navigate(Section.orders)
            ),
            (
              Icons.assignment_turned_in_outlined,
              AppPalette.green,
              AppPalette.greenBg,
              AppLocale.t('Check-in return'),
              () => state.navigate(Section.orders)
            ),
            (
              Icons.person_add_alt_1_outlined,
              AppPalette.blue,
              AppPalette.blueBg,
              AppLocale.t('Add customer'),
              () => state.navigate(Section.customers)
            ),
          ];
    return SectionCard(
      icon: Icons.bolt_rounded,
      title: AppLocale.t('Quick actions'),
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
      color: AppPalette.fill.withOpacity(0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    AppPalette.stroke.withOpacity(AppPalette.dark ? 0.9 : 0.6)),
          ),
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
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.body)),
                ),
              ],
            ),
          ),
        ),
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
                    Eyebrow(Fmt.longDate(now)),
                    const SizedBox(height: 6),
                    Text(
                        AppLocale.tf(
                            'Welcome back, {n}', {'n': _firstName(state)}),
                        style: Theme.of(context).textTheme.headlineLarge),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              PrimaryButton(
                label: AppLocale.t('New rental booking'),
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
            // There are three metrics here; keeping a fourth empty column
            // made the owner dashboard feel sparse and visually unbalanced.
            const cols = 3;
            const gap = 12.0;
            final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.payments_outlined,
                    iconColor: AppPalette.primary,
                    iconBg: AppPalette.primarySoft,
                    label: AppLocale.t("Today's revenue"),
                    value: state.earnings.isEmpty
                        ? '—'
                        : Fmt.money(state.earnings.last.value * 1000),
                    subtitle: state.earnings.length >= 2
                        ? AppLocale.tf('vs. {n} yesterday', {
                            'n': Fmt.money(state
                                    .earnings[state.earnings.length - 2].value *
                                1000),
                          })
                        : AppLocale.t('Bookings today'),
                    trailing: TrendChip(
                        text: '${state.earningsTrendPct.toStringAsFixed(1)}%',
                        positive: state.earningsTrendPct >= 0),
                    onTap: () => state.navigate(Section.reports),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.donut_large_rounded,
                    iconColor: AppPalette.amber,
                    iconBg: AppPalette.amberBg,
                    label: AppLocale.t('Fleet utilization'),
                    value: '${state.utilization.toStringAsFixed(1)}%',
                    subtitle:
                        AppLocale.tr('{n} units on hand', state.totalUnits),
                    onTap: () => state.navigate(Section.inventory),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: KpiCard(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppPalette.red,
                    iconBg: AppPalette.redBg,
                    label: AppLocale.t('Awaiting payment'),
                    value: Fmt.moneySmart(awaiting),
                    subtitle: AppLocale.tr(
                        state.needsPaymentCount == 1
                            ? '{n} order pending'
                            : '{n} orders pending',
                        state.needsPaymentCount),
                    onTap: () {
                      state.setOrderStatusFilter(OrderStatus.needsPayment);
                      state.navigate(Section.orders);
                    },
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 14),

          // ---- earnings overview (full width)
          const _EarningsCard(),
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
                      _SnapshotCard(state: state, snapshot: snapshot),
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
                      _QuickActionsCard(state: state),
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

// ------------------------------------------------------- earnings card
/// Full-width owner earnings overview: 12-day bar chart on the left,
/// month-to-date total + top revenue categories on the right.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final points = state.earnings;
    final categories = state.categorySeries;
    if (points.isEmpty || categories.isEmpty) {
      return _EmptyMetricsCard();
    }
    final maxV = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final maxCat =
        categories.map((c) => c.amount).reduce((a, b) => a > b ? a : b);
    final money =
        NumberFormat.currency(symbol: AppLocale.birr, decimalDigits: 0);
    final wide = MediaQuery.sizeOf(context).width >= 1240;

    final bars = Column(
      children: [
        SizedBox(
          height: 118,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < points.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FractionallySizedBox(
                      heightFactor: (points[i].value / maxV).clamp(0.15, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: i == points.length - 1
                              ? LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: AppPalette.primaryGradient,
                                )
                              : null,
                          color: i == points.length - 1
                              ? null
                              : AppPalette.primary
                                  .withOpacity(AppPalette.dark ? 0.30 : 0.16),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5)),
                          boxShadow: i == points.length - 1
                              ? AppShadow.glow(blur: 14)
                              : null,
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
            Text(Fmt.dayMonth(points.first.day),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    color: AppPalette.faint)),
            Text(AppLocale.t('Today'),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    color: AppPalette.faint)),
          ],
        ),
      ],
    );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Fmt.compactMoney(state.monthGrossRevenueK * 1000),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 24,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppPalette.ink)),
        const SizedBox(height: 3),
        Text(
            AppLocale.tf('Month to date · {n}',
                {'n': AppLocale.gcMonthName(DateTime.now())}),
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                color: AppPalette.muted)),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 10),
        Eyebrow(AppLocale.t('Top categories')),
        const SizedBox(height: 8),
        for (final c in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _CategoryStatRow(
              label: c.category,
              amount: money.format(c.amount),
              fraction: (c.amount / maxCat).clamp(0.0, 1.0),
            ),
          ),
      ],
    );

    return SectionCard(
      icon: Icons.show_chart,
      title: AppLocale.t('Earnings overview'),
      subtitle: AppLocale.t('Daily gross bookings · last 12 days'),
      action: TrendChip(
          text: '${state.earningsTrendPct.toStringAsFixed(1)}%',
          positive: state.earningsTrendPct >= 0),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 12, child: bars),
                const SizedBox(width: 26),
                Expanded(flex: 5, child: summary),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bars,
                const SizedBox(height: 16),
                summary,
              ],
            ),
    );
  }
}

/// Category revenue row: name · progress bar · amount.
class _CategoryStatRow extends StatelessWidget {
  final String label;
  final String amount;
  final double fraction;

  const _CategoryStatRow({
    required this.label,
    required this.amount,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.body)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: AppPalette.fill,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(amount,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: AppPalette.muted)),
        ),
      ],
    );
  }
}

// --------------------------------------------------- empty metrics state
/// Shown when the Appwrite metrics document has no series yet — honest
/// empty state, never a placeholder dataset.
class _EmptyMetricsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppPalette.raise,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.stroke),
      ),
      child: Column(
        children: [
          Icon(Icons.insights_outlined, size: 30, color: AppPalette.muted),
          const SizedBox(height: 10),
          Text(AppLocale.t('No earnings data yet'),
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink,
              )),
          const SizedBox(height: 5),
          Text(
              'Revenue analytics appear once bookings start flowing through '
              'the workspace.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppPalette.muted,
              )),
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
    return HoverFill(
      onTap: () => openCalendar(context),
      radius: 11,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppPalette.greenBg.withOpacity(AppPalette.dark ? 0.8 : 0.55),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color:
                  AppPalette.green.withOpacity(AppPalette.dark ? 0.28 : 0.0)),
        ),
        child: Row(
          children: [
            Dot(color: AppPalette.green),
            const SizedBox(width: 9),
            Text(AppLocale.t('Business Open'),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.green)),
            const SizedBox(width: 12),
            Container(width: 1, height: 14, color: AppPalette.greenBg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  AppLocale.tf('Closes at {n}',
                      {'n': AppLocale.t(Catalog.businessCloseTime)}),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppPalette.body)),
            ),
            Text(AppLocale.t('Calendar'),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.green)),
            const SizedBox(width: 3),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: AppPalette.green),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------- owner phone hero
/// The owner's compact (phone) hero — same gradient-panel language as the
/// employee shift hero, tuned for the business pulse: greeting, a glass
/// owner avatar, and the live open/closed status + headline number as
/// frosted pills. Dark mode: Noir indigo→violet + glow; light: the deeper
/// "morning" variant of [AppPalette.heroGradient].
class _OwnerHero extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;

  const _OwnerHero({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final first = _firstName(state);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppPalette.heroGradient,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadow.glow(blur: 26),
      ),
      child: Stack(
        children: [
          // decorative depth: soft highlight orbs (mirrored vs. shift hero)
          Positioned(
            right: -30,
            top: -44,
            child: Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            left: -36,
            bottom: -52,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Fmt.weekdayMonth(now).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white.withOpacity(0.72),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Welcome back, $first',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    // live status + headline number, frosted (wraps on
                    // narrow phones instead of overflowing)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _HeroPill(
                          icon: Icons.storefront_outlined,
                          text: AppLocale.tf('Open · closes {n}',
                              {'n': AppLocale.t(Catalog.businessCloseTime)}),
                        ),
                        _HeroPill(
                          icon: Icons.bolt_rounded,
                          text: '${state.openOrdersCount} active rentals',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // glass avatar — owner initial
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.16),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  first.isEmpty ? 'O' : first[0].toUpperCase(),
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ],
          ),
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
    final next = state.nextDispatch;
    final dispatchOverdue = next != null &&
        next.date.isBefore(DateTime(now.year, now.month, now.day));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // hero (greeting + live business status on the brand gradient)
          _OwnerHero(state: state, now: now),
          const SizedBox(height: 14),

          // Today at a glance
          Text(AppLocale.t('Today at a glance'),
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.ink)),
          const SizedBox(height: 10),
          SizedBox(
            height: 122,
            // Swipeable glance strip: fixed-width tiles peek past the
            // right edge with a fade affordance instead of being squeezed
            // into unreadable thirds on narrow phones.
            child: KpiStrip(
              children: [
                KpiTileMini(
                  icon: Icons.payments_outlined,
                  iconColor: AppPalette.primary,
                  iconBg: AppPalette.primarySoft,
                  label: AppLocale.t("Today's revenue"),
                  value: state.earnings.isEmpty
                      ? '—'
                      : Fmt.money(state.earnings.last.value * 1000),
                  subtitle: AppLocale.t('vs. yesterday'),
                  trailing: TrendChip(
                      text: '${state.earningsTrendPct.toStringAsFixed(1)}%',
                      positive: state.earningsTrendPct >= 0),
                  onTap: () => state.navigate(Section.reports),
                ),
                KpiTileMini(
                  icon: Icons.event_available_outlined,
                  iconColor: AppPalette.purple,
                  iconBg: AppPalette.purpleBg,
                  label: AppLocale.t('Active rentals'),
                  value: '${state.openOrdersCount}',
                  subtitle: AppLocale.t('open right now'),
                  onTap: () => state.navigate(Section.orders),
                ),
                KpiTileMini(
                  icon: Icons.schedule_rounded,
                  iconColor: AppPalette.amber,
                  iconBg: AppPalette.amberBg,
                  label: AppLocale.t('Pending returns'),
                  value: '${state.returnsTodayCount}',
                  subtitle: AppLocale.t('to check in today'),
                  trailing: state.returnsLateCount > 0
                      ? TrendChip(
                          text:
                              AppLocale.tr('{n} late', state.returnsLateCount),
                          positive: false)
                      : TrendChip.flat(text: AppLocale.t('On time')),
                  onTap: () => state.navigate(Section.orders),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick actions (owner set)
          _QuickActionsCard(state: state),
          const SizedBox(height: 14),

          // Live activity
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppPalette.stroke),
              boxShadow: AppShadow.card(opacity: 0.04),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocale.t('Live activity'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink)),
                const SizedBox(height: 12),
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ActivityRow(
                      entry: e,
                      showDivider: false,
                      onTap: () => state.navigate(Section.activity),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LinkChip(
                    label: AppLocale.t('View activity log'),
                    onTap: () => state.navigate(Section.activity),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Next dispatch — LIVE from the pickup schedule (the wide
          // dashboard's dispatch card uses the same source). A run whose
          // date has already passed but is still on the board flips the
          // card to an honest amber “overdue” state instead of posing as
          // upcoming.
          if (next != null)
            HoverLift(
              onTap: () => openCalendar(context),
              radius: 14,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: dispatchOverdue
                          ? AppPalette.amberBg
                          : AppPalette.stroke),
                  boxShadow: AppShadow.card(opacity: 0.04),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconChipLite(
                            icon: Icons.local_shipping_outlined,
                            color: dispatchOverdue
                                ? AppPalette.amber
                                : AppPalette.blue,
                            bg: dispatchOverdue
                                ? AppPalette.amberBg
                                : AppPalette.blueBg,
                            size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Eyebrow(dispatchOverdue
                                  ? AppLocale.t('Pickup overdue')
                                  : AppLocale.t('Next pickup')),
                              const SizedBox(height: 3),
                              Text(next.venue,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppPalette.ink)),
                            ],
                          ),
                        ),
                        Text(
                            dispatchOverdue
                                ? Fmt.shortWeekdayDate(next.date)
                                : DateFormat.jm().format(next.date),
                            style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: dispatchOverdue
                                    ? AppPalette.amber
                                    : AppPalette.primary)),
                      ],
                    ),
                    const SizedBox(height: 11),
                    const Divider(),
                    const SizedBox(height: 10),
                    // meta facts wrap to a second line on narrow phones
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.event_outlined,
                              size: 15,
                              color: dispatchOverdue
                                  ? AppPalette.amber
                                  : AppPalette.muted),
                          const SizedBox(width: 6),
                          Text(Fmt.shortWeekdayDate(next.date),
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  fontWeight: dispatchOverdue
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: dispatchOverdue
                                      ? AppPalette.amber
                                      : AppPalette.muted)),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 15, color: AppPalette.muted),
                          const SizedBox(width: 6),
                          Text(Fmt.items(next.itemCount),
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  color: AppPalette.muted)),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.person_outline,
                              size: 15, color: AppPalette.muted),
                          const SizedBox(width: 6),
                          Text(next.contactName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  color: AppPalette.muted)),
                        ]),
                      ],
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

// ============================================================ shared cards
// ------------------------------------------------------------ snapshot card
class _SnapshotCard extends StatelessWidget {
  final WorkspaceState state;
  final List<InventoryItem> snapshot;

  const _SnapshotCard({
    required this.state,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.inventory_2_outlined,
      title: AppLocale.t('Inventory snapshot'),
      action: LinkChip(
        label: AppLocale.t('View inventory'),
        onTap: () => state.navigate(Section.inventory),
      ),
      child: Column(
        children: [
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
      title: AppLocale.t('Upcoming pickups'),
      action: LinkChip(
        label: AppLocale.t('Open calendar'),
        onTap: () => openCalendar(context),
      ),
      child: Column(
        children: [
          for (var i = 0; i < state.pickups.length; i++)
            PickupRow(
              pickup: state.pickups[i],
              now: now,
              showDivider: i < state.pickups.length - 1,
              onTap: () => openCalendar(context),
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
      title: AppLocale.t('Recent activity'),
      action: LinkChip(
        label: AppLocale.t('Open log'),
        onTap: () => state.navigate(Section.activity),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ActivityRow(
                entry: entries[i],
                showDivider: false,
                onTap: () => state.navigate(Section.activity),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- health card
/// Workspace health, computed from the live book — nothing hardcoded.
/// Completion timestamps don't exist yet, so "health" is schedule
/// adherence of open orders (the same rule as [returnsLateCount]),
/// surfaced with a dynamic verdict, a real fraction bar and the actual
/// payments + cloud-sync state.
class _WorkspaceHealth extends StatelessWidget {
  final WorkspaceState state;
  const _WorkspaceHealth({required this.state});

  @override
  Widget build(BuildContext context) {
    final overdue = state.openOverdueCount;
    final onSchedule = state.scheduleHealth;
    final smooth = overdue == 0;
    final heading = smooth
        ? AppLocale.t('Running smoothly')
        : AppLocale.t('Needs attention');
    final headingColor = smooth ? AppPalette.ink : AppPalette.amber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: smooth ? AppPalette.stroke : AppPalette.amberBg),
        boxShadow: AppShadow.card(opacity: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(AppLocale.t('Workspace health')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(heading,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: headingColor)),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: smooth ? AppPalette.greenBg : AppPalette.amberBg,
                    shape: BoxShape.circle),
                child: Icon(
                    smooth ? Icons.check_rounded : Icons.priority_high_rounded,
                    size: 16,
                    color: smooth ? AppPalette.green : AppPalette.amber),
              ),
            ],
          ),
          const SizedBox(height: 14),
          HealthBar(fraction: onSchedule),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${state.openOrdersCount} open rentals',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppPalette.muted)),
                const SizedBox(width: 10),
                Text(
                    '${(onSchedule * 100).toStringAsFixed(0)}% on schedule'
                    '${overdue > 0 ? ' · $overdue overdue' : ''}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: smooth ? AppPalette.green : AppPalette.amber)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // Real payments signal — what the orders ledger actually says.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Dot(
                    color: state.needsPaymentCount > 0
                        ? AppPalette.amber
                        : AppPalette.green),
                const SizedBox(width: 8),
                Text(
                    state.needsPaymentCount > 0
                        ? '${state.needsPaymentCount} awaiting payment'
                        : AppLocale.t('No payments pending'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Real sync signal — writes go straight through to the cloud.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Dot(
                    color:
                        state.liveBackend ? AppPalette.green : AppPalette.red),
                const SizedBox(width: 8),
                Text(
                    state.liveBackend
                        ? AppLocale.t('Cloud sync live · Appwrite')
                        : AppLocale.t('Cloud sync unavailable'),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppPalette.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
