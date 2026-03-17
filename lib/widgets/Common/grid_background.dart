import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Mriežkové pozadie (login page štýl).
class GridBackground extends StatelessWidget {
  const GridBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: Color(0xFF0F0F12)),
        CustomPaint(size: Size.infinite, painter: _GridPainter()),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF252530).withOpacity(0.5)
      ..strokeWidth = 0.5;
    const step = 24.0;
    for (double x = 0; x <= size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Prémiové pozadie pre obrazovku Prijemiek.
/// Evokuje receipt paper — jemné diagonálne čiary + zelený glow.
class ReceiptBackground extends StatelessWidget {
  const ReceiptBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Base dark
        const ColoredBox(color: Color(0xFF080C0F)),

        // Diagonal receipt-stripe pattern
        CustomPaint(
          size: Size.infinite,
          painter: _DiagonalStripePainter(),
        ),

        // Green glow — top right (príjem = prichádza = vpravo hore)
        Positioned(
          top: -size.height * 0.15,
          right: -size.width * 0.15,
          child: Container(
            width: size.width * 0.8,
            height: size.width * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.13),
                  const Color(0xFF10B981).withOpacity(0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Subtle teal glow — bottom left
        Positioned(
          bottom: -size.height * 0.1,
          left: -size.width * 0.2,
          child: Container(
            width: size.width * 0.6,
            height: size.width * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0D9488).withOpacity(0.07),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),

        // Top fade overlay so AppBar blends in
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF080C0F).withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Jemné diagonálne čiary — ako bezpečnostný vzor na papierových dokladoch.
class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.028)
      ..strokeWidth = 1.0;

    const spacing = 22.0;
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final count = (diagonal / spacing).ceil() + 2;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 6); // 30 stupňov
    canvas.translate(-size.width / 2, -size.height / 2);

    for (int i = -count; i <= count * 2; i++) {
      final x = i * spacing;
      canvas.drawLine(
        Offset(x, -diagonal),
        Offset(x, size.height + diagonal),
        paint,
      );
    }
    canvas.restore();

    // Jemná horizontálna mriežka (ako účtenka)
    final hPaint = Paint()
      ..color = const Color(0xFF1A2A22).withOpacity(0.6)
      ..strokeWidth = 0.4;
    const hStep = 40.0;
    for (double y = 0; y <= size.height; y += hStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), hPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
