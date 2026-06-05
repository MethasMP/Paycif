import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum PaycifButtonVariant { primary, secondary, accent, ghost }
enum PaycifButtonSize { md, lg }

class PaycifButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final PaycifButtonVariant variant;
  final PaycifButtonSize size;
  final bool isLoading;
  final IconData? icon;

  const PaycifButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = PaycifButtonVariant.primary,
    this.size = PaycifButtonSize.lg,
    this.isLoading = false,
    this.icon,
  });

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Height calculation
    final double height = size == PaycifButtonSize.lg ? 56.0 : 48.0;

    // Text Style
    final TextStyle textStyle = theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: size == PaycifButtonSize.lg ? 16.0 : 14.0,
        ) ??
        const TextStyle();

    // Background color
    Color getBgColor() {
      if (_isDisabled) {
        if (variant == PaycifButtonVariant.ghost || variant == PaycifButtonVariant.secondary) {
          return Colors.transparent;
        }
        return isDark 
            ? AppTheme.accentGoldDisabled.withValues(alpha: 0.3) 
            : AppTheme.primaryTealLight;
      }

      switch (variant) {
        case PaycifButtonVariant.primary:
          return isDark ? AppTheme.darkTheme.primaryColor : AppTheme.primaryTeal;
        case PaycifButtonVariant.secondary:
          return Colors.transparent;
        case PaycifButtonVariant.accent:
          return isDark ? AppTheme.darkTheme.colorScheme.secondary : AppTheme.accentGold;
        case PaycifButtonVariant.ghost:
          return Colors.transparent;
      }
    }

    // Foreground color
    Color getFgColor() {
      if (_isDisabled) {
        return theme.disabledColor;
      }

      switch (variant) {
        case PaycifButtonVariant.primary:
          return Colors.white;
        case PaycifButtonVariant.secondary:
          return isDark ? AppTheme.darkTheme.primaryColor : AppTheme.primaryTeal;
        case PaycifButtonVariant.accent:
          return AppTheme.accentGoldDark;
        case PaycifButtonVariant.ghost:
          return isDark ? Colors.white70 : AppTheme.textSecondary;
      }
    }

    // Border side
    BorderSide? getBorder() {
      if (variant == PaycifButtonVariant.secondary) {
        final Color color = _isDisabled 
            ? theme.disabledColor.withValues(alpha: 0.5)
            : (isDark ? AppTheme.darkTheme.primaryColor : AppTheme.primaryTeal);
        return BorderSide(color: color, width: 1.5);
      }
      return BorderSide.none;
    }

    return SizedBox(
      height: height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isDisabled ? 0.6 : 1.0,
        child: OutlinedButton(
          onPressed: _isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: getBgColor(),
            foregroundColor: getFgColor(),
            side: getBorder(),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(9999)), // Pill shape
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            elevation: 0,
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(getFgColor()),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: size == PaycifButtonSize.lg ? 20 : 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: textStyle.copyWith(color: getFgColor()),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
