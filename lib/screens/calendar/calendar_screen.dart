import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/pickup.dart';
import '../../models/rental_order.dart';
import '../../state/workspace_state.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/detail_page.dart';
import '../../widgets/motion.dart';
import '../../widgets/order_status_style.dart';
import '../orders/order_detail_screen.dart';
import '../../core/palette.dart';

/// The dispatch calendar — a month grid with dots for pickups and event
/// dates, plus a per-day agenda. Opened via “Open calendar”.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final now = DateTime.now();
    final pickups = state.pickups;

    return DetailPage(
      eyebrow: 'Workspace / Calendar',
      title: 'Dispatch calendar',
      subtitle:
          'Pickups and event dates in one place — tap a day to see its agenda.',
      icon: Icons.calendar_month_outlined,
      actions: [
        OutlineButton(
          label: 'Today',
          icon: Icons.today_outlined,
          onTap: () => setState(() {
            final t = DateTime(now.year, now.month, now.day);
            _month = DateTime(now.year, now.month);
            _selected = t;
          }),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthGrid(
            month: _month,
            selected: _selected,
            now: now,
            pickups: pickups,
            orders: state.orders,
            onPrev: () => setState(() {
              _month = DateTime(_month.year, _month.month - 1);
            }),
            onNext: () => setState(() {
              _month = DateTime(_month.year, _month.month + 1);
            }),
            onSelect: (d) => setState(() => _selected = d),
          ),
          const SizedBox(height: 14),
          _AgendaCard(
            day: _selected,
            pickups: pickups,
            orders: state.orders,
          ),
          const SizedBox(height: 14),
          _UpcomingRuns(state: state, now: now),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- month grid
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime? selected;
  final DateTime now;
  final List<Pickup> pickups;
  final List<RentalOrder> orders;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.now,
    required this.pickups,
    required this.orders,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Set<int> get _pickupDays => pickups
      .where((p) => p.date.year == month.year && p.date.month == month.month)
      .map((p) => p.date.day)
      .toSet();

  Set<int> get _eventDays => orders
      .where((o) =>
          o.eventDate.year == month.year && o.eventDate.month == month.month)
      .map((o) => o.eventDate.day)
      .toSet();

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday - DateTime.monday) % 7;
    final monthName = DateFormat('MMMM yyyy').format(month);

    final cells = <int?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return SectionCard(
      icon: Icons.calendar_month_outlined,
      title: monthName,
      subtitle: 'Indigo = event date · green = pickup run',
      child: Column(
        children: [
          Row(
            children: [
              _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
              const Spacer(),
              Text('Indigo = event · green = pickup',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      color: AppPalette.faint)),
              const Spacer(),
              _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final wd in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Text(wd,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.faint)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < cells.length / 7; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: _cellFor(cells[r * 7 + c])),
              ],
            ),
        ],
      ),
    );
  }

  void onFirstToday(DateTime t) {
    onSelect(t);
  }

  Widget _cellFor(int? day) {
    if (day == null) return const SizedBox(height: 40);
    final date = DateTime(month.year, month.month, day);
    final hasPickup = _pickupDays.contains(day);
    final hasEvent = _eventDays.contains(day);
    final isSelected = selected != null && _sameDay(selected!, date);
    final isToday = _sameDay(now, date);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(date),
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.primarySoft
              : isToday
                  ? AppPalette.fill
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected
                ? AppPalette.primaryBorder
                : isToday
                    ? AppPalette.primary.withOpacity(0.4)
                    : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    fontWeight:
                        isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppPalette.primary
                        : isToday
                            ? AppPalette.primary
                            : AppPalette.body)),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasPickup) _DayDot(color: AppPalette.green),
                if (hasPickup && hasEvent) const SizedBox(width: 3),
                if (hasEvent) _DayDot(color: AppPalette.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final Color color;
  const _DayDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.fill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppPalette.stroke),
          ),
          child: Icon(icon, size: 16, color: AppPalette.body),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- agenda
class _AgendaCard extends StatelessWidget {
  final DateTime? day;
  final List<Pickup> pickups;
  final List<RentalOrder> orders;

  const _AgendaCard({
    required this.day,
    required this.pickups,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.read<WorkspaceState>();
    final dayPickups = day == null
        ? <Pickup>[]
        : pickups.where((p) => _sameDay(p.date, day!)).toList();
    final dayOrders = day == null
        ? <RentalOrder>[]
        : orders.where((o) => _sameDay(o.eventDate, day!)).toList();
    final empty = dayPickups.isEmpty && dayOrders.isEmpty;

    return SectionCard(
      icon: Icons.event_note_outlined,
      title: day == null
          ? 'Agenda'
          : 'Agenda · ${DateFormat('EEE, MMM d').format(day!)}',
      subtitle: empty
          ? 'Nothing scheduled for this day.'
          : '${dayPickups.length} pickup(s) · ${dayOrders.length} event date(s)',
      child: empty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.wb_sunny_outlined,
                      size: 16, color: AppPalette.amber),
                  const SizedBox(width: 8),
                  Text('A clear day — good slot for maintenance work.',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppPalette.muted)),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < dayPickups.length; i++)
                  StaggerIn(
                    index: i,
                    child: HoverFill(
                      onTap: () => openCalendar(context),
                      child: _AgendaRow(
                        icon: Icons.local_shipping_outlined,
                        iconColor: AppPalette.green,
                        iconBg: AppPalette.greenBg,
                        title: 'Pickup · ${dayPickups[i].title}',
                        meta:
                            '${dayPickups[i].venue} · ${dayPickups[i].itemCount} items · ${dayPickups[i].contactName}',
                      ),
                    ),
                  ),
                for (var i = 0; i < dayOrders.length; i++)
                  StaggerIn(
                    index: dayPickups.length + i,
                    child: HoverFill(
                      onTap: () {
                        final live = state.orderById(dayOrders[i].id);
                        if (live != null) openOrderDetail(context, live);
                      },
                      child: _AgendaRow(
                        icon: Icons.event_outlined,
                        iconColor: dayOrders[i].status.fg,
                        iconBg: dayOrders[i].status.bg,
                        title: 'Event · ${dayOrders[i].eventName}',
                        meta:
                            '#${dayOrders[i].id} · ${dayOrders[i].itemCount} items · ${dayOrders[i].status.label}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _AgendaRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String meta;

  const _AgendaRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Row(
        children: [
          IconChipLite(icon: icon, color: iconColor, bg: iconBg, size: 30),
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
          Icon(Icons.chevron_right_rounded,
              size: 16, color: AppPalette.faint),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- runs
class _UpcomingRuns extends StatelessWidget {
  final WorkspaceState state;
  final DateTime now;

  const _UpcomingRuns({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final upcoming = [...state.pickups]..sort((a, b) => a.date.compareTo(b.date));
    return SectionCard(
      icon: Icons.local_shipping_outlined,
      title: 'All upcoming pickups',
      subtitle: '${upcoming.length} run(s) on the schedule.',
      child: Column(
        children: [
          for (var i = 0; i < upcoming.length; i++)
            StaggerIn(
              index: i,
              child: Column(
                children: [
                  _RunLine(pickup: upcoming[i], now: now),
                  if (i < upcoming.length - 1) const Divider(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RunLine extends StatelessWidget {
  final Pickup pickup;
  final DateTime now;
  const _RunLine({required this.pickup, required this.now});

  @override
  Widget build(BuildContext context) {
    final diff = pickup.date.difference(now).inDays;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: AppPalette.fill,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppPalette.stroke),
            ),
            child: Column(
              children: [
                Text('${pickup.date.day}',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink)),
                Text(DateFormat('MMM').format(pickup.date).toUpperCase(),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppPalette.muted)),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickup.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink)),
                Text('${pickup.venue} · ${pickup.itemCount} items · ${pickup.contactName}',
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
            label: diff <= 0 ? 'Today' : 'In $diff days',
            fg: diff <= 1 ? AppPalette.amber : AppPalette.green,
            bg: diff <= 1 ? AppPalette.amberBg : AppPalette.greenBg,
          ),
        ],
      ),
    );
  }
}

/// Entry point used by every “Open calendar” affordance.
void openCalendar(BuildContext context) {
  Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CalendarScreen()));
}
