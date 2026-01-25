import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/transaction_item.dart';
import 'transaction_detail_screen.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        // Style inherited from AppTheme.titleLarge via AppBarTheme.titleTextStyle
      ),
      body: BlocBuilder<DashboardController, DashboardState>(
        builder: (context, state) {
          if (state.transactions.isEmpty) {
            return _buildEmptyState(context);
          }

          final grouped = _groupTransactions(
            state.transactions,
            context,
          ); // Pass context

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final dateKey = grouped.keys.elementAt(index);
              final transactions = grouped[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      dateKey.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...transactions.map(
                    (tx) => TransactionItem(
                      transaction: tx,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TransactionDetailScreen(transaction: tx),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<Transaction>> _groupTransactions(
    List<Transaction> transactions,
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final Map<String, List<Transaction>> grouped = {};
    for (var tx in transactions) {
      final date = tx.createdAt; // Assuming ISO String
      final now = DateTime.now();
      String key;

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        key = l10n.commonToday;
      } else if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day - 1) {
        key = l10n.commonYesterday;
      } else {
        key = DateFormat('MMMM d').format(date);
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 60,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.historyNoActivity,
            style: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
