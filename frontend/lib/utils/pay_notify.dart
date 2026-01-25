import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum PayNotifyType { success, error, info }

class PayNotify {
  static void show(
    BuildContext context,
    String message, {
    PayNotifyType type = PayNotifyType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;

    // Haptic Feedback based on type
    switch (type) {
      case PayNotifyType.success:
        HapticFeedback.mediumImpact();
        break;
      case PayNotifyType.error:
        HapticFeedback.heavyImpact();
        break;
      case PayNotifyType.info:
        HapticFeedback.selectionClick();
        break;
    }

    overlayEntry = OverlayEntry(
      builder: (context) => _PayNotifyWidget(
        message: message,
        type: type,
        onDismiss: () => overlayEntry.remove(),
        duration: duration,
      ),
    );

    overlayState.insert(overlayEntry);
  }

  // Shorthand methods
  static void success(BuildContext context, String message) =>
      show(context, message, type: PayNotifyType.success);
  static void error(BuildContext context, String message) =>
      show(context, message, type: PayNotifyType.error);
  static void info(BuildContext context, String message) =>
      show(context, message, type: PayNotifyType.info);
}

class _PayNotifyWidget extends StatefulWidget {
  final String message;
  final PayNotifyType type;
  final VoidCallback onDismiss;
  final Duration duration;

  const _PayNotifyWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_PayNotifyWidget> createState() => _PayNotifyWidgetState();
}

class _PayNotifyWidgetState extends State<_PayNotifyWidget> {
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) {
        setState(() => _isExiting = true);
        Future.delayed(400.ms, widget.onDismiss);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color baseColor;
    IconData icon;
    switch (widget.type) {
      case PayNotifyType.success:
        baseColor = const Color(0xFF10B981); // Emerald
        icon = Icons.check_circle_rounded;
        break;
      case PayNotifyType.error:
        baseColor = const Color(0xFFEF4444); // Rose
        icon = Icons.error_rounded;
        break;
      case PayNotifyType.info:
        baseColor = const Color(0xFF3B82F6); // Blue
        icon = Icons.info_rounded;
        break;
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child:
            GestureDetector(
                  onTap: () {
                    setState(() => _isExiting = true);
                    Future.delayed(400.ms, widget.onDismiss);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: baseColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: baseColor.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: baseColor.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: baseColor, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .animate(target: _isExiting ? 0 : 1)
                .slideY(
                  begin: -1.5,
                  end: 0,
                  curve: Curves.easeOutBack,
                  duration: 600.ms,
                )
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1))
                .then()
                .shake(duration: 400.ms, hz: 4)
                .animate(target: _isExiting ? 1 : 0)
                .slideY(end: -1.5, curve: Curves.easeInBack, duration: 400.ms)
                .fadeOut(duration: 300.ms),
      ),
    );
  }
}
