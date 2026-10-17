/// Static UI options — presentation constants, NOT data.
///
/// Everything here is fixed interface vocabulary (filter-chip labels,
/// schedule copy). All business data (inventory, orders, customers,
/// activity, pickups, metrics, workspace names, accounts) lives in
/// Appwrite Cloud and is loaded at sign-in — nothing else is bundled.
class Catalog {
  Catalog._();

  /// Filter chips shown above the inventory grid. The first entry is the
  /// "no filter" sentinel; the rest are matched against each item's
  /// `category` field.
  static const List<String> categories = [
    'All categories',
    'Seating',
    'Tables',
    'Lighting',
    'Linens',
    'Furniture',
    'Outdoor',
  ];

  static const String allCategories = 'All categories';

  /// Copy shown on the dashboard's business-hours pill.
  static const String businessCloseTime = '7:00 PM';
}
