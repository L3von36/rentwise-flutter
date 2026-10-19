import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_locale.dart';
import '../../core/app_theme.dart';
import '../../core/ethiopian_calendar.dart';
import '../../core/formatters.dart';
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
///
/// Renders in the ACTIVE calendar system: the Ethiopian 13-month grid
/// (መስከረም…ጳጉሜ) or the Gregorian grid — same dots, same agenda, the
/// month the operator thinks in. Weeks open on እሑድ (Sunday).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Visible month in the ACTIVE calendar system.
  int? _ecYear, _ecMonth;
  int? _gcYear, _gcMonth;
  DateTime? _selected; // always a Gregorian date

  @override
  void initState() {
    super.initState();
    _syncToday();
  }

  void _syncToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selected = today;
    if (AppLocale.isEthiopic) {
      final ec = EthiopianCalendar.fromGregorian(today);
      _ecYear = ec.year;
      _ecMonth = ec.month;
      _gcYear = null;
      _gcMonth = null;
    } else {
      _gcYear = now.year;
      _gcMonth = now.month;
      _ecYear = null;
      _ecMonth = null;
    }
  }

  void _stepMonth(int dir) {
    setState(() {
      if (AppLocale.isEthiopic) {
        _ecMonth = _ecMonth! + dir;
        if (_ecMonth! > 13) {
          _ecMonth = 1;
          _ecYear = _ecYear! + 1;
        }
        if (_ecMonth! < 1) {
          _ecMonth = 13;
          _ecYear = _ecYear! - 1;
        }
      } else {
        _gcMonth = _gcMonth! + dir;
        if (_gcMonth! > 12) {
          _gcMonth = 1;
          _gcYear = _gcYear! + 1;
        }
        if (_gcMonth! < 1) {
          _gcMonth = 12;
          _gcYear = _gcYear! - 1;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkspaceState>();
    final now = DateTime.now();
    final pickups = state.pickups;

    return DetailPage(
      eyebrow: AppLocale.t('Calendar'),
      title: AppLocale.t('Pickup calendar'),
      subtitle: AppLocale.t('Pickups and event dates'),
      icon: Icons.calendar_month_outlined,
      actions: [
        OutlineButton(
          label: AppLocale.t('Today'),
          icon: Icons.today_outlined,
          onTap: () => setState(_syncToday),
        ),
      ],
      body: LayoutBuilder(builder: (context, box) {
        // ≥960px: month grid + agenda stay left, the pickups rail moves
        // right — instead of stretching the phone column across the
        // whole window.
        final wide = box.maxWidth >= 960;
        final grid = _MonthGrid(
          ecYear: _ecYear,
          ecMonth: _ecMonth,
          gcYear: _gcYear,
          gcMonth: _gcMonth,
          selected: _selected,
          now: now,
          pickups: pickups,
          orders: state.orders,
          onPrev: () => _stepMonth(-1),
          onNext: () => _stepMonth(1),
          onSelect: (d) => setState(() => _selected = d),
        );
        final agenda = _AgendaCard(
          day: _selected,
          pickups: pickups,
          orders: state.orders,
        );
        final runs = _UpcomingRuns(state: state, now: now);
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              grid,
              const SizedBox(height: 14),
              agenda,
              const SizedBox(height: 14),
              runs,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  grid,
                  const SizedBox(height: 14),
                  agenda,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: runs),
          ],
        );
      }),
    );
  }
}

// ---------------------------------------------------------------- month grid
class _MonthGrid extends StatelessWidget {
  final int? ecYear, ecMonth;
  final int? gcYear, gcMonth;
  final DateTime? selected;
  final DateTime now;
  final List<Pickup> pickups;
  final List<RentalOrder> orders;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  const _MonthGrid({
    required this.ecYear,
    required this.ecMonth,
    required this.gcYear,
    required this.gcMonth,
    required this.selected,
    required this.now,
    required this.pickups,
    required this.orders,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  Set<int> get _pickupDays {
    if (AppLocale.isEthiopic) {
      return pickups
          .map((p) => EthiopianCalendar.fromGregorian(p.date))
          .where((ec) => ec.year == ecYear && ec.month == ecMonth)
          .map((ec) => ec.day)
          .toSet();
    }
    return pickups
        .where((p) =>
            p.date.year == gcYear && p.date.month == gcMonth)
        .map((p) => p.date.day)
        .toSet();
  }

  Set<int> get _eventDays {
    if (AppLocale.isEthiopic) {
      return orders
          .map((o) => EthiopianCalendar.fromGregorian(o.eventDate))
          .where((ec) => ec.year == ecYear && ec.month == ecMonth)
          .map((ec) => ec.day)
          .toSet();
    }
    return orders
        .where((o) => o.eventDate.year == gcYear && o.eventDate.month == gcMonth)
        .map((o) => o.eventDate.day)
        .toSet();
  }

  /// (dayNumber, gcDate) cells, null = blank.
  List<(int, DateTime)?> get _cells {
    if (AppLocale.isEthiopic) {
      return [
        for (final c in EthiopianCalendar.monthCells(ecYear!, ecMonth!))
          c == null ? null : (c, EthiopianCalendar.toGregorian(ecYear!, ecMonth!, c)),
      ];
    }
    final first = DateTime(gcYear!, gcMonth!, 1);
    final days = DateTime(gcYear!, gcMonth! + 1, 0).day;
    final leading = first.weekday % 7; // Sunday-first
    final cells = <(int, DateTime)?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= days; d++) (d, DateTime(gcYear!, gcMonth!, d)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  String get _title {
    if (AppLocale.isEthiopic) {
      return '${EthiopianCalendar.monthName(ecMonth!, AppLocale.language)} '
          '$ecYear ${EthiopianCalendar.era(AppLocale.language)}';
    }
    return '${AppLocale.gcMonthOf(gcMonth!)} $gcYear';
  }

  @override
  Widget build(BuildContext context) {
    final cells = _cells;
    final headers = Fmt.weekdayHeaders();

    return SectionCard(
      icon: Icons.calendar_month_outlined,
      title: _title,
      subtitle: AppLocale.t('Indigo = event date · green = pickup run'),
      child: Column(
        children: [
          Row(
            children: [
              _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
              const Spacer(),
              _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final wd in headers)
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

  Widget _cellFor((int, DateTime)? cell) {
    if (cell == null) return const SizedBox(height: 40);
    final (day, date) = cell;
    final hasPickup = _pickupDays.contains(day);
    final hasEvent = _eventDays.contains(day);
    final isSelected =
        selected != null && EthiopianCalendar.sameDay(selected!, date);
    final isToday = EthiopianCalendar.sameDay(now, date);

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
        : pickups.where((p) => EthiopianCalendar.sameDay(p.date, day!)).toList();
    final dayOrders = day == null
        ? <RentalOrder>[]
        : orders.where((o) => EthiopianCalendar.sameDay(o.eventDate, day!)).toList();
    final empty = dayPickups.isEmpty && dayOrders.isEmpty;

    return SectionCard(
      icon: Icons.event_note_outlined,
      title: day == null
          ? AppLocale.t('Agenda')
          : '${AppLocale.t('Agenda')} · ${Fmt.dayMonth(day!)}',
      child: empty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.event_busy_outlined,
                      size: 16, color: AppPalette.faint),
                  const SizedBox(width: 8),
                  Text(AppLocale.t('Nothing scheduled for this day.'),
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
                    child: _AgendaRow(
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppPalette.green,
                      iconBg: AppPalette.greenBg,
                      title:
                          AppLocale.t('Pickup · {n}').replaceFirst('{n}', dayPickups[i].title),
                      meta:
                          '${dayPickups[i].venue} · ${Fmt.items(dayPickups[i].itemCount)} · ${dayPickups[i].contactName}',
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
                        title:
                            AppLocale.t('Event · {n}').replaceFirst('{n}', dayOrders[i].eventName),
                        meta:
                            '#${dayOrders[i].id} · ${Fmt.items(dayOrders[i].itemCount)} · ${dayOrders[i].status.label}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
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
    // Runs from today onward — past runs belong to the returns flow,
    // not the upcoming schedule.
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = state.pickups
        .where((p) => !p.date.isBefore(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return SectionCard(
      icon: Icons.local_shipping_outlined,
      title: AppLocale.t('Upcoming pickups'),
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
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: AppPalette.fill,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppPalette.stroke),
            ),
            child: Column(
              children: [
                Text(Fmt.dayNumber(pickup.date),
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink)),
                Text(Fmt.monthUpper(pickup.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
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
                Text('${pickup.venue} · ${Fmt.items(pickup.itemCount)} · ${pickup.contactName}',
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
            label: Fmt.inDays(pickup.date, now),
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
