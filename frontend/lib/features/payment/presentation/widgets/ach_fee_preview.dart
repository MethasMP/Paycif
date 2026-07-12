import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/paycif_button.dart';
import 'package:frontend/features/payment/data/ach_onramp_service.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:frontend/core/widgets/app_icon.dart';

/// Bottom sheet shown before opening the ACH widget.
/// Displays supported payment methods + fee structure for the user's currency.
/// User taps "Continue" → app launches ACH widget.
class AchFeePreviewSheet extends StatelessWidget {
  final List<AchFiatMethod> methods;
  final String currency;
  final VoidCallback onConfirm;

  const AchFeePreviewSheet({
    super.key,
    required this.methods,
    required this.currency,
    required this.onConfirm,
  });

  static Future<bool> show(
    BuildContext context, {
    required List<AchFiatMethod> methods,
    required String currency,
    required VoidCallback onConfirm,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AchFeePreviewSheet(
        methods: methods,
        currency: currency,
        onConfirm: onConfirm,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final Color mutedColor = AppTheme.textSecondaryColor(context);
    final Color handleColor = isDark ? Colors.white24 : AppTheme.borderGrey;
    final filtered = methods.isEmpty
        ? <AchFiatMethod>[]
        : methods.where((m) => m.currency == currency).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.payViaCardPartnerTitle,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.payViaCardPartnerSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          const SizedBox(height: 20),

          if (filtered.isEmpty)
            _InfoRow(
              icon: PhosphorIcons.creditCard,
              label: 'Card / Apple Pay / Google Pay',
              value: 'Fees shown in checkout',
              mutedColor: mutedColor,
            )
          else ...[
            Text(
              'Payment methods for $currency',
              style: theme.textTheme.labelMedium?.copyWith(
                color: mutedColor,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            ...filtered.map((m) => _MethodRow(method: m, mutedColor: mutedColor)),
          ],

          const SizedBox(height: 8),
          _InfoRow(
            icon: PhosphorIcons.lock,
            label: 'Apple Pay on iPhone',
            value: 'Supported in-app',
            mutedColor: mutedColor,
          ),
          _InfoRow(
            icon: PhosphorIcons.arrowSquareOut,
            label: 'Google Pay on Android',
            value: 'Opens browser',
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: PaycifButton(
              text: 'Continue to Payment',
              variant: PaycifButtonVariant.primary,
              size: PaycifButtonSize.lg,
              onPressed: () {
                Navigator.of(context).pop(true);
                onConfirm();
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _feeLabel(AchFiatMethod method) {
  final parts = <String>[];
  if (method.feeRate > 0) parts.add('${(method.feeRate * 100).toStringAsFixed(1)}%');
  if (method.fixedFee > 0) {
    parts.add('${method.fixedFee.toStringAsFixed(2)} ${method.currency}');
  }
  return parts.isEmpty ? 'No fee' : parts.join(' + ');
}

class _MethodRow extends StatelessWidget {
  final AchFiatMethod method;
  final Color mutedColor;
  const _MethodRow({required this.method, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          AppIcon(PhosphorIcons.wallet, size: AppIconSize.sm, color: AppTheme.primaryColor(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(method.payWayName,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          ),
          Text(_feeLabel(method),
              style: theme.textTheme.bodySmall?.copyWith(color: mutedColor)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color mutedColor;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          AppIcon(icon, size: AppIconSize.sm, color: mutedColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(color: mutedColor)),
          ),
          Text(value,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
