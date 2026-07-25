import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_icon.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KYC REQUIRED SHEET
//
// Shown when an unverified user attempts to pay. Explains that identity
// verification is required before the first payment and routes them into the
// KYC flow. Mirrors the styling of PaymentCheckoutSheet (solid card surface,
// rounded top, theme-aware light/dark).
//
// Returns via Navigator.pop(true) when the user taps "Verify Now" so the caller
// can launch the KYC flow; pops with `false`/`null` otherwise.
// ─────────────────────────────────────────────────────────────────────────────
class KycRequiredSheet extends StatelessWidget {
  const KycRequiredSheet({super.key});

  /// Convenience opener — returns `true` when the user chose to verify.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const KycRequiredSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 16,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBorderHairline : AppTheme.lightBorderHairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Icon badge
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const AppIcon(
              PhosphorIcons.identificationCard,
              color: AppTheme.primaryTeal,
              size: AppIconSize.lg,
            ),
          ),
          const SizedBox(height: 20),

          // Heading
          const Text(
            'Verify your identity',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),

          // Supporting copy
          Text(
            'A quick one-time identity check is required before your first payment. It only takes a minute.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 28),

          // Primary CTA — Verify Now
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text(
                'Verify Now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary — dismiss without proceeding
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondaryColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text(
                'Not now',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
