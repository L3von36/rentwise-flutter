import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// A customer in the directory.
class Customer {
  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;

  /// Government ID captured for the payment policy (v1.26) — type
  /// ('National ID', 'Passport', 'Driver's license', 'Other') and the
  /// number/serial the customer presented. Shown at handover so the
  /// operator can re-verify the same document.
  final String idType;
  final String idNumber;
  final int rentals;
  final double lifetimeSpend;
  final DateTime lastBooking;
  final Color avatarColor;

  const Customer({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    this.idType = '',
    this.idNumber = '',
    required this.rentals,
    required this.lifetimeSpend,
    required this.lastBooking,
    required this.avatarColor,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  bool get isRepeat => rentals >= 3;

  Customer copyWith({
    String? name,
    String? company,
    String? email,
    String? phone,
    String? idType,
    String? idNumber,
    int? rentals,
    double? lifetimeSpend,
    DateTime? lastBooking,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        company: company ?? this.company,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        idType: idType ?? this.idType,
        idNumber: idNumber ?? this.idNumber,
        rentals: rentals ?? this.rentals,
        lifetimeSpend: lifetimeSpend ?? this.lifetimeSpend,
        lastBooking: lastBooking ?? this.lastBooking,
        avatarColor: avatarColor,
      );
}

/// ID document types the payment policy accepts, shown in the
/// add-customer dialog and re-verified at handover.
const List<String> kCustomerIdTypes = [
  'National ID',
  'Passport',
  "Driver's license",
  'Student ID',
  'Other',
];

/// Palette used to cycle customer avatar colors.
const List<Color> kAvatarPalette = [
  AppColors.avatarGreen,
  AppColors.avatarPurple,
  AppColors.avatarTeal,
  AppColors.avatarOrange,
  AppColors.avatarIndigo,
  AppColors.avatarBlue,
];
