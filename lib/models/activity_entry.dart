import 'package:flutter/material.dart';

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
        ActivityType.rental => const Color(0xFF4F46E5),
        ActivityType.payment => const Color(0xFF079455),
        ActivityType.orderUpdate => const Color(0xFF7C3AED),
        ActivityType.returnItem => const Color(0xFFD97706),
        ActivityType.note => const Color(0xFF2563EB),
        ActivityType.newBooking => const Color(0xFF4F46E5),
      };

  Color get bg => switch (this) {
        ActivityType.rental => const Color(0xFFEEF2FF),
        ActivityType.payment => const Color(0xFFE7F6EF),
        ActivityType.orderUpdate => const Color(0xFFF2ECFE),
        ActivityType.returnItem => const Color(0xFFFDF1DF),
        ActivityType.note => const Color(0xFFEAF1FE),
        ActivityType.newBooking => const Color(0xFFEEF2FF),
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
