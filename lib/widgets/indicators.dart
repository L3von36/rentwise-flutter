import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Trend arrow chip shown on KPI cards (green up / amber down).
class TrendChip extends StatelessWidget {
  final String text;
  final bool positive;
  final bool flat;

  const TrendChip({
    super.key,
    required this.text,
    required this.positive,
    this.flat = false,
  });

  const TrendChip.flat({super.key, required this.text, this.positive = true})
      : flat = true;

  @override
  Widget build(BuildContext context) {
    if (flat) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.greenBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration:
                  const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
          ],
        ),
      );
    }
    final color = positive ? AppColors.green : AppColors.amber;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          positive ? Icons.north_east : Icons.south_east,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Thin indigo availability bar (e.g. 190 / 240).
class AvailabilityBar extends StatelessWidget {
  final double fraction;
  final double width;
  final double height;
  final Color fillColor;

  const AvailabilityBar({
    super.key,
    required this.fraction,
    this.width = 64,
    this.height = 4,
    this.fillColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Container(color: AppColors.primaryTint.withOpacity(0.55)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(color: fillColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thick rounded bar used on the Workspace health card.
class HealthBar extends StatelessWidget {
  final double fraction;
  const HealthBar({super.key, required this.fraction});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Container(color: AppColors.greenBg),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    AppColors.greenBar,
                    Color(0xFF0E9F6E),
                  ]),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
