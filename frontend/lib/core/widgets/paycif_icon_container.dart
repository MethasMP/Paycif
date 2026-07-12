import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

class PaycifIconContainer extends StatelessWidget {
  final IconData icon;
  final double size;

  const PaycifIconContainer({
    super.key,
    required this.icon,
    this.size = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color tint = AppTheme.primaryColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.14 : 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: tint,
        size: size,
      ),
    );
  }
}
