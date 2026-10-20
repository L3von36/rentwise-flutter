/// Shared codecs for persisting workspace models to Appwrite.
///
/// Icons and avatar colors are Flutter objects that cannot be serialized,
/// so documents store a stable string/int key that both the app and the
/// seeding harness resolve through the registries below.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/activity_entry.dart';
import '../models/customer.dart';
import '../models/payment_receipt.dart';

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
String iconKeyFor(IconData icon) => kInventoryIcons.entries
    .firstWhere((e) => e.value == icon,
        orElse: () => const MapEntry('inventory_2', Icons.inventory_2_outlined))
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
String awDate(DateTime d) => DateTime.utc(
        d.year, d.month, d.day, d.hour, d.minute, d.second, d.millisecond)
    .toIso8601String();

DateTime dateFromDoc(String raw) => DateTime.parse(raw).toLocal();

/// Enum codecs — documents store the Dart enum name.
String statusToDoc(OrderStatus s) => s.name;
OrderStatus statusFromDoc(String raw) => OrderStatus.values.byName(raw);

String activityTypeToDoc(ActivityType t) => t.name;
ActivityType activityTypeFromDoc(String raw) => ActivityType.values.byName(raw);

// ------------------------------------------------------------- payments
// v1.30 payments ledger — receipts live in their own collection. What
// stage a receipt fills is DERIVED (PaymentLedger), never stored.

Map<String, dynamic> paymentToDoc(PaymentReceipt r) => {
      'orderId': r.orderId,
      'amount': r.amount,
      'method': r.method.docName,
      'note': r.note,
      'recordedBy': r.recordedBy,
      'recordedAt': awDate(r.recordedAt),
    };

PaymentReceipt paymentFromDoc(String id, Map<String, dynamic> data) =>
    PaymentReceipt(
      id: id,
      orderId: (data['orderId'] ?? '') as String,
      amount: ((data['amount'] ?? 0) as num).toDouble(),
      method: PaymentMethodX.fromDoc(data['method'] as String?) ??
          PaymentMethod.cash,
      note: (data['note'] ?? '') as String? ?? '',
      recordedBy: (data['recordedBy'] ?? '') as String? ?? '',
      recordedAt: data['recordedAt'] == null
          ? DateTime.now()
          : dateFromDoc(data['recordedAt'] as String),
    );

/// Quoted line items ride along on the order document as JSON.
String orderLinesToDoc(List<OrderLine> lines) => jsonEncode(lines
    .map((l) => {
          'item': l.itemName,
          'qty': l.qty,
          'unit': l.unitPrice,
          'down': l.downPayment,
          'collateral': l.collateralAmount,
        })
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
              downPayment: ((e['down'] ?? 0) as num).toDouble(),
              collateralAmount: ((e['collateral'] ?? 0) as num).toDouble(),
            ))
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

// ------------------------------------------------------------- signatures
// Signature strokes ride on the order document as a compact binary blob
// (base64 of int16 deltas) — the `signatureData` column is capped at
// 2800 chars by the free-tier table budget, so a text JSON of stroke
// points would not fit. Worst realistic case (~300 points across ~6
// strokes) encodes to ~1.6KB.

/// Signature capture space: points are normalized to this box by the
/// signature pad before encoding.
const int kSignatureGridMax = 4095;

/// Encodes signature strokes (points normalized to 0..[kSignatureGridMax])
/// into the compact document form: `S1` + base64(varint stroke count ·
/// per stroke: varint point count + int16 absolute x,y + int16 deltas).
String signatureToDoc(List<List<Offset>> strokes) {
  if (strokes.isEmpty) return '';
  final b = BytesBuilder();
  void varint(int v) {
    while (v >= 0x80) {
      b.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    b.addByte(v);
  }

  void i16(int v) {
    v = v.clamp(-32768, 32767);
    b.addByte(v & 0xff);
    b.addByte((v >> 8) & 0xff);
  }

  final real = strokes.where((s) => s.length >= 2).toList(growable: false);
  if (real.isEmpty) return '';
  varint(real.length);
  for (final stroke in real) {
    varint(stroke.length);
    var px = 0, py = 0;
    for (var i = 0; i < stroke.length; i++) {
      final x = (stroke[i].dx.round()).clamp(0, kSignatureGridMax);
      final y = (stroke[i].dy.round()).clamp(0, kSignatureGridMax);
      if (i == 0) {
        i16(x);
        i16(y);
      } else {
        i16(x - px);
        i16(y - py);
      }
      px = x;
      py = y;
    }
  }
  return 'S1${base64Encode(b.toBytes())}';
}

/// Decodes [signatureToDoc] output back to strokes in the normalized
/// 0..[kSignatureGridMax] space. Garbage/legacy input decodes to [].
List<List<Offset>> signatureFromDoc(String raw) {
  if (raw.isEmpty || !raw.startsWith('S1')) return const [];
  try {
    final bytes = base64Decode(raw.substring(2));
    var pos = 0;
    int readByte() => bytes[pos++];
    int varint() {
      var v = 0, shift = 0;
      while (true) {
        final b = readByte();
        v |= (b & 0x7f) << shift;
        if (b < 0x80) break;
        shift += 7;
      }
      return v;
    }

    int i16() {
      final lo = readByte(), hi = readByte();
      var v = lo | (hi << 8);
      if (v >= 0x8000) v -= 0x10000;
      return v;
    }

    final strokeCount = varint();
    final strokes = <List<Offset>>[];
    for (var s = 0; s < strokeCount; s++) {
      final pointCount = varint();
      final stroke = <Offset>[];
      var x = 0, y = 0;
      for (var p = 0; p < pointCount; p++) {
        if (pos + 4 > bytes.length) throw const FormatException('short');
        x += i16();
        y += i16();
        stroke.add(Offset((x.toDouble()).clamp(0, kSignatureGridMax).toDouble(),
            (y.toDouble()).clamp(0, kSignatureGridMax).toDouble()));
      }
      if (stroke.length >= 2) strokes.add(stroke);
    }
    return strokes;
  } catch (_) {
    return const [];
  }
}
