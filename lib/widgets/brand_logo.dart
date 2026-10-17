import 'package:flutter/material.dart';
import '../core/palette.dart';

/// RentWise brand mark — indigo rounded swoosh.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BrandMarkPainter(),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFF6A63F0), AppPalette.primary, const Color(0xFF3B34C4)],
    ).createShader(rect);

    // Slanted rounded "feather" like the design logo.
    final path = Path()
      ..moveTo(size.width * 0.72, 0)
      ..quadraticBezierTo(size.width * 0.92, 0, size.width * 0.78,
          size.height * 0.22)
      ..lineTo(size.width * 0.38, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.24, size.height * 0.98,
          size.width * 0.14, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.04, size.height * 0.74,
          size.width * 0.16, size.height * 0.56)
      ..lineTo(size.width * 0.58, size.height * 0.06)
      ..quadraticBezierTo(size.width * 0.66, 0, size.width * 0.72, 0)
      ..close();

    final paint = Paint()..shader = gradient;
    canvas.drawPath(path, paint);

    // small tip accent
    final tip = Path()
      ..moveTo(size.width * 0.60, size.height * 0.24)
      ..lineTo(size.width * 0.78, size.height * 0.44)
      ..lineTo(size.width * 0.52, size.height * 0.50)
      ..quadraticBezierTo(size.width * 0.46, size.height * 0.51,
          size.width * 0.48, size.height * 0.42)
      ..close();
    canvas.drawPath(
        tip, Paint()..color = Colors.white.withOpacity(0.55));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "rentwise | EVENT RENTALS" lockup.
class BrandLockup extends StatelessWidget {
  final double markSize;
  final double fontSize;
  final bool dark;
  const BrandLockup(
      {super.key, this.markSize = 26, this.fontSize = 17, this.dark = true});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'rentwise',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: dark ? AppPalette.ink : Colors.white,
                ),
              ),
              WidgetSpan(
                child: SizedBox(width: fontSize * 0.45),
              ),
              TextSpan(
                text: 'EVENT RENTALS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: fontSize * 0.52,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  color: dark
                      ? AppPalette.muted
                      : Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}
