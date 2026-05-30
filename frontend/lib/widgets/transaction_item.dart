import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../models/transaction.dart';
import '../theme/app_theme.dart';

import '../factories/transaction_icon_factory.dart';

class TransactionItem extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionItem({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    // 1. Determine Type & Color Logic
    // 'PAYOUT' and 'DEBIT' are Money Out (Expenses)
    // 'CREDIT' and 'TOPUP' are Money In (Income)
    final isDebit = transaction.type == 'PAYOUT' || transaction.type == 'DEBIT';
    final isCredit = transaction.type == 'CREDIT';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Smart Icon Logic (Delegated to Factory)
    final iconData = TransactionIconFactory.create(
      transaction.description,
      isDebit,
    );

    // 3. Color Palette - "Thai Money is Green" (all THB amounts are teal)
    final amountColor = AppTheme.primaryColor(context);

    final iconBgColor = isDark
        ? const Color(0xFF2BBF9E).withValues(alpha: 0.1)
        : const Color(0xFFE1F5EE); // primary-100

    final iconColor = AppTheme.primaryColor(context);

    // 4. Formatting
    final prefix = isCredit ? '+' : '-';
    // Using a simpler number format if desired, or keeping existing
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final formattedAmount = currencyFormat.format(
      transaction.amount / 100,
    ); // Satang to Baht

    // 5. Title & Subtitle
    // If description is generic, make it cleaner
    String title = transaction.description;
    if (title.isEmpty) title = isDebit ? 'Payment' : 'Deposit';
    if (title.contains('Unknown Merchant')) {
      title = 'Merchant Payment'; // Clean up generic backend text
    }

    // Subtitle: Time + Source (simulated)
    final timeStr = DateFormat('MMM d, h:mm a').format(transaction.createdAt);

    return Semantics(
      label: 'Transaction: $title, $prefix$formattedAmount, $timeStr',
      button: true,
      child: InkWell(
        onTap: () {
          // 🧠 Haptic Language:
          // Debit = Double Thump (Heavy) | Credit = Success Chirp (Light)
          if (isDebit) {
            HapticFeedback.heavyImpact(); // First thump
            Future.delayed(const Duration(milliseconds: 80), () {
              HapticFeedback.mediumImpact(); // Second thump
            });
          } else {
            HapticFeedback.lightImpact(); // Chirp
          }
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // --- Icon Container ---
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 20),
                ),
              ),
              const SizedBox(width: 16),

              // --- Title & Subtitle ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                      ), // H2: 20/28, 500
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor(context),
                      ), // Caption: 13/20, 400
                    ),
                  ],
                ),
              ),

              // --- Amount ---
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${isCredit ? '+' : '-'} THB $formattedAmount', // Western digits, THB symbol before
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: amountColor,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ), // Numeric: 28/36, 500
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
