import 'dart:ui';
import 'package:flutter/material.dart';

class PremiumScannerOverlay extends StatefulWidget {
  final double frameSize;
  const PremiumScannerOverlay({super.key, required this.frameSize});

  @override
  State<PremiumScannerOverlay> createState() => _PremiumScannerOverlayState();
}

class _PremiumScannerOverlayState extends State<PremiumScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = (size.height / 2 - 60) - (widget.frameSize / 2);

    return Stack(
      children: [
        // 1. Semi-transparent blurred background
        ClipPath(
          clipper: _ScannerCutoutClipper(frameSize: widget.frameSize),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),

        // 2. Animated Laser Line
        AnimatedBuilder(
          animation: _scanAnimation,
          builder: (context, child) {
            final dynamicPos =
                topPadding + (widget.frameSize * _scanAnimation.value);

            return Positioned(
              top: dynamicPos,
              left: (size.width / 2) - (widget.frameSize / 2),
              child: Container(
                width: widget.frameSize,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: 0.0),
                      const Color(0xFFF59E0B),
                      const Color(0xFFF59E0B).withValues(alpha: 0.0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // 3. Static Designer Corners
        CustomPaint(
          painter: _ScannerFramePainter(frameSize: widget.frameSize),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

class _ScannerCutoutClipper extends CustomClipper<Path> {
  final double frameSize;
  _ScannerCutoutClipper({required this.frameSize});

  @override
  Path getClip(Size size) {
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 60),
      width: frameSize,
      height: frameSize,
    );

    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addRRect(
        RRect.fromRectAndRadius(scanRect, const Radius.circular(24)),
      ),
    );
  }

  @override
  bool shouldReclip(covariant _ScannerCutoutClipper oldClipper) =>
      oldClipper.frameSize != frameSize;
}

class _ScannerFramePainter extends CustomPainter {
  final double frameSize;
  _ScannerFramePainter({required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 60),
      width: frameSize,
      height: frameSize,
    );

    final paint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 40.0;
    const radius = 24.0;

    // Drawing premium corners with subtle rounding
    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + cornerLength)
        ..lineTo(rect.left, rect.top + radius)
        ..arcToPoint(
          Offset(rect.left + radius, rect.top),
          radius: const Radius.circular(radius),
        )
        ..lineTo(rect.left + cornerLength, rect.top),
      paint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerLength, rect.top)
        ..lineTo(rect.right - radius, rect.top)
        ..arcToPoint(
          Offset(rect.right, rect.top + radius),
          radius: const Radius.circular(radius),
        )
        ..lineTo(rect.right, rect.top + cornerLength),
      paint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.bottom - cornerLength)
        ..lineTo(rect.left, rect.bottom - radius)
        ..arcToPoint(
          Offset(rect.left + radius, rect.bottom),
          radius: const Radius.circular(radius),
        )
        ..lineTo(rect.left + cornerLength, rect.bottom),
      paint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - cornerLength, rect.bottom)
        ..lineTo(rect.right - radius, rect.bottom)
        ..arcToPoint(
          Offset(rect.right, rect.bottom - radius),
          radius: const Radius.circular(radius),
        )
        ..lineTo(rect.right, rect.bottom - cornerLength),
      paint,
    );

    // Subtle Glow around the inner edge of cutout
    final glowPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) =>
      oldDelegate.frameSize != frameSize;
}
