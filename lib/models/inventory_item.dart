import 'package:flutter/material.dart';

import '../core/palette.dart';

/// Lifecycle state of an inventory piece.
enum ItemStatus { inStock, rentedOut, maintenance }

extension ItemStatusX on ItemStatus {
  String get label => switch (this) {
        ItemStatus.inStock => 'In Stock',
        ItemStatus.rentedOut => 'Rented Out',
        ItemStatus.maintenance => 'Maintenance',
      };

  Color get fg => switch (this) {
        ItemStatus.inStock => AppPalette.green,
        ItemStatus.rentedOut => AppPalette.primary,
        ItemStatus.maintenance => AppPalette.amber,
      };

  Color get bg => switch (this) {
        ItemStatus.inStock => AppPalette.greenBg,
        ItemStatus.rentedOut => AppPalette.primarySoft,
        ItemStatus.maintenance => AppPalette.amberBg,
      };
}

/// A rentable inventory item.
class InventoryItem {
  final String id;
  final String name;
  final String note;
  final String category;
  final int totalStock;
  final int available;
  final double ratePerDay;
  final IconData icon;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.note,
    required this.category,
    required this.totalStock,
    required this.available,
    required this.ratePerDay,
    required this.icon,
  });

  ItemStatus get status {
    if (available <= 0) return ItemStatus.maintenance;
    if (available == totalStock) return ItemStatus.inStock;
    return available < totalStock * 0.34
        ? ItemStatus.rentedOut
        : ItemStatus.inStock;
  }

  double get availabilityFraction =>
      totalStock == 0 ? 0 : (available / totalStock).clamp(0.0, 1.0);

  bool get needsAttention => status == ItemStatus.maintenance;

  InventoryItem copyWith({int? available, int? totalStock}) => InventoryItem(
        id: id,
        name: name,
        note: note,
        category: category,
        totalStock: totalStock ?? this.totalStock,
        available: available ?? this.available,
        ratePerDay: ratePerDay,
        icon: icon,
      );
}
