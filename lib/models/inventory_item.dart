import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/app_locale.dart';

/// Lifecycle state of an inventory stock line.
///
/// Status is DERIVED from the unit counts, except [ItemStatus.maintenance]
/// which is an explicit operator decision stored on the item:
///  - all units free                      -> In stock
///  - some units out, some free           -> Partially out
///  - every unit out                      -> Rented out
///  - operator flagged the item           -> Maintenance
enum ItemStatus { inStock, partial, rentedOut, maintenance }

extension ItemStatusX on ItemStatus {
  String get label => switch (this) {
        ItemStatus.inStock => AppLocale.t('In stock'),
        ItemStatus.partial => AppLocale.t('Partially out'),
        ItemStatus.rentedOut => AppLocale.t('Rented out'),
        ItemStatus.maintenance => AppLocale.t('Maintenance'),
      };

  Color get fg => switch (this) {
        ItemStatus.inStock => AppPalette.green,
        ItemStatus.partial => AppPalette.blue,
        ItemStatus.rentedOut => AppPalette.primary,
        ItemStatus.maintenance => AppPalette.amber,
      };

  Color get bg => switch (this) {
        ItemStatus.inStock => AppPalette.greenBg,
        ItemStatus.partial => AppPalette.blueBg,
        ItemStatus.rentedOut => AppPalette.primarySoft,
        ItemStatus.maintenance => AppPalette.amberBg,
      };
}

/// A rentable inventory item (a stock line, e.g. "Folding Chairs" x240).
class InventoryItem {
  final String id;
  final String name;
  final String note;
  final String category;
  final int totalStock;
  final int available;

  /// Operator flag: the item is pulled from service (repairs, cleaning,
  /// damage). Orthogonal to the rented counts — maintenance units are
  /// excluded from the availability KPIs without erasing the numbers.
  final bool maintenance;

  final double ratePerDay;
  final IconData icon;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.note,
    required this.category,
    required this.totalStock,
    required this.available,
    this.maintenance = false,
    required this.ratePerDay,
    required this.icon,
  });

  ItemStatus get status {
    if (maintenance) return ItemStatus.maintenance;
    if (available <= 0) return ItemStatus.rentedOut;
    if (available < totalStock) return ItemStatus.partial;
    return ItemStatus.inStock;
  }

  /// Units effectively out with customers (never counts maintenance).
  int get onRentUnits =>
      maintenance ? 0 : (totalStock - available).clamp(0, totalStock);

  double get availabilityFraction =>
      totalStock == 0 ? 0 : (available / totalStock).clamp(0.0, 1.0);

  bool get needsAttention => status == ItemStatus.maintenance;

  InventoryItem copyWith({
    int? available,
    int? totalStock,
    bool? maintenance,
  }) =>
      InventoryItem(
        id: id,
        name: name,
        note: note,
        category: category,
        totalStock: totalStock ?? this.totalStock,
        available: available ?? this.available,
        maintenance: maintenance ?? this.maintenance,
        ratePerDay: ratePerDay,
        icon: icon,
      );
}
