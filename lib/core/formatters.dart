import 'package:intl/intl.dart';

import 'app_locale.dart';
import 'ethiopian_calendar.dart';

/// Money / date / number formatting helpers — all locale- and
/// calendar-aware.
///
///  * Money is Ethiopian Birr: "Br 1,840" (en) / "ብር 1,840" (am).
///  * Dates render in the user's calendar system (Ethiopian 13-month or
///    Gregorian) and language — see [AppLocale] and [EthiopianCalendar].
///  * Underlying business data always stores Gregorian DateTimes; this is
///    a pure presentation layer.
class Fmt {
  Fmt._();

  static final NumberFormat _num = NumberFormat.decimalPattern();

  // ------------------------------------------------------------- money

  /// Whole-birr money: "Br 1,840" / "ብር 1,840".
  static String money(num v) => '${AppLocale.birr} ${_num.format(v.round())}';

  /// Money that always keeps two decimals (rates, unit prices).
  static String moneyCents(num v) =>
      '${AppLocale.birr} ${NumberFormat('#,##0.00').format(v)}';

  /// Honest money: whole amounts stay clean ("Br 1,840"), amounts that
  /// actually carry cents keep them ("Br 1,840.50") — displaying a
  /// Br 1,840.50 rental as "Br 1,841" misstates what the front desk must
  /// collect and makes the payment-plan pieces stop adding up.
  static String moneySmart(num v) =>
      v == v.roundToDouble() ? money(v) : moneyCents(v);

  /// "$n items" with correct singular ("1 item" / "1 እቃ").
  static String items(int n) => AppLocale.items(n);

  /// Compact money for chart axes / tight KPIs: "Br 1.8k" / "ብር 1.8k".
  static String compactMoney(num v) {
    if (v >= 1000) {
      final k = v / 1000;
      // 289.k reads wrong — only show a decimal for magnitudes that
      // actually need it (below 100k).
      final s = (k >= 100 || k == k.roundToDouble())
          ? k.toStringAsFixed(0)
          : k.toStringAsFixed(1);
      return '${AppLocale.birr} ${s}k';
    }
    return money(v);
  }

  /// Plain grouped number (no currency) — used where the unit is already
  /// in the label, e.g. "Utilization Br".
  static String number(num v) => _num.format(v.round());

  /// Legacy alias kept for call sites that wanted a currency-less group.
  static String compactNumber(num v) {
    if (v >= 1000) {
      final k = v / 1000;
      final s = k == k.roundToDouble()
          ? k.toStringAsFixed(0)
          : k.toStringAsFixed(1);
      return '$s.k';
    }
    return _num.format(v.round());
  }

  // ------------------------------------------------------------- dates

  /// "Ginbot 10, 2018" / "ግንቦት 10, 2018" / "Oct 20, 2026" / "ኦክቶበር 20, 2026"
  /// — honors the active calendar system + language.
  static String shortDate(DateTime d) => AppLocale.shortDate(d);

  /// Long form with weekday: "Monday, Ginbot 10, 2018".
  static String longDate(DateTime d) => AppLocale.longDate(d);

  /// "Ginbot 10" / "Oct 20" — no year.
  static String dayMonth(DateTime d) => AppLocale.dayMonth(d);

  /// Day number for the pickup date block (EC day in Ethiopian mode).
  static String dayNumber(DateTime d) => AppLocale.blockDay(d);

  /// Month word for the pickup date block ("OCT" / "ግንቦት").
  static String monthUpper(DateTime d) => AppLocale.blockMonth(d);

  /// "10:45 AM" / "10:45 ጠዋት".
  static String timeOfDay(DateTime d) => AppLocale.timeOfDay(d);

  /// "Mon" / "ሰኞ" — short weekday for tight rows.
  static String shortWeekday(DateTime d) {
    if (AppLocale.isAmharic) return AppLocale.weekdayName(d);
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return en[d.weekday - 1];
  }

  /// "Mon, Oct 20" / "ሰኞ, ግንቦት 20".
  static String shortWeekdayDate(DateTime d) =>
      '${shortWeekday(d)}, ${AppLocale.dayMonth(d)}';

  /// "Mon 10:45 AM" / "ሰኞ 10:45 ጠዋት".
  static String shortWeekdayTime(DateTime d) =>
      '${shortWeekday(d)} ${timeOfDay(d)}';

  /// "October 2026" / "ኦክቶበር 2026" — Gregorian month + year label.
  static String monthYear(DateTime d) =>
      '${AppLocale.gcMonthName(d)} ${d.year}';

  /// "Monday, October 20" / "ሰኞ, ግንቦት 20" (weekday + day-month).
  static String weekdayMonth(DateTime d) =>
      '${AppLocale.weekdayName(d)}, ${AppLocale.dayMonth(d)}';

  /// "Oct 20, 10:45 AM" — timestamps on payment rows / activity.
  static String shortDateTime(DateTime d) =>
      '${shortDate(d)} · ${timeOfDay(d)}';

  static String uppercase(String s) => s.toUpperCase();

  /// Relative label: "Today" / "Tomorrow" / "In 4 days" / "ዛሬ" / "ነገ" /
  /// "በ4 ቀን ውስጥ".
  static String inDays(DateTime target, DateTime from) {
    final diff = DateTime(target.year, target.month, target.day)
        .difference(DateTime(from.year, from.month, from.day))
        .inDays;
    return AppLocale.relativeDay(diff);
  }

  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Weekday header cells for month grids. Weekday NAMES are
  /// calendar-system independent (እሑድ is Sunday in both), so this only
  /// depends on language — and weeks always open on Sunday (እሑድ),
  /// the Ethiopian convention.
  static List<String> weekdayHeaders() => AppLocale.isAmharic
      ? EthiopianCalendar.weekdayHeadersAm
      : EthiopianCalendar.weekdayHeadersEn;
}
