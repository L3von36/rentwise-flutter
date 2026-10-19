import 'amharic_strings.dart';
import 'ethiopian_calendar.dart';

/// App language. English is the default; አማርኛ is a first-class UI.
enum AppLanguage { en, am }

/// Which calendar the whole app renders dates with.
enum CalendarSystem { ethiopic, gregorian }

/// Global locale mirror — the same pattern as `AppPalette.brightness`.
///
/// Static so formatters (`Fmt`) and model labels (order status text,
/// blockers) can localize without dragging a BuildContext through every
/// call. `ShellState` is the single writer: it restores persisted choices
/// at boot and updates the mirror BEFORE notifying listeners, and the
/// MaterialApp re-keys so every widget rebuilds against the new locale.
abstract class AppLocale {
  AppLocale._();

  static AppLanguage _language = AppLanguage.en;
  static CalendarSystem _calendar = CalendarSystem.gregorian;

  static AppLanguage get language => _language;
  static CalendarSystem get calendarSystem => _calendar;

  static bool get isAmharic => _language == AppLanguage.am;
  static bool get isEthiopic => _calendar == CalendarSystem.ethiopic;

  /// Called by [ShellState] before the first frame and on every change.
  static void set({AppLanguage? language, CalendarSystem? calendarSystem}) {
    if (language != null) _language = language;
    if (calendarSystem != null) _calendar = calendarSystem;
  }

  // ------------------------------------------------------------- lookup

  /// Contextual English → Amharic UI dictionary (see amharic_strings.dart).
  /// Keys are the exact English source strings used in the app; values are
  /// what an Ethiopian rental-business user would actually say — NOT
  /// word-for-word renderings.
  static String t(String en) =>
      isAmharic ? (amharicStrings[en] ?? en) : en;

  /// Translate a template containing ONE `{n}` slot, replacing the slot
  /// AFTER translation so Amharic word order around the number stays
  /// natural: tr('In {n} days', 4) → "በ4 ቀን ውስጥ".
  static String tr(String template, Object n) {
    final s = isAmharic ? (amharicStrings[template] ?? template) : template;
    return s.replaceFirst('{n}', '$n');
  }

  /// Translate a template with NAMED slots ({n}, {c}, {m}, …) replaced
  /// AFTER translation — Amharic sentences move the pieces around, so
  /// interpolation must happen on the localized string.
  static String tf(String template, Map<String, Object> slots) {
    var s = isAmharic ? (amharicStrings[template] ?? template) : template;
    slots.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  // ------------------------------------------------------------ dates

  static const List<String> _gcMonthsShortEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _gcMonthsLongEn = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _gcWeekdaysLongAm = [
    'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ',
  ];
  static const List<String> _gcWeekdaysLongEn = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  static String _gcMonthShort(DateTime d) => isAmharic
      ? kGregorianMonthsAm[d.month - 1]
      : _gcMonthsShortEn[d.month - 1];

  static String gcMonthName(DateTime d) => isAmharic
      ? kGregorianMonthsAm[d.month - 1]
      : _gcMonthsLongEn[d.month - 1];

  /// Gregorian month name by index (1-12), honoring the language.
  static String gcMonthOf(int month) => isAmharic
      ? kGregorianMonthsAm[month - 1]
      : _gcMonthsLongEn[month - 1];

  static String weekdayName(DateTime d) => isAmharic
      ? _gcWeekdaysLongAm[d.weekday - 1]
      : _gcWeekdaysLongEn[d.weekday - 1];

  /// "Ginbot 10, 2018" / "Oct 20, 2026" — respects calendar + language.
  static String shortDate(DateTime d) {
    if (isEthiopic) return EthiopianCalendar.formatShort(d, _language);
    return '${_gcMonthShort(d)} ${d.day}, ${d.year}';
  }

  /// "ሰኞ, ግንቦት 10, 2018" / "Monday, October 20, 2026".
  static String longDate(DateTime d) {
    if (isEthiopic) return EthiopianCalendar.formatLong(d, _language);
    return '${weekdayName(d)}, ${gcMonthName(d)} ${d.day}, ${d.year}';
  }

  /// "ግንቦት 10" / "Oct 20" — no year.
  static String dayMonth(DateTime d) {
    if (isEthiopic) return EthiopianCalendar.formatDayMonth(d, _language);
    return '${_gcMonthShort(d)} ${d.day}';
  }

  /// Day-number for date tiles ("18 OCT" block) — EC day in Ethiopian mode.
  static String blockDay(DateTime d) =>
      isEthiopic ? '${EthiopianCalendar.fromGregorian(d).day}' : '${d.day}';

  /// Month word for date tiles ("OCT" / "ግንቦት").
  static String blockMonth(DateTime d) => isEthiopic
      ? EthiopianCalendar.monthName(
          EthiopianCalendar.fromGregorian(d).month, _language)
      : _gcMonthShort(d).toUpperCase();

  /// The OTHER calendar's rendering of the same date — shown in pickers
  /// and the profile preview so the two systems are always cross-readable.
  static String otherSystemDate(DateTime d) {
    final ecActive = isEthiopic;
    if (ecActive) {
      return '${_gcMonthShort(d)} ${d.day}, ${d.year}';
    }
    return EthiopianCalendar.formatShort(d, _language);
  }

  // ------------------------------------------------------- money & misc

  /// Birr symbol: "Br" (en) / "ብር" (am).
  static String get birr => isAmharic ? 'ብር' : 'Br';

  static String items(int n) => isAmharic
      ? (n == 1 ? '1 እቃ' : '$n እቃዎች')
      : (n == 1 ? '1 item' : '$n items');

  static String relativeDay(int diff) {
    if (isAmharic) {
      return switch (diff) {
        0 => 'ዛሬ',
        1 => 'ነገ',
        -1 => 'ትናንት',
        _ => diff > 0 ? 'በ$diff ቀን ውስጥ' : '${-diff} ቀን በፊት',
      };
    }
    return switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => diff > 0 ? 'In $diff days' : '${-diff} days ago',
    };
  }

  /// 12-hour clock with Amharic day periods (ጠዋት / ከሰዓት / ምሽት / ሌሊት) —
  /// how times are actually spoken in Ethiopia. English keeps AM/PM.
  static String timeOfDay(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    if (!isAmharic) {
      return '$h12:$mm ${d.hour < 12 ? 'AM' : 'PM'}';
    }
    final period = switch (d.hour) {
      < 5 => 'ሌሊት',
      < 12 => 'ጠዋት',
      < 18 => 'ከሰዓት',
      _ => 'ምሽት',
    };
    return '$h12:$mm $period';
  }
}
