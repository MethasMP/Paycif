import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../widgets/transaction_item.dart';
import 'history_screen.dart';
import '../utils/error_translator.dart';
import 'profile_page.dart';
import 'scan_page.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<DashboardController, DashboardState>(
      builder: (context, state) {
        if (state.status == 'error') {
          return Center(
            child: Text(
              "${l10n.commonError}: ${ErrorTranslator.translate(l10n, state.errorMessage ?? '')}",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          );
        }

        final isReady = state.status == 'success';

        return Scaffold(
          backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.white, // White background for Light Mode
          appBar: _buildAppBar(context),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: isReady
                ? RefreshIndicator(
                    onRefresh: () async => context.read<DashboardController>().refresh(),
                    color: theme.primaryColor,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 32),
                          // 1. Headline
                          Text(
                            "Ready to Pay",
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Scan any PromptPay or Paycif QR code to pay instantly",
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                          SizedBox(height: 48),
                          // 2. Gold CTA Center
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const ScanPage()),
                              ).then((_) {
                                if (mounted) context.read<DashboardController>().refresh();
                              });
                            },
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEF9F27), // accent-500
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F6E56).withValues(alpha: 0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  PhosphorIcons.qrCode,
                                  color: Color(0xFF412402), // accent-900
                                  size: 56,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 54),
                          // 3. Recent Transactions
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _buildRecentTransactionsHeader(context, l10n),
                          ),
                          SizedBox(height: 12),
                          _buildTransactionList(state.transactions),
                        ],
                      ),
                    ),
                  )
                : Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(PhosphorIcons.bell),
        onPressed: () {},
      ),
      title: Text(
        AppLocalizations.of(context)!.appTitle,
        style: theme.appBarTheme.titleTextStyle?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor(context),
          letterSpacing: -0.5,
        ) ?? theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor(context),
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(PhosphorIcons.gear),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.homeRecentTransactions,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryScreen()),
          ),
          child: Text(
            l10n.homeViewAll,
            style: theme.textTheme.labelLarge?.copyWith(
              color: const Color(0xFFEF9F27),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            "No recent transactions",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length > 5 ? 5 : transactions.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) => TransactionItem(transaction: transactions[index]),
    );
  }
}
