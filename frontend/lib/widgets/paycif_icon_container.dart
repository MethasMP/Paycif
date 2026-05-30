import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PaycifIconContainer extends StatelessWidget {
  final IconData icon;
  final double size;

  const PaycifIconContainer({
    super.key,
    required this.icon,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryTealLight, // #E1F5EE
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryTeal.withValues(alpha: 0.2), // Teal stroke
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        color: AppTheme.primaryTeal,
        size: size,
      ),
    );
  }
}
