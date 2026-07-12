import 'package:flutter/material.dart';

/// Bespoke nav-bar icon set (Home / History / Cards / Profile), drawn to share
/// the exact open-corner-bracket stroke language of the scan button's
/// [CustomScanIcon] in main_screen.dart — the one glyph in the app that isn't
/// borrowed from a third-party icon library. Scoped deliberately to the four
/// bottom-nav tabs only; every other icon in the app still goes through
/// [AppIcon] / PhosphorIcons per DESIGN.md §5. Active state thickens the
/// stroke rather than swapping to a different glyph shape.
enum NavGlyphType { home, history, cards, profile }

class NavGlyph extends StatelessWidget {
  final NavGlyphType type;
  final bool isActive;
  final Color color;
  final double size;

  const NavGlyph({
    super.key,
    required this.type,
    required this.color,
    this.isActive = false,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _NavGlyphPainter(type: type, color: color, isActive: isActive),
    );
  }
}

class _NavGlyphPainter extends CustomPainter {
  final NavGlyphType type;
  final Color color;
  final bool isActive;

  _NavGlyphPainter({required this.type, required this.color, required this.isActive});

  static const double _cornerRadius = 3.5; // matches CustomScanIcon

  Paint _paint() => Paint()
    ..color = color
    ..strokeWidth = isActive ? 2.6 : 2.0
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // Four open L-shaped corner marks — the same construction as
  // CustomScanIcon's corner brackets, generalized to any rect.
  void _addCornerBrackets(Path path, Rect r, double cornerLen) {
    final radius = _cornerRadius;
    // top-left
    path.moveTo(r.left, r.top + cornerLen);
    path.lineTo(r.left, r.top + radius);
    path.quadraticBezierTo(r.left, r.top, r.left + radius, r.top);
    path.lineTo(r.left + cornerLen, r.top);
    // top-right
    path.moveTo(r.right - cornerLen, r.top);
    path.lineTo(r.right - radius, r.top);
    path.quadraticBezierTo(r.right, r.top, r.right, r.top + radius);
    path.lineTo(r.right, r.top + cornerLen);
    // bottom-left
    path.moveTo(r.left, r.bottom - cornerLen);
    path.lineTo(r.left, r.bottom - radius);
    path.quadraticBezierTo(r.left, r.bottom, r.left + radius, r.bottom);
    path.lineTo(r.left + cornerLen, r.bottom);
    // bottom-right
    path.moveTo(r.right - cornerLen, r.bottom);
    path.lineTo(r.right - radius, r.bottom);
    path.quadraticBezierTo(r.right, r.bottom, r.right, r.bottom - radius);
    path.lineTo(r.right, r.bottom - cornerLen);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = _paint();

    switch (type) {
      case NavGlyphType.home:
        final roof = Path()
          ..moveTo(w * 0.13, h * 0.46)
          ..lineTo(w * 0.5, h * 0.10)
          ..lineTo(w * 0.87, h * 0.46);
        canvas.drawPath(roof, paint);

        final walls = Path()
          ..moveTo(w * 0.20, h * 0.40)
          ..lineTo(w * 0.20, h * 0.86)
          ..moveTo(w * 0.80, h * 0.40)
          ..lineTo(w * 0.80, h * 0.86);
        canvas.drawPath(walls, paint);

        final door = Path()
          ..moveTo(w * 0.40, h * 0.86)
          ..lineTo(w * 0.40, h * 0.60)
          ..lineTo(w * 0.60, h * 0.60)
          ..lineTo(w * 0.60, h * 0.86);
        canvas.drawPath(door, paint);
        break;

      case NavGlyphType.history:
        final frame = Path();
        final rect = Rect.fromLTRB(w * 0.20, h * 0.10, w * 0.80, h * 0.90);
        _addCornerBrackets(frame, rect, w * 0.16);
        canvas.drawPath(frame, paint);

        for (final fy in [0.36, 0.55, 0.72]) {
          canvas.drawLine(
            Offset(w * 0.34, h * fy),
            Offset(w * 0.66, h * fy),
            paint,
          );
        }
        break;

      case NavGlyphType.cards:
        final back = Path();
        _addCornerBrackets(back, Rect.fromLTRB(w * 0.30, h * 0.14, w * 0.92, h * 0.62), w * 0.12);
        canvas.drawPath(back, paint);

        final front = Path();
        _addCornerBrackets(front, Rect.fromLTRB(w * 0.08, h * 0.38, w * 0.70, h * 0.86), w * 0.12);
        canvas.drawPath(front, paint);
        break;

      case NavGlyphType.profile:
        // Head: a circle left deliberately open at the top.
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w * 0.5, h * 0.36), radius: w * 0.19),
          0.35 * 3.14159,
          2 * 3.14159 - 0.7 * 3.14159,
          false,
          paint,
        );
        // Shoulders: a wide arc opening upward.
        canvas.drawArc(
          Rect.fromLTRB(w * 0.14, h * 0.52, w * 0.86, h * 1.14),
          3.14159,
          3.14159,
          false,
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _NavGlyphPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isActive != isActive || oldDelegate.type != type;
  }
}
