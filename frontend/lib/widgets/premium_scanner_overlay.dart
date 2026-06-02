import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM SCANNER OVERLAY — Minimalist Ring
//
// First-principle approach: the frame IS the UI.
// No corner brackets. No scan line. No hard cutout.
// Just a clean, glowing, breathing rounded rectangle.
// ─────────────────────────────────────────────────────────────────────────────

class PremiumScannerOverlay extends StatefulWidget {
  final double frameSize;
  const PremiumScannerOverlay({super.key, required this.frameSize});

  @override
  State<PremiumScannerOverlay> createState() => _PremiumScannerOverlayState();
}

class _PremiumScannerOverlayState extends State<PremiumScannerOverlay>
    with TickerProviderStateMixin {

  // Breathing pulse — the whole frame gently scales
  late AnimationController _breatheController;
  late Animation<double> _breatheAnim;

  @override
  void initState() {
    super.initState();

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _breatheAnim = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final frameSize = widget.frameSize;
    final centerY = screenSize.height * 0.40;

    return Stack(
      children: [
        // ── 1. Soft gradient vignette (NOT a hard cutout) ───────────────
        CustomPaint(
          painter: _SoftVignettePainter(
            frameSize: frameSize,
            centerY: centerY,
          ),
          child: const SizedBox.expand(),
        ),

        // ── 2. The frame — glowing continuous border ──────────────
        AnimatedBuilder(
          animation: _breatheAnim,
          builder: (ctx, _) {
            return CustomPaint(
              painter: _LuminousFramePainter(
                frameSize: frameSize * _breatheAnim.value,
                centerY: centerY,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOFT VIGNETTE — gentle gradient fade instead of hard black cutout
// ─────────────────────────────────────────────────────────────────────────────
class _SoftVignettePainter extends CustomPainter {
  final double frameSize;
  final double centerY;

  _SoftVignettePainter({required this.frameSize, required this.centerY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, centerY);

    // Radial gradient: clear in center, dark at edges
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (center.dx / size.width) * 2 - 1,
          (center.dy / size.height) * 2 - 1,
        ),
        radius: 0.55,
        colors: const [
          Color(0x00000000), // fully transparent in center
          Color(0x15000000), // barely visible
          Color(0x60000000), // medium at edges
          Color(0x99000000), // strong at corners
        ],
        stops: const [0.0, 0.45, 0.72, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _SoftVignettePainter old) =>
      old.frameSize != frameSize || old.centerY != centerY;
}

// ─────────────────────────────────────────────────────────────────────────────
// LUMINOUS FRAME — continuous clean glowing border
// ─────────────────────────────────────────────────────────────────────────────
class _LuminousFramePainter extends CustomPainter {
  final double frameSize;
  final double centerY;

  static const _gold = Color(0xFFEF9F27);
  static const _radius = 28.0;

  _LuminousFramePainter({
    required this.frameSize,
    required this.centerY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: frameSize,
      height: frameSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(_radius));

    // ── Static base border (very subtle) ─────────────────────────────────
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, basePaint);

    // ── Ambient glow behind frame border ─────────────────────────────────
    final glowPaint = Paint()
      ..color = _gold.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawRRect(rrect, glowPaint);
    
    // ── Inner core glow to make it stand out a bit more ──────────────────
    final coreGlowPaint = Paint()
      ..color = _gold.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect, coreGlowPaint);
  }

  @override
  bool shouldRepaint(covariant _LuminousFramePainter old) =>
      old.frameSize != frameSize || old.centerY != centerY;
}
