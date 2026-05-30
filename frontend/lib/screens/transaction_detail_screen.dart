import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import '../models/transaction.dart';
import '../utils/pay_notify.dart';
import '../widgets/paycif_icon_container.dart';
import '../widgets/paycif_amount_text.dart';
import '../theme/app_theme.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDebit = transaction.type == 'PAYOUT' || transaction.type == 'DEBIT';
    final isCredit = transaction.type == 'CREDIT';

    final prefix = isCredit ? '+' : '-';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  PaycifIconContainer(
                    icon: isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCredit
                        ? l10n.transactionReceivedFrom
                        : l10n.transactionPaidTo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transaction.description.isEmpty
                        ? (isDebit
                            ? l10n.transactionMerchantPayment
                            : 'Deposit')
                        : transaction.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$prefix ',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor(context),
                            ),
                      ),
                      PaycifAmountText(
                        amount: transaction.amount / 100,
                        isLarge: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    context,
                    l10n.transactionStatus,
                    l10n.transactionStatusCompleted,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  _buildDetailRow(
                    context,
                    l10n.transactionTime,
                    DateFormat(
                      'MMM d, yyyy • h:mm a',
                    ).format(transaction.createdAt),
                  ),
                  _buildDetailRow(
                    context,
                    l10n.transactionId,
                    transaction.id.substring(0, 8).toUpperCase(),
                  ),
                  _buildDetailRow(
                    context,
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
              child: Semantics(
                label: 'Get help with this transaction',
                button: true,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor(context),
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color ?? AppTheme.textPrimaryColor(context),
                ),
          ),
        ],
      ),
    );
  }
}
