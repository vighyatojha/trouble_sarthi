// lib/widgets/map_pin.dart

import 'package:flutter/material.dart';

/// The centered map pin that floats/bounces while the camera is moving.
/// Pass [isFloating] = true (camera moving) to lift the pin up.
class MapPin extends StatelessWidget {
  final bool isFloating;

  const MapPin({super.key, this.isFloating = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, isFloating ? -10 : 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Pin head ────────────────────────────────────────────────────────
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isFloating ? 0.55 : 0.35),
                  blurRadius: isFloating ? 20 : 12,
                  offset: Offset(0, isFloating ? 8 : 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),

          // ── Pointy tail ─────────────────────────────────────────────────────
          CustomPaint(
            size: const Size(14, 8),
            painter: _PinTailPainter(color: color),
          ),

          // ── Shadow dot on ground ─────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: isFloating ? 6 : 10,
            height: isFloating ? 3 : 5,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(isFloating ? 0.1 : 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}