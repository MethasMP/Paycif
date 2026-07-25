import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_icon.dart';

enum AppNotificationToastType { success, error, info }

enum AppNotificationToastVibrationStyle {
  selection,
  light,
  medium,
  heavy,
  success,
  error,
  longSuccess,
}

class AppNotificationToast {
  static void show(
    BuildContext context,
    String message, {
    AppNotificationToastType type = AppNotificationToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;

    // Haptic Feedback based on type
    switch (type) {
      case AppNotificationToastType.success:
        HapticFeedback.mediumImpact();
        break;
      case AppNotificationToastType.error:
        HapticFeedback.heavyImpact();
        break;
      case AppNotificationToastType.info:
        HapticFeedback.selectionClick();
        break;
    }

    bool isDismissed = false;

    overlayEntry = OverlayEntry(
      builder: (context) => _AppNotificationToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          if (!isDismissed) {
            isDismissed = true;
            overlayEntry.remove();
          }
        },
        duration: duration,
      ),
    );

    overlayState.insert(overlayEntry);
  }

  // Shorthand methods
  static void success(BuildContext context, String message) =>
      show(context, message, type: AppNotificationToastType.success);
  static void error(BuildContext context, String message) =>
      show(context, message, type: AppNotificationToastType.error);
  static void info(BuildContext context, String message) =>
      show(context, message, type: AppNotificationToastType.info);

  static void vibrate({
    AppNotificationToastVibrationStyle style = AppNotificationToastVibrationStyle.selection,
  }) {
    switch (style) {
      case AppNotificationToastVibrationStyle.selection:
        HapticFeedback.selectionClick();
        break;
      case AppNotificationToastVibrationStyle.light:
        HapticFeedback.lightImpact();
        break;
      case AppNotificationToastVibrationStyle.medium:
        HapticFeedback.mediumImpact();
        break;
      case AppNotificationToastVibrationStyle.heavy:
        HapticFeedback.heavyImpact();
        break;
      case AppNotificationToastVibrationStyle.success:
        HapticFeedback.lightImpact();
        Future.delayed(const Duration(milliseconds: 50), () {
          HapticFeedback.lightImpact();
        });
        break;
      case AppNotificationToastVibrationStyle.error:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.heavyImpact();
        });
        break;
      case AppNotificationToastVibrationStyle.longSuccess:
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.mediumImpact();
          Future.delayed(const Duration(milliseconds: 100), () {
            HapticFeedback.heavyImpact();
          });
        });
        break;
    }
  }
}

class _AppNotificationToastWidget extends StatefulWidget {
  final String message;
  final AppNotificationToastType type;
  final VoidCallback onDismiss;
  final Duration duration;

  const _AppNotificationToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_AppNotificationToastWidget> createState() => _AppNotificationToastWidgetState();
}

class _AppNotificationToastWidgetState extends State<_AppNotificationToastWidget> {
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
      case AppNotificationToastType.success:
        baseColor = AppTheme.successGreen; // Emerald
        icon = PhosphorIcons.checkCircle;
        break;
      case AppNotificationToastType.error:
        baseColor = AppTheme.errorRed; // Rose
        icon = PhosphorIcons.warningCircle;
        break;
      case AppNotificationToastType.info:
        baseColor = AppTheme.infoBlue; // Blue
        icon = PhosphorIcons.info;
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
                  // Solid card toast — glass is reserved for the nav dock.
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceCard : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: baseColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
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
                          child: AppIcon(icon, color: baseColor, size: AppIconSize.sm),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
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
