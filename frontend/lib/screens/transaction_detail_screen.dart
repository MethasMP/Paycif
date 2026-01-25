import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../models/transaction.dart';
import '../utils/pay_notify.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDebit = transaction.type == 'PAYOUT' || transaction.type == 'DEBIT';
    final isCredit =
        transaction.type == 'CREDIT' || transaction.type == 'TOPUP';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final amountColor = isCredit
        ? const Color(0xFF10B981) // Emerald-500
        : const Color(0xFFEF4444); // Red-500

    final prefix = isCredit ? '+' : '-';
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final formattedAmount = currencyFormat.format(transaction.amount / 100);

    return Scaffold(
      backgroundColor: isDark
          ? Colors.black
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.transactionDetailsTitle),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 1. Top Section - Receipt Style
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: amountColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCredit
                        ? l10n.transactionReceivedFrom
                        : l10n.transactionPaidTo,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transaction.description.isEmpty
                        ? (isDebit
                              ? l10n.transactionMerchantPayment
                              : l10n.transactionTopUpLabel)
                        : transaction.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$prefix ฿ ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                      ),
                      Text(
                        formattedAmount,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    l10n.transactionStatus,
                    l10n.transactionStatusCompleted,
                    color: Colors.green,
                  ),
                  _buildDetailRow(
                    l10n.transactionTime,
                    DateFormat(
                      'MMM d, yyyy • h:mm a',
                    ).format(transaction.createdAt),
                  ),
                  _buildDetailRow(
                    l10n.transactionId,
                    transaction.id.substring(0, 8).toUpperCase(),
                  ),
                  _buildDetailRow(
                    l10n.transactionMethod,
                    isCredit
                        ? l10n.transactionBankTransfer
                        : l10n.transactionPaycifWallet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // 2. Help Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  PayNotify.success(
                    context,
                    l10n.transactionSupportTicketCreated,
                  );
                },
                icon: const Icon(Icons.help_outline),
                label: Text(l10n.transactionHelp),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
