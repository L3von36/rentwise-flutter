import 'package:intl/intl.dart';

/// Money / date / number formatting helpers.
class Fmt {
  Fmt._();

  static final NumberFormat _money = NumberFormat.currency(
      symbol: '\$', decimalDigits: 0);
  static final NumberFormat _moneyCents = NumberFormat.currency(
      symbol: '\$', decimalDigits: 2);
  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _longDate = DateFormat('EEEE, MMMM d, yyyy');
  static final DateFormat _shortDate = DateFormat('MMM d, yyyy');

  static String money(num v) => _money.format(v);
  static String moneyCents(num v) => _moneyCents.format(v);

  /// Honest money: whole amounts stay clean ("$1,840"), amounts that
  /// actually carry cents keep them ("$1.50") — displaying a $1.50
  /// rental as "$2" misstates what the front desk must collect and
  /// makes the payment-plan pieces stop adding up.
  static String moneySmart(num v) =>
      v == v.roundToDouble() ? _money.format(v) : _moneyCents.format(v);

  /// "$n items" with correct singular ("1 item").
  static String items(int n) => n == 1 ? '1 item' : '$n items';

  static String compactMoney(num v) {
    if (v >= 1000) {
      final k = v / 1000;
      final s = k == k.roundToDouble()
          ? k.toStringAsFixed(0)
          : k.toStringAsFixed(1);
      return '\$$s.k';
    }
    return money(v);
  }

  static String dayMonth(DateTime d) => _dayMonth.format(d);
  static String longDate(DateTime d) => _longDate.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);

  /// "18 OCT" style date block used on pickup rows.
  static String dayNumber(DateTime d) => DateFormat('d').format(d);
  static String monthUpper(DateTime d) =>
      DateFormat('MMM').format(d).toUpperCase();

  static String timeOfDay(DateTime d) => DateFormat('h:mm a').format(d);

  static String uppercase(String s) => s.toUpperCase();

  /// "In 4 days" / "Today" / "In 5 days" relative label.
  static String inDays(DateTime target, DateTime from) {
    final diff = DateTime(target.year, target.month, target.day)
        .difference(DateTime(from.year, from.month, from.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
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
}
