/// An upcoming pickup/dispatch shown on the dashboard.
class Pickup {
  final String id;
  final DateTime date;
  final String title;
  final String venue;
  final int itemCount;
  final String contactName;

  const Pickup({
    required this.id,
    required this.date,
    required this.title,
    required this.venue,
    required this.itemCount,
    required this.contactName,
  });
}

/// One bar of the owner revenue trend chart.
class RevenuePoint {
  final DateTime day;
  final double value; // thousands of dollars

  const RevenuePoint({required this.day, required this.value});
}

/// Revenue split per inventory category (Reports screen).
class CategoryRevenue {
  final String category;
  final double amount;

  const CategoryRevenue({required this.category, required this.amount});
}
