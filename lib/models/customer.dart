import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// A customer in the directory.
class Customer {
  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
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
        rentals: rentals ?? this.rentals,
        lifetimeSpend: lifetimeSpend ?? this.lifetimeSpend,
        lastBooking: lastBooking ?? this.lastBooking,
        avatarColor: avatarColor,
      );
}

/// Palette used to cycle customer avatar colors.
const List<Color> kAvatarPalette = [
  AppColors.avatarGreen,
  AppColors.avatarPurple,
  AppColors.avatarTeal,
  AppColors.avatarOrange,
  AppColors.avatarIndigo,
  AppColors.avatarBlue,
];
