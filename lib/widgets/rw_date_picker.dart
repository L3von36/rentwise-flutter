import 'package:flutter/material.dart';

import '../core/app_locale.dart';
import '../core/app_theme.dart';
import '../core/ethiopian_calendar.dart';
import '../core/palette.dart';

/// App-wide date picker — one dialog, two calendar systems.
///
///  * Ethiopian mode: a real 13-month Ge'ez grid (መስከረም…ጳጉሜ, 30-day
///    months, 5/6-day Pagume) with the equivalent Gregorian date always
///    shown under the header.
///  * Gregorian mode: the familiar month grid.
///  * The ዓ.ም / እ.ኤ.አ toggle inside the dialog converts the visible
///    month in place, so a user who thinks in Ethiopian dates can still
///    hand a Gregorian date to a supplier (and vice versa).
///
/// Weeks are Sunday-first — እሑድ opens the Ethiopian week, and weekday
/// NAMES are calendar-system independent anyway.
///
/// Returns a plain Gregorian [DateTime] (midnight, local) — the app
/// stores GC dates everywhere; this dialog is presentation only.
Future<DateTime?> showRwDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (_) => _RwDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _RwDatePickerDialog extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _RwDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_RwDatePickerDialog> createState() => _RwDatePickerDialogState();
}

class _RwDatePickerDialogState extends State<_RwDatePickerDialog> {
  late CalendarSystem _system;
  DateTime? _selected; // GC date
  // Visible month in the ACTIVE system.
  late int _ecYear, _ecMonth; // 1..13
  late int _gcYear, _gcMonth;

  DateTime get _initial =>
      widget.initialDate ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _system = AppLocale.calendarSystem;
    _selected = _clampDay(_initial);
    _syncVisibleMonthsFrom(_selected!);
  }

  DateTime _clampDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  void _syncVisibleMonthsFrom(DateTime gc) {
    final ec = EthiopianCalendar.fromGregorian(gc);
    _ecYear = ec.year;
    _ecMonth = ec.month;
    _gcYear = gc.year;
    _gcMonth = gc.month;
  }

  bool _inRange(DateTime d) =>
      !d.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month,
          widget.firstDate.day)) &&
      !d.isAfter(DateTime(
          widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));

  void _stepMonth(int dir) {
    setState(() {
      if (_system == CalendarSystem.ethiopic) {
        _ecMonth += dir;
        if (_ecMonth > 13) {
          _ecMonth = 1;
          _ecYear++;
        }
        if (_ecMonth < 1) {
          _ecMonth = 13;
          _ecYear--;
        }
      } else {
        _gcMonth += dir;
        if (_gcMonth > 12) {
          _gcMonth = 1;
          _gcYear++;
        }
        if (_gcMonth < 1) {
          _gcMonth = 12;
          _gcYear--;
        }
      }
    });
  }

  void _switchSystem(CalendarSystem s) {
    if (s == _system) return;
    setState(() {
      _system = s;
      // Keep looking at the same moment — convert the visible month.
      final anchor = _selected ?? _todayGC();
      _syncVisibleMonthsFrom(anchor);
    });
  }

  DateTime _todayGC() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ------------------------------------------------------------- cells

  /// (dayNumber, gcDate) pairs, null for leading blanks.
  List<(int, DateTime)?> get _cells {
    if (_system == CalendarSystem.ethiopic) {
      return [
        for (final c in EthiopianCalendar.monthCells(_ecYear, _ecMonth))
          c == null
              ? null
              : (c, EthiopianCalendar.toGregorian(_ecYear, _ecMonth, c)),
      ];
    }
    final first = DateTime(_gcYear, _gcMonth, 1);
    final days = DateTime(_gcYear, _gcMonth + 1, 0).day;
    final leading = first.weekday % 7; // Sunday-first
    final cells = <(int, DateTime)?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= days; d++) (d, DateTime(_gcYear, _gcMonth, d)),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  // ------------------------------------------------------------ builders

  @override
  Widget build(BuildContext context) {
    final title = _system == CalendarSystem.ethiopic
        ? '${EthiopianCalendar.monthName(_ecMonth, AppLocale.language)} '
            '$_ecYear ${EthiopianCalendar.era(AppLocale.language)}'
        : '${AppLocale.gcMonthOf(_gcMonth)} $_gcYear';

    final isAm = AppLocale.isAmharic;
    final headers = isAm
        ? EthiopianCalendar.weekdayHeadersAm
        : EthiopianCalendar.weekdayHeadersEn;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.raise,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- system toggle
            _SystemToggle(current: _system, onChanged: _switchSystem),
            const SizedBox(height: 12),
            // ---- header
            Row(
              children: [
                _NavBtn(
                    icon: Icons.chevron_left_rounded, onTap: () => _stepMonth(-1)),
                Expanded(
                  child: Text(title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.ink)),
                ),
                _NavBtn(
                    icon: Icons.chevron_right_rounded, onTap: () => _stepMonth(1)),
              ],
            ),
            const SizedBox(height: 4),
            // cross-system hint — the same moment in the other calendar
            Center(
              child: Text(
                _system == CalendarSystem.ethiopic
                    ? '${AppLocale.t('Gregorian')}: ${_visibleMonthGcLabel()}'
                    : '${AppLocale.t('Ethiopian')}: ${_visibleMonthEcLabel()}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: AppPalette.muted),
              ),
            ),
            const SizedBox(height: 10),
            // ---- weekday header
            Row(
              children: [
                for (final h in headers)
                  Expanded(
                    child: Text(h,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.faint)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // ---- grid
            for (var r = 0; r < _cells.length / 7; r++)
              Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(child: _cell(_cells[r * 7 + c])),
                ],
              ),
            const SizedBox(height: 10),
            // ---- footer
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    final t = _todayGC();
                    if (_inRange(t)) {
                      setState(() {
                        _selected = t;
                        _syncVisibleMonthsFrom(t);
                      });
                    }
                  },
                  child: Text(AppLocale.t('Today'),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocale.t('Cancel'),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.muted)),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  child: Text(AppLocale.t('OK'),
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.primary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _visibleMonthEcLabel() {
    // First day of the visible EC month, rendered in EC form.
    final first = EthiopianCalendar.toGregorian(_ecYear, _ecMonth, 1);
    return EthiopianCalendar.formatShort(first, AppLocale.language);
  }

  String _visibleMonthGcLabel() {
    if (_system == CalendarSystem.ethiopic) {
      final first = EthiopianCalendar.toGregorian(_ecYear, _ecMonth, 1);
      return '${AppLocale.gcMonthOf(first.month)} ${first.year}';
    }
    return '${AppLocale.gcMonthOf(_gcMonth)} $_gcYear';
  }

  Widget _cell((int, DateTime)? cell) {
    if (cell == null) return const SizedBox(height: 36);
    final (day, gc) = cell;
    final isSelected =
        _selected != null && EthiopianCalendar.sameDay(_selected!, gc);
    final isToday = EthiopianCalendar.sameDay(_todayGC(), gc);
    final enabled = _inRange(gc);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => setState(() => _selected = gc) : null,
      child: Container(
        height: 36,
        margin: const EdgeInsets.all(1.5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.primary
              : isToday
                  ? AppPalette.primarySoft
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected
                ? AppPalette.primary
                : isToday
                    ? AppPalette.primaryBorder
                    : Colors.transparent,
          ),
        ),
        child: Text('$day',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight:
                    isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                color: !enabled
                    ? AppPalette.faint
                    : isSelected
                        ? Colors.white
                        : isToday
                            ? AppPalette.primary
                            : AppPalette.body)),
      ),
    );
  }
}

class _SystemToggle extends StatelessWidget {
  final CalendarSystem current;
  final ValueChanged<CalendarSystem> onChanged;

  const _SystemToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppPalette.fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final (system, label) in [
            (CalendarSystem.ethiopic,
                AppLocale.isAmharic ? 'ዓ.ም' : AppLocale.t('Ethiopian')),
            (CalendarSystem.gregorian,
                AppLocale.isAmharic ? 'እ.ኤ.አ' : AppLocale.t('Gregorian')),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(system),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: current == system
                        ? AppPalette.raise
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: current == system
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: current == system
                              ? AppPalette.primary
                              : AppPalette.muted)),
                ),
              ),
            ),
        ],
      ),
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
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 16, color: AppPalette.body),
        ),
      ),
    );
  }
}
