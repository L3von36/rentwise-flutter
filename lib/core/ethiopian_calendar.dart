import 'app_locale.dart';

/// Ethiopian (Ge'ez / Amete Mihret) calendar engine.
///
/// The Ethiopian calendar has 13 months — 12 × 30 days plus ጳጉሜ (Pagume)
/// of 5 days, 6 in a leap year. A year is leap when `year % 4 == 3`.
/// It runs 7–8 years behind the Gregorian calendar (the gap widens at the
/// Gregorian new year and closes again at Enkutatash, Sept 11 / 12 GC).
///
/// Everything in the app keeps storing real `DateTime` (Gregorian) values —
/// this engine is a pure presentation layer that converts for DISPLAY and
/// for the Ethiopian date picker. No business data ever lives in EC form.
///
/// Conversion uses JDN (Julian Day Number) arithmetic — exact, no floats.
class EthiopianCalendar {
  EthiopianCalendar._();

  /// JDN reference of the Amete Mihret count.
  static const int _epoch = 1723856;

  // ------------------------------------------------------------- names
  // Index 0 = Meskerem … 12 = Pagume. Ge'ez script for the Amharic UI,
  // transliteration for the English UI.
  static const List<String> monthsAm = [
    'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት',
    'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ',
  ];

  static const List<String> monthsEn = [
    'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit', 'Megabit',
    'Miyazya', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume',
  ];

  /// Weekday names in Dart weekday order (1 = Monday … 7 = Sunday).
  static const List<String> weekdaysAm = [
    'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ',
  ];
  static const List<String> weekdaysEn = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  /// Grid headers, Sunday-first — Ethiopian calendars open the week on
  /// እሑድ (Sunday).
  static const List<String> weekdayHeadersAm = ['እ', 'ሰ', 'ማ', 'ረ', 'ሐ', 'ዓ', 'ቅ'];
  static const List<String> weekdayHeadersEn = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  static String monthName(int ecMonth, AppLanguage lang) =>
      lang == AppLanguage.am ? monthsAm[ecMonth - 1] : monthsEn[ecMonth - 1];

  static String weekdayName(int gcWeekday, AppLanguage lang) =>
      lang == AppLanguage.am
          ? weekdaysAm[gcWeekday - 1]
          : weekdaysEn[gcWeekday - 1];

  // -------------------------------------------------------- conversions

  /// Gregorian y/m/d → Julian Day Number (integer).
  static int gregorianToJdn(int y, int m, int d) {
    final a = (m - 14) ~/ 12;
    return (1461 * (y + 4800 + a)) ~/ 4 +
        (367 * (m - 2 - 12 * a)) ~/ 12 -
        (3 * ((y + 4900 + a) ~/ 100)) ~/ 4 +
        d -
        32075;
  }

  /// JDN → Ethiopian date components.
  static ({int year, int month, int day}) ethiopicFromJdn(int jdn) {
    final r = (jdn - _epoch) % 1461;
    final n = (r % 365) + 365 * (r ~/ 1460);
    final year = 4 * ((jdn - _epoch) ~/ 1461) + (r ~/ 365) - (r ~/ 1460);
    final month = n ~/ 30 + 1;
    final day = (n % 30) + 1;
    return (year: year, month: month, day: day);
  }

  /// Ethiopian components → JDN.
  static int ethiopicToJdn(int year, int month, int day) =>
      _epoch +
      365 +
      365 * (year - 1) +
      year ~/ 4 +
      30 * (month - 1) +
      day -
      1;

  /// Gregorian DateTime → Ethiopian components.
  static ({int year, int month, int day}) fromGregorian(DateTime gc) =>
      ethiopicFromJdn(gregorianToJdn(gc.year, gc.month, gc.day));

  /// Ethiopian components → Gregorian DateTime (midnight, local).
  static DateTime toGregorian(int ecYear, int ecMonth, int ecDay) =>
      _gcFromJdn(ethiopicToJdn(ecYear, ecMonth, ecDay));

  /// JDN → Gregorian DateTime (midnight, local).
  static DateTime _gcFromJdn(int jdn) {
    final a = jdn + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - (146097 * b) ~/ 4;
    final d = (4 * c + 3) ~/ 1461;
    final e = c - (1461 * d) ~/ 4;
    final m = (5 * e + 2) ~/ 153;
    final day = e - (153 * m + 2) ~/ 5 + 1;
    final month = m + 3 - 12 * (m ~/ 10);
    final year = 100 * b + d - 4800 + (m ~/ 10);
    return DateTime(year, month, day);
  }

  /// Days in an Ethiopian month (ጳጉሜ has 6 days in a leap year).
  static int daysInMonth(int ecYear, int ecMonth) =>
      ecMonth == 13 ? (isLeapYear(ecYear) ? 6 : 5) : 30;

  /// Ethiopian leap year — every 4th year, offset one from Gregorian.
  static bool isLeapYear(int ecYear) => ecYear % 4 == 3;

  /// Dart weekday (1=Mon … 7=Sun) of the Gregorian date matching the
  /// given Ethiopian date.
  static int weekdayOf(int ecYear, int ecMonth, int ecDay) =>
      toGregorian(ecYear, ecMonth, ecDay).weekday;

  /// Today in Ethiopian components.
  static ({int year, int month, int day}) today() =>
      fromGregorian(DateTime.now());

  // -------------------------------------------------------- formatting

  /// "ግንቦት 10, 2018" (am) / "Ginbot 10, 2018" (en).
  static String formatShort(DateTime gc, AppLanguage lang) {
    final ec = fromGregorian(gc);
    return '${monthName(ec.month, lang)} ${ec.day}, ${ec.year}';
  }

  /// "ሰኞ, ግንቦት 10, 2018" (am) / "Monday, Ginbot 10, 2018" (en).
  static String formatLong(DateTime gc, AppLanguage lang) {
    final ec = fromGregorian(gc);
    return '${weekdayName(gc.weekday, lang)}, '
        '${monthName(ec.month, lang)} ${ec.day}, ${ec.year}';
  }

  /// "ግንቦት 10" (am) / "Ginbot 10" (en) — no year.
  static String formatDayMonth(DateTime gc, AppLanguage lang) {
    final ec = fromGregorian(gc);
    return '${monthName(ec.month, lang)} ${ec.day}';
  }

  /// Era suffix: "ዓ.ም" (am) / "EC" (en).
  static String era(AppLanguage lang) => lang == AppLanguage.am ? 'ዓ.ም' : 'EC';

  /// Month grid cells for an Ethiopian month: leading blank weekday slots
  /// (Sunday-first) then 1..days, padded with trailing blanks so the grid
  /// is always whole 7-cell rows. Null = blank cell.
  static List<int?> monthCells(int ecYear, int ecMonth) {
    final leading = weekdayOf(ecYear, ecMonth, 1) % 7; // Sunday-first
    final cells = <int?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth(ecYear, ecMonth); d++) d,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Gregorian month names for the Amharic UI — transliterated exactly how
/// Ethiopians say them (ጃንዋሪ, ፌብሯሪ, …), not archaic church forms.
const List<String> kGregorianMonthsAm = [
  'ጃንዋሪ', 'ፌብሯሪ', 'ማርች', 'ኤፕሪል', 'ሜይ', 'ጁን',
  'ጁላይ', 'ኦገስት', 'ሴፕቴምበር', 'ኦክቶበር', 'ኖቬምበር', 'ዲሴምበር',
];
