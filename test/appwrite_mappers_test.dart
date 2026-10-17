import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rentwise/data/appwrite_mappers.dart';
import 'package:rentwise/services/appwrite_backend.dart' show initialsFor, slugFor;
import 'package:rentwise/models/activity_entry.dart';
import 'package:rentwise/models/inventory_item.dart';
import 'package:rentwise/models/rental_order.dart';

/// Appwrite persistence codecs round-trip without loss.
void main() {
  test('inventory icon keys resolve to stable icons', () {
    const item = InventoryItem(
      id: 'INV-001',
      name: 'Folding Chairs',
      note: '',
      category: 'Seating',
      totalStock: 10,
      available: 10,
      ratePerDay: 1.5,
      icon: Icons.event_seat,
    );
    expect(iconKeyFor(item.icon), 'event_seat');
    expect(kInventoryIcons['event_seat'], Icons.event_seat);
    // Unknown icons fall back to the generic crate icon.
    expect(iconKeyFor(Icons.airplanemode_active), 'inventory_2');
    expect(
        kInventoryIcons[iconKeyFor(Icons.airplanemode_active)],
        Icons.inventory_2_outlined);
  });

  test('order line items survive the JSON round-trip', () {
    const lines = [
      OrderLine(itemName: 'Folding Chairs', qty: 10, unitPrice: 40),
      OrderLine(itemName: 'String Lights', qty: 2, unitPrice: 180),
    ];
    final restored = orderLinesFromDoc(orderLinesToDoc(lines));
    expect(restored.length, 2);
    expect(restored[0].itemName, 'Folding Chairs');
    expect(restored[0].qty, 10);
    expect(restored[0].lineTotal, 400);
    expect(restored[1].unitPrice, 180);
  });

  test('order line codec is resilient to garbage input', () {
    expect(orderLinesFromDoc(''), isEmpty);
    expect(orderLinesFromDoc('not json'), isEmpty);
    expect(orderLinesFromDoc('[]'), isEmpty);
  });

  test('order status enum codec round-trips every status', () {
    for (final s in OrderStatus.values) {
      expect(statusFromDoc(statusToDoc(s)), s);
    }
  });

  test('activity type enum codec round-trips every type', () {
    for (final t in ActivityType.values) {
      expect(activityTypeFromDoc(activityTypeToDoc(t)), t);
    }
  });

  test('actor/avatar colors keep their palette index', () {
    for (var i = 0; i < kActivityActorColors.length; i++) {
      expect(actorColorIndex(kActivityActorColors[i]), i);
      expect(actorColorFromIndex(i), kActivityActorColors[i]);
    }
    expect(actorColorIndex(const Color(0xFF123456)), 0); // unknown -> 0
  });

  test('awDate strips microseconds for Appwrite datetimes', () {
    final d = DateTime.parse('2026-10-17T08:15:02.123456');
    final encoded = awDate(d);
    expect(RegExp(r'\.\d{3}(\+00:00|Z)$').hasMatch(encoded), isTrue,
        reason: 'encoded=$encoded must carry millisecond precision only');
    expect(DateTime.parse(encoded).millisecondsSinceEpoch,
        DateTime.parse('2026-10-17T08:15:02.123Z').millisecondsSinceEpoch);
  });

  test('initials + slug helpers', () {
    expect(initialsFor('Tinsae Abeba'), 'TA');
    expect(initialsFor('jordan'), 'J');
    expect(slugFor('Riverside Events'), 'riverside-events');
    expect(slugFor('  Gala -- Night!! '), 'gala-night');
  });
}
