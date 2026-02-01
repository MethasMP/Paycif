import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

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
    final isCredit =
        transaction.type == 'CREDIT' || transaction.type == 'TOPUP';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Smart Icon Logic (Delegated to Factory)
    final iconData = TransactionIconFactory.create(
      transaction.description,
      isDebit,
    );

    // 3. Color Palette
    // Spending: Red for "Money Out"
    // Income: Emerald/Green for "Money In"
    final amountColor = isCredit
        ? const Color(0xFF10B981) // Emerald-500
        : const Color(0xFFEF4444); // Red-500

    final iconBgColor = isCredit
        ? const Color(0xFFD1FAE5) // Emerald-100
        : (isDark
              ? const Color(0xFF450A0A) // Red-950 (Dark mode BG)
              : const Color(0xFFFEE2E2)); // Red-100 (Light mode BG)

    final iconColor = isCredit
        ? const Color(0xFF059669) // Emerald-600
        : (isDark
              ? const Color(0xFFF87171) // Red-400 (Dark mode Icon)
              : const Color(0xFFDC2626)); // Red-600 (Light mode Icon)

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
    if (title.isEmpty) title = isDebit ? 'Payment' : 'Top Up';
    if (title.contains('Unknown Merchant')) {
      title = 'Merchant Payment'; // Clean up generic backend text
    }

    // Subtitle: Time + Source (simulated)
    final timeStr = DateFormat('MMM d, h:mm a').format(transaction.createdAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            // --- Icon Container ---
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(22), // Circular/Pill shape
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),

            // --- Title & Subtitle ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600, // Semi-bold for title
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr, // Simplify subtitle to just time/date for now
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.grey[400]
                          : const Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // --- Amount ---
            const SizedBox(width: 8),
            Text(
              '$prefix$formattedAmount',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600, // Medium weight for numbers
                color: amountColor,
                fontFamily:
                    'RobotoMono', // Optional: Monospaced for numbers alignment if available, else default
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
