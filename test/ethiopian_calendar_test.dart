import 'package:flutter_test/flutter_test.dart';
import 'package:rentwise/core/app_locale.dart';
import 'package:rentwise/core/ethiopian_calendar.dart';
import 'package:rentwise/core/formatters.dart';
import 'package:rentwise/models/rental_order.dart';

/// Ethiopian calendar engine — verified against known date pairs.
void main() {
  group('EthiopianCalendar conversions', () {
    test('Enkutatash 2017 EC = Sept 11, 2024 GC', () {
      final ec = EthiopianCalendar.fromGregorian(DateTime(2024, 9, 11));
      expect(ec.year, 2017);
      expect(ec.month, 1);
      expect(ec.day, 1);
      final back = EthiopianCalendar.toGregorian(2017, 1, 1);
      expect(back.year, 2024);
      expect(back.month, 9);
      expect(back.day, 11);
    });

    test('2026-10-20 GC = Tikimt 10, 2019 EC', () {
      final ec = EthiopianCalendar.fromGregorian(DateTime(2026, 10, 20));
      expect(ec.year, 2019);
      expect(ec.month, 2);
      expect(ec.day, 10);
    });

    test('EC leap year (2015): Pagume 6 = Sept 11, 2023; next new year Sept 12',
        () {
      expect(EthiopianCalendar.isLeapYear(2015), isTrue);
      expect(EthiopianCalendar.daysInMonth(2015, 13), 6);
      final pagume6 = EthiopianCalendar.toGregorian(2015, 13, 6);
      expect(pagume6, DateTime(2023, 9, 11));
      // The year AFTER a leap year starts a day later in GC terms.
      final nextNewYear = EthiopianCalendar.toGregorian(2016, 1, 1);
      expect(nextNewYear, DateTime(2023, 9, 12));
    });

    test('non-leap Pagume has 5 days', () {
      expect(EthiopianCalendar.isLeapYear(2018), isFalse);
      expect(EthiopianCalendar.daysInMonth(2018, 13), 5);
    });

    test('all 12 regular months have exactly 30 days', () {
      for (var m = 1; m <= 12; m++) {
        expect(EthiopianCalendar.daysInMonth(2019, m), 30, reason: 'month $m');
      }
    });

    test('round-trip GC → EC → GC over a wide date range', () {
      var d = DateTime(2020, 1, 1);
      const step = Duration(days: 37);
      while (d.isBefore(DateTime(2035, 1, 1))) {
        final ec = EthiopianCalendar.fromGregorian(d);
        final back = EthiopianCalendar.toGregorian(ec.year, ec.month, ec.day);
        expect(back, d, reason: 'round-trip failed for $d');
        d = d.add(step);
      }
    });

    test('month grid cells: Pagume of a leap year shows 6 day cells', () {
      final cells =
          EthiopianCalendar.monthCells(2015, 13).whereType<int>().toList();
      expect(cells.length, 6);
      expect(cells.last, 6);
    });

    test('month grid cells: rows align to 7 columns', () {
      for (var m = 1; m <= 13; m++) {
        final cells = EthiopianCalendar.monthCells(2019, m);
        expect(cells.length % 7, 0, reason: 'EC month $m');
      }
    });
  });

  group('AppLocale + Fmt', () {
    setUp(() {
      AppLocale.set(language: AppLanguage.en, calendarSystem: CalendarSystem.gregorian);
    });

    test('money renders Birr in both languages', () {
      AppLocale.set(language: AppLanguage.en);
      expect(Fmt.money(1840), 'Br 1,840');
      AppLocale.set(language: AppLanguage.am);
      expect(Fmt.money(1840), 'ብር 1,840');
    });

    test('moneySmart keeps cents only when they exist', () {
      AppLocale.set(language: AppLanguage.en);
      expect(Fmt.moneySmart(1840), 'Br 1,840');
      expect(Fmt.moneySmart(1840.5), 'Br 1,840.50');
    });

    test('t() falls back to English for unknown keys, never shows raw key',
        () {
      AppLocale.set(language: AppLanguage.am);
      expect(AppLocale.t('Orders'), 'ትዕዛዞች');
      expect(AppLocale.t('Definitely Not A Key 42'), 'Definitely Not A Key 42');
      AppLocale.set(language: AppLanguage.en);
      expect(AppLocale.t('Orders'), 'Orders');
    });

    test('tr() replaces the number slot after translation', () {
      AppLocale.set(language: AppLanguage.am);
      expect(AppLocale.tr('{n} available', 7), '7 ክፍት');
      AppLocale.set(language: AppLanguage.en);
      expect(AppLocale.tr('{n} available', 7), '7 available');
    });

    test('Ethiopian + English renders transliterated month names', () {
      AppLocale.set(
          language: AppLanguage.en, calendarSystem: CalendarSystem.ethiopic);
      expect(Fmt.shortDate(DateTime(2026, 10, 20)), 'Tikimt 10, 2019');
      expect(Fmt.dayMonth(DateTime(2026, 10, 20)), 'Tikimt 10');
    });

    test('Ethiopian + Amharic renders Ge\'ez month names', () {
      AppLocale.set(
          language: AppLanguage.am, calendarSystem: CalendarSystem.ethiopic);
      expect(Fmt.shortDate(DateTime(2026, 10, 20)), 'ጥቅምት 10, 2019');
    });

    test('Gregorian + Amharic renders transliterated GC months', () {
      AppLocale.set(
          language: AppLanguage.am, calendarSystem: CalendarSystem.gregorian);
      expect(Fmt.shortDate(DateTime(2026, 10, 20)), 'ኦክቶበር 20, 2026');
    });

    test('date block respects the calendar system', () {
      AppLocale.set(
          language: AppLanguage.en, calendarSystem: CalendarSystem.ethiopic);
      expect(Fmt.dayNumber(DateTime(2026, 10, 20)), '10');
      expect(Fmt.monthUpper(DateTime(2026, 10, 20)), 'Tikimt');
      AppLocale.set(
          language: AppLanguage.en, calendarSystem: CalendarSystem.gregorian);
      expect(Fmt.dayNumber(DateTime(2026, 10, 20)), '20');
      expect(Fmt.monthUpper(DateTime(2026, 10, 20)), 'OCT');
    });

    test('weekday headers are Sunday-first', () {
      expect(Fmt.weekdayHeaders().first,
          anyOf('እ', 'Su')); // እሑድ / Sunday opens the week
      AppLocale.set(language: AppLanguage.en);
      expect(Fmt.weekdayHeaders(), ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']);
    });

    test('relative days localize', () {
      AppLocale.set(language: AppLanguage.am);
      expect(AppLocale.relativeDay(0), 'ዛሬ');
      expect(AppLocale.relativeDay(1), 'ነገ');
      expect(AppLocale.relativeDay(4), 'በ4 ቀን ውስጥ');
      AppLocale.set(language: AppLanguage.en);
      expect(AppLocale.relativeDay(0), 'Today');
      expect(AppLocale.relativeDay(4), 'In 4 days');
    });

    test('Amharic time uses Ethiopian day periods', () {
      AppLocale.set(language: AppLanguage.am);
      expect(AppLocale.timeOfDay(DateTime(2026, 1, 1, 9, 5)), '9:05 ጠዋት');
      expect(AppLocale.timeOfDay(DateTime(2026, 1, 1, 15, 30)), '3:30 ከሰዓት');
      expect(AppLocale.timeOfDay(DateTime(2026, 1, 1, 20, 0)), '8:00 ምሽት');
      AppLocale.set(language: AppLanguage.en);
      expect(AppLocale.timeOfDay(DateTime(2026, 1, 1, 15, 30)), '3:30 PM');
    });
  });

  group('PaymentMethod', () {
    test('brand names stay Latin in every language', () {
      AppLocale.set(language: AppLanguage.am);
      final telebirr = PaymentMethod.values
          .firstWhere((m) => m.name == 'telebirr');
      expect(telebirr.label, 'Telebirr');
      AppLocale.set(language: AppLanguage.en);
      expect(telebirr.label, 'Telebirr');
    });

    test('doc round-trips by name', () {
      for (final m in PaymentMethod.values) {
        expect(PaymentMethodX.fromDoc(m.name), m);
      }
      expect(PaymentMethodX.fromDoc(null), isNull);
      expect(PaymentMethodX.fromDoc('not-a-method'), isNull);
    });
  });
}
