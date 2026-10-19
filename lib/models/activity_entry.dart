import 'package:flutter/material.dart';

import '../core/palette.dart';

/// Type of a workspace activity entry.
enum ActivityType { rental, payment, orderUpdate, returnItem, note, newBooking }

extension ActivityTypeX on ActivityType {
  String get label => switch (this) {
        ActivityType.rental => 'Rental',
        ActivityType.payment => 'Payment',
        ActivityType.orderUpdate => 'Order update',
        ActivityType.returnItem => 'Return',
        ActivityType.note => 'Note',
        ActivityType.newBooking => 'New booking',
      };

  Color get fg => switch (this) {
        ActivityType.rental => AppPalette.primary,
        ActivityType.payment => AppPalette.green,
        ActivityType.orderUpdate => AppPalette.purple,
        ActivityType.returnItem => AppPalette.amber,
        ActivityType.note => AppPalette.blue,
        ActivityType.newBooking => AppPalette.primary,
      };

  Color get bg => switch (this) {
        ActivityType.rental => AppPalette.primarySoft,
        ActivityType.payment => AppPalette.greenBg,
        ActivityType.orderUpdate => AppPalette.purpleBg,
        ActivityType.returnItem => AppPalette.amberBg,
        ActivityType.note => AppPalette.blueBg,
        ActivityType.newBooking => AppPalette.primarySoft,
      };

  /// Icon glyph used by the notifications feed and the activity timeline.
  IconData get icon => switch (this) {
        ActivityType.rental => Icons.inventory_2_outlined,
        ActivityType.payment => Icons.payments_outlined,
        ActivityType.orderUpdate => Icons.receipt_long_rounded,
        ActivityType.returnItem => Icons.assignment_return_outlined,
        ActivityType.note => Icons.sticky_note_2_outlined,
        ActivityType.newBooking => Icons.event_available_outlined,
      };
}

/// A single time-stamped workspace action.
///
/// [body] may contain simple **bold** markers which the UI renders richly.
class ActivityEntry {
  final String id;
  final String actor;
  final String actorInitials;
  final Color actorColor;
  final DateTime at;
  final ActivityType type;
  final String body; // supports **bold** segments

  const ActivityEntry({
    required this.id,
    required this.actor,
    required this.actorInitials,
    required this.actorColor,
    required this.at,
    required this.type,
    required this.body,
  });
}
