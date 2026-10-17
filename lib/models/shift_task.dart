import 'package:flutter/material.dart';

/// One actionable item on the shift task list. Tasks are *derived* from
/// live order + pickup data (never stored), and carry an optional link to
/// the record they came from so every row can open its source.
class ShiftTask {
  final String title;
  final String meta;

  /// Bucket used by the task filters: prep | delivery | payment.
  final String kind;
  final String chip;
  final Color chipFg;
  final Color chipBg;

  /// Order id this task belongs to (null for pickup tasks).
  final String? orderId;

  /// Pickup id this task belongs to (null for order tasks).
  final String? pickupId;

  const ShiftTask({
    required this.title,
    required this.meta,
    required this.kind,
    required this.chip,
    required this.chipFg,
    required this.chipBg,
    this.orderId,
    this.pickupId,
  });
}

/// Lead-time insight bar used by the customer insights screen.
class LeadTimePoint {
  final String label;
  final double days;
  const LeadTimePoint(this.label, this.days);
}
