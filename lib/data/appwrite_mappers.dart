/// Shared codecs for persisting workspace models to Appwrite.
///
/// Icons and avatar colors are Flutter objects that cannot be serialized,
/// so documents store a stable string/int key that both the app and the
/// seeding harness resolve through the registries below.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/activity_entry.dart';
import '../models/customer.dart';

import '../models/rental_order.dart';

/// iconKey -> icon. Everything added through the app uses the fallback key.
const Map<String, IconData> kInventoryIcons = {
  'event_seat': Icons.event_seat,
  'table_bar': Icons.table_bar,
  'lightbulb_outline': Icons.lightbulb_outline,
  'dry_cleaning_outlined': Icons.dry_cleaning_outlined,
  'local_bar_outlined': Icons.local_bar_outlined,
  'heat_pump_outlined': Icons.heat_pump_outlined,
  'inventory_2': Icons.inventory_2_outlined,
};

/// Reverse lookup used by the seeding harness.
String iconKeyFor(IconData icon) =>
    kInventoryIcons.entries
        .firstWhere((e) => e.value == icon, orElse: () => const MapEntry('inventory_2', Icons.inventory_2_outlined))
    .key;

/// Avatar palette for customers, cycled by [Customer.avatarColor].
const List<Color> kAvatarPaletteFlat = kAvatarPalette;

/// Activity actor colors, indexed in documents (0 = owner indigo,
/// 1 = employee green, then palette order).
const List<Color> kActivityActorColors = [
  AppColors.avatarIndigo,
  AppColors.avatarGreen,
  AppColors.avatarPurple,
  AppColors.avatarTeal,
  AppColors.avatarOrange,
  AppColors.avatarBlue,
];

Color actorColorFromIndex(int index) =>
    kActivityActorColors[index.clamp(0, kActivityActorColors.length - 1)];

int actorColorIndex(Color color) {
  final i = kActivityActorColors.indexOf(color);
  return i == -1 ? 0 : i;
}

Color avatarColorFromIndex(int index) =>
    kAvatarPalette[index.clamp(0, kAvatarPalette.length - 1)];

int avatarColorIndex(Color color) {
  final i = kAvatarPalette.indexOf(color);
  return i == -1 ? 0 : i;
}

/// Appwrite datetime attributes are ISO-8601 with millisecond precision.
String awDate(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second,
            d.millisecond)
        .toIso8601String();

DateTime dateFromDoc(String raw) => DateTime.parse(raw).toLocal();

/// Enum codecs — documents store the Dart enum name.
String statusToDoc(OrderStatus s) => s.name;
OrderStatus statusFromDoc(String raw) => OrderStatus.values.byName(raw);

String activityTypeToDoc(ActivityType t) => t.name;
ActivityType activityTypeFromDoc(String raw) => ActivityType.values.byName(raw);

/// Quoted line items ride along on the order document as JSON.
String orderLinesToDoc(List<OrderLine> lines) => jsonEncode(lines
    .map((l) => {'item': l.itemName, 'qty': l.qty, 'unit': l.unitPrice})
    .toList());

List<OrderLine> orderLinesFromDoc(String raw) {
  if (raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => OrderLine(
              itemName: (e['item'] ?? '') as String,
              qty: (e['qty'] ?? 0) as int,
              unitPrice: ((e['unit'] ?? 0) as num).toDouble(),
            ))
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}
