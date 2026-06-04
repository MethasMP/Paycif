import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PaycifIconContainer extends StatelessWidget {
  final IconData icon;
  final double size;

  const PaycifIconContainer({
    super.key,
    required this.icon,
    this.size = 28.0, // Slightly larger for premium visibility
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium adaptive styling
    final Color backgroundColor = isDark
        ? Theme.of(context).colorScheme.surface // Deep surface background
        : AppTheme.primaryTealLight; // Soft teal tint #E1F5EE
        
    final Color borderColor = isDark
        ? AppTheme.accentGoldDisabled.withValues(alpha: 0.15) // Subtle gold border in dark mode
        : AppTheme.primaryTeal.withValues(alpha: 0.2); // Teal stroke in light mode
        
    final Color iconColor = isDark
        ? AppTheme.accentGoldDisabled // Gold accent icon in dark mode
        : AppTheme.primaryTeal; // Teal icon in light mode

    return Container(
      padding: const EdgeInsets.all(16), // Extra padding for breathing room
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? AppTheme.accentGoldDisabled.withValues(alpha: 0.05) 
                : AppTheme.primaryTeal.withValues(alpha: 0.03),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: size,
      ),
    );
  }
}
