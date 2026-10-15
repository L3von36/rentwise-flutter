import 'package:flutter/material.dart';

/// Lifecycle state of an inventory piece.
enum ItemStatus { inStock, rentedOut, maintenance }

extension ItemStatusX on ItemStatus {
  String get label => switch (this) {
        ItemStatus.inStock => 'In Stock',
        ItemStatus.rentedOut => 'Rented Out',
        ItemStatus.maintenance => 'Maintenance',
      };

  Color get fg => switch (this) {
        ItemStatus.inStock => const Color(0xFF079455),
        ItemStatus.rentedOut => const Color(0xFF4F46E5),
        ItemStatus.maintenance => const Color(0xFFD97706),
      };

  Color get bg => switch (this) {
        ItemStatus.inStock => const Color(0xFFE7F6EF),
        ItemStatus.rentedOut => const Color(0xFFEEF2FF),
        ItemStatus.maintenance => const Color(0xFFFDF1DF),
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
