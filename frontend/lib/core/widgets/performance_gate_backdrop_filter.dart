import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

class PerformanceGateBackdropFilter extends StatelessWidget {
  final double sigmaX;
  final double sigmaY;
  final Widget child;
  final Color fallbackColor;
  final Color? blurredColor;

  const PerformanceGateBackdropFilter({
    super.key,
    required this.sigmaX,
    required this.sigmaY,
    required this.child,
    this.fallbackColor = const Color(0xF00B0F0E), // High opacity near-black for safety
    this.blurredColor,
  });

  @override
  Widget build(BuildContext context) {
    final enableBlur = AppTheme.shouldEnableBlur(context);

    if (!enableBlur) {
      // Return a standard Container with solid/opaque background to guarantee readable text
      return Container(
        color: fallbackColor,
        child: child,
      );
    }

    // Default high-performance glass effect
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          color: blurredColor ?? Colors.black.withValues(alpha: 0.35),
          child: child,
        ),
      ),
    );
  }
}
