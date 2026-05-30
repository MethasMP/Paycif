import 'package:flutter/material.dart';
import '../../services/qr_aggregator_service.dart';
import '../../theme/app_theme.dart';

class PaymentPreviewBottomSheet extends StatelessWidget {
  final PaymentContext context;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PaymentPreviewBottomSheet({
    super.key,
    required this.context,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Symbol of the method
          _buildMethodIcon(),
          const SizedBox(height: 16),

          // Merchant Name
          Text(
            this.context.title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            this.context.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
          ),

          const SizedBox(height: 32),

          // Amount Display (if available)
          if (this.context.amount != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount to Pay',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '${this.context.amount} ${this.context.currency}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor(context),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Trust Badge
          if (this.context.isSafe)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Verified via Paycif Layer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodIcon() {
    IconData icon;
    Color color;

    switch (context.method) {
      case PaymentMethodType.promptPay:
        icon = Icons.account_balance_rounded;
        color = const Color(0xFF1A1F71);
        break;
      case PaymentMethodType.billPayment:
        icon = Icons.receipt_long_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case PaymentMethodType.shopeePay:
        icon = Icons.shopping_bag_rounded;
        color = const Color(0xFFEE4D2D); // Shopee Orange
        break;
      case PaymentMethodType.truemoney:
        icon = Icons.account_balance_wallet_rounded;
        color = const Color(0xFFFF8100); // TrueMoney Orange
        break;
      default:
        icon = Icons.qr_code_2_rounded;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}
