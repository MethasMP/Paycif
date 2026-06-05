import 'package:flutter/material.dart';
import '../../domain/entities/payment_breakdown.dart';
import '../../../../theme/app_theme.dart';

class FxBreakdownCard extends StatelessWidget {
  final PaymentBreakdown breakdown;

  const FxBreakdownCard({
    super.key,
    required this.breakdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color labelColor = AppTheme.textSecondaryColor(context);
    final Color valueColor = AppTheme.textPrimaryColor(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.borderGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Amount",
                style: theme.textTheme.bodyMedium?.copyWith(color: labelColor),
              ),
              Text(
                "${breakdown.amountTHB.toStringAsFixed(2)} THB",
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderGrey),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "FX Rate",
                style: theme.textTheme.bodySmall?.copyWith(color: labelColor),
              ),
              Text(
                "1 USD ≈ ${breakdown.exchangeRate.toStringAsFixed(2)} THB",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Network Fee (3.5%)",
                style: theme.textTheme.bodySmall?.copyWith(color: labelColor),
              ),
              Text(
                "\$${breakdown.feeUSD.toStringAsFixed(2)} USD",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderGrey),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "Total",
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: const Color(0xFF028090),
                ),
              ),
              Text(
                "\$${breakdown.totalUSD.toStringAsFixed(2)} USD",
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
