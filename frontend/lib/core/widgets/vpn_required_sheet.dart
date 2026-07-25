import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_icon.dart';

/// 🛡️ VpnRequiredSheet — Apple HIG & World-class Security Sheet Standard
///
/// Presented when a VPN connection is detected during money-movement actions.
/// Provides clear context, explanation of security policy, and clean CTA.
class VpnRequiredSheet extends StatelessWidget {
  const VpnRequiredSheet({super.key});

  /// Convenience display trigger
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const VpnRequiredSheet(),
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
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBorderHairline : AppTheme.lightBorderHairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Neutral Security Badge (Apple HIG Style — Non-alarmist slate/teal tint)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              PhosphorIcons.globeHemisphereWest,
              color: isDark ? Colors.white : AppTheme.primaryColor(context),
              size: AppIconSize.lg,
            ),
          ),
          const SizedBox(height: 20),

          // Title (Apple HIG: Action-oriented & Direct)
          const Text(
            'Turn Off VPN to Pay',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),

          // Body Copy (Apple HIG: User-centric, clear reason + immediate solution)
          Text(
            'PromptPay requires a direct connection to confirm your local payment location in Thailand. Once turned off, you can resume scanning immediately.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 28),

          // Primary CTA — Got It
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : AppTheme.primaryColor(context),
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text(
                'Got It',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
