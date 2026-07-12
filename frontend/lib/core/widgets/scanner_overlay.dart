import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCANNER OVERLAY — Corner Brackets (Consensus Compliant)
//
// Design rationale:
//   • Context: outdoor, bright sun, one-handed, hurried tourist
//   • Constant 1.5px stroke weight (Fine Utility), zero outer glow, zero shadows
//   • Adaptive color: transparent white in searching state, snaps instantly to
//     flat solid Teal-Cyan (#00A896) on active detection lock.
//   • No skeuomorphic scan beam to optimize GPU resources.
// ─────────────────────────────────────────────────────────────────────────────

class ScannerOverlay extends StatelessWidget {
  final double frameSize;
  final bool isLocked;

  const ScannerOverlay({
    super.key,
    required this.frameSize,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerY = screenSize.height * 0.40;

    return CustomPaint(
      painter: _ScannerOverlayPainter(
        frameSize: frameSize,
        centerY: centerY,
        isLocked: isLocked,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double frameSize;
  final double centerY;
  final bool isLocked;

  static const double _bracketLength = 32.0;
  static const double _bracketThickness = 1.5; // Constant 1.5px fine utility weight
  static const double _cornerRadius = 10.0;

  _ScannerOverlayPainter({
    required this.frameSize,
    required this.centerY,
    required this.isLocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: frameSize,
      height: frameSize,
    );

    // 1. Dark vignette mask with rounded cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(_cornerRadius)))
      ..fillType = PathFillType.evenOdd;

    final vignettePaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.drawPath(path, vignettePaint);

    // 2. Corner brackets (flat 1.5px vector line, zero glow)
    final bracketPaint = Paint()
      ..color = isLocked ? AppTheme.primaryTeal : Colors.white.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bracketThickness
      ..strokeCap = StrokeCap.round;

    final l = frameRect.left;
    final r = frameRect.right;
    final t = frameRect.top;
    final b = frameRect.bottom;
    final bl = _bracketLength;
    final cr = _cornerRadius;

    // Draw 4 corners precisely
    // Top-Left
    final pathTL = Path()
      ..moveTo(l + cr, t)
      ..lineTo(l + bl, t)
      ..moveTo(l, t + cr)
      ..lineTo(l, t + bl)
      ..moveTo(l + cr, t)
      ..arcToPoint(
        Offset(l, t + cr),
        radius: const Radius.circular(_cornerRadius),
        clockwise: false,
      );
    canvas.drawPath(pathTL, bracketPaint);

    // Top-Right
    final pathTR = Path()
      ..moveTo(r - bl, t)
      ..lineTo(r - cr, t)
      ..moveTo(r, t + cr)
      ..lineTo(r, t + bl)
      ..moveTo(r - cr, t)
      ..arcToPoint(
        Offset(r, t + cr),
        radius: const Radius.circular(_cornerRadius),
        clockwise: true,
      );
    canvas.drawPath(pathTR, bracketPaint);

    // Bottom-Left
    final pathBL = Path()
      ..moveTo(l + cr, b)
      ..lineTo(l + bl, b)
      ..moveTo(l, b - cr)
      ..lineTo(l, b - bl)
      ..moveTo(l + cr, b)
      ..arcToPoint(
        Offset(l, b - cr),
        radius: const Radius.circular(_cornerRadius),
        clockwise: true,
      );
    canvas.drawPath(pathBL, bracketPaint);

    // Bottom-Right
    final pathBR = Path()
      ..moveTo(r - bl, b)
      ..lineTo(r - cr, b)
      ..moveTo(r, b - bl)
      ..lineTo(r, b - cr)
      ..moveTo(r - cr, b)
      ..arcToPoint(
        Offset(r, b - cr),
        radius: const Radius.circular(_cornerRadius),
        clockwise: false,
      );
    canvas.drawPath(pathBR, bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      old.frameSize != frameSize ||
      old.centerY != centerY ||
      old.isLocked != isLocked;
}
