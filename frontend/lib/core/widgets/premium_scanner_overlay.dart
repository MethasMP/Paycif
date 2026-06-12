import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM SCANNER OVERLAY v2 — Corner Brackets + Scan Beam
//
// Design rationale (from UX brief):
//   • Context: outdoor, bright sun, one-handed, hurried tourist
//   • Corner brackets signal the active zone without obscuring the QR
//   • Teal (left/bottom) + Gold (right/top) = brand trust signal in color
//   • Animated scan beam = live, "system is working" reassurance
//   • Hard cutout (not radial fade) for OLED + outdoor readability
// ─────────────────────────────────────────────────────────────────────────────

class PremiumScannerOverlay extends StatefulWidget {
  final double frameSize;
  const PremiumScannerOverlay({super.key, required this.frameSize});

  @override
  State<PremiumScannerOverlay> createState() => _PremiumScannerOverlayState();
}

class _PremiumScannerOverlayState extends State<PremiumScannerOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();

    // Scan beam — travels top-to-bottom in 1.8s, then loops
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();

    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final frameSize = widget.frameSize;
    final centerY = screenSize.height * 0.40;

    return AnimatedBuilder(
      animation: _scanAnim,
      builder: (ctx, _) {
        return CustomPaint(
          painter: _ScannerOverlayPainter(
            frameSize: frameSize,
            centerY: centerY,
            scanProgress: _scanAnim.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double frameSize;
  final double centerY;
  final double scanProgress; // 0.0 → 1.0

  static const double _bracketLength = 36.0;
  static const double _bracketThickness = 4.0;
  static const double _cornerRadius = 10.0;

  _ScannerOverlayPainter({
    required this.frameSize,
    required this.centerY,
    required this.scanProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: frameSize,
      height: frameSize,
    );

    // ── 1. Hard dark vignette with clear rectangle cutout ─────────────────
    _drawVignette(canvas, size, frameRect);

    // ── 2. Animated gold scan beam ─────────────────────────────────────────
    _drawScanBeam(canvas, frameRect);

    // ── 3. Corner brackets (Teal top-left/bottom-right, Gold top-right/bottom-left) ──
    _drawCornerBrackets(canvas, frameRect);
  }

  void _drawVignette(Canvas canvas, Size size, Rect frameRect) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(_cornerRadius)))
      ..fillType = PathFillType.evenOdd;

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.drawPath(path, paint);
  }

  void _drawScanBeam(Canvas canvas, Rect frameRect) {
    final beamY = frameRect.top + (frameRect.height * scanProgress);
    const beamHeight = 80.0;

    // Clip drawing to the scan frame area
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(_cornerRadius)),
    );

    // Horizontal gold gradient beam
    final beamRect = Rect.fromLTWH(
      frameRect.left,
      beamY - beamHeight / 2,
      frameRect.width,
      beamHeight,
    );

    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppTheme.accentGold.withValues(alpha: 0.08),
          AppTheme.accentGold.withValues(alpha: 0.55),
          AppTheme.accentGold.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(beamRect);

    canvas.drawRect(beamRect, beamPaint);

    // Thin bright core line
    final linePaint = Paint()
      ..color = AppTheme.accentGold.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    canvas.drawLine(
      Offset(frameRect.left + 8, beamY),
      Offset(frameRect.right - 8, beamY),
      linePaint,
    );

    canvas.restore();
  }

  void _drawCornerBrackets(Canvas canvas, Rect frameRect) {
    final tealPaint = Paint()
      ..color = AppTheme.primaryTeal
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bracketThickness
      ..strokeCap = StrokeCap.round;

    final goldPaint = Paint()
      ..color = AppTheme.accentGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bracketThickness
      ..strokeCap = StrokeCap.round;

    final l = frameRect.left;
    final r = frameRect.right;
    final t = frameRect.top;
    final b = frameRect.bottom;
    final bl = _bracketLength;
    final cr = _cornerRadius;

    // ── Top-left: Teal ───────────────────────────────────────────────────
    final pathTL = Path()
      ..moveTo(l + cr, t)
      ..lineTo(l + bl, t) // horizontal
      ..moveTo(l, t + cr)
      ..lineTo(l, t + bl); // vertical
    // Draw corner arc
    final pathTLArc = Path()
      ..moveTo(l + cr, t)
      ..arcToPoint(
        Offset(l, t + cr),
        radius: const Radius.circular(_cornerRadius),
        clockwise: false,
      );
    canvas.drawPath(pathTL, tealPaint);
    canvas.drawPath(pathTLArc, tealPaint);

    // ── Bottom-right: Teal ───────────────────────────────────────────────
    final pathBR = Path()
      ..moveTo(r - bl, b)
      ..lineTo(r - cr, b) // horizontal
      ..moveTo(r, b - bl)
      ..lineTo(r, b - cr); // vertical
    final pathBRArc = Path()
      ..moveTo(r - cr, b)
      ..arcToPoint(
        Offset(r, b - cr),
        radius: const Radius.circular(_cornerRadius),
        clockwise: false,
      );
    canvas.drawPath(pathBR, tealPaint);
    canvas.drawPath(pathBRArc, tealPaint);

    // ── Top-right: Gold ──────────────────────────────────────────────────
    final pathTR = Path()
      ..moveTo(r - bl, t)
      ..lineTo(r - cr, t) // horizontal
      ..moveTo(r, t + cr)
      ..lineTo(r, t + bl); // vertical
    final pathTRArc = Path()
      ..moveTo(r - cr, t)
      ..arcToPoint(
        Offset(r, t + cr),
        radius: const Radius.circular(_cornerRadius),
        clockwise: true,
      );
    canvas.drawPath(pathTR, goldPaint);
    canvas.drawPath(pathTRArc, goldPaint);

    // ── Bottom-left: Gold ────────────────────────────────────────────────
    final pathBL = Path()
      ..moveTo(l + cr, b)
      ..lineTo(l + bl, b) // horizontal
      ..moveTo(l, b - cr)
      ..lineTo(l, b - bl); // vertical
    final pathBLArc = Path()
      ..moveTo(l + cr, b)
      ..arcToPoint(
        Offset(l, b - cr),
        radius: const Radius.circular(_cornerRadius),
        clockwise: true,
      );
    canvas.drawPath(pathBL, goldPaint);
    canvas.drawPath(pathBLArc, goldPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      old.scanProgress != scanProgress ||
      old.frameSize != frameSize ||
      old.centerY != centerY;
}
