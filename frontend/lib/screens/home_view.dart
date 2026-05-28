import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';
import '../widgets/transaction_item.dart';
import 'history_screen.dart';
import '../utils/error_translator.dart';
import 'profile_page.dart';
import 'payment_methods_screen.dart';
import 'package:flutter/services.dart';

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
            ),
          );
        }

        final isReady = state.status == 'success';

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPayPerUseCard(context, state, isDark),
                          const SizedBox(height: 28),
                          _buildActionRow(context, l10n),
                          const SizedBox(height: 32),
                          _buildRecentTransactionsHeader(context, l10n),
                          const SizedBox(height: 12),
                          _buildTransactionList(state.transactions),
                        ],
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
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
        icon: const Icon(Icons.notifications_none_rounded),
        onPressed: () {},
      ),
      title: Text(
        AppLocalizations.of(context)!.appTitle,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          ),
        ),
      ],
    );
  }

  Widget _buildPayPerUseCard(BuildContext context, DashboardState state, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
            ? [const Color(0xFF085041), const Color(0xFF04342C)]
            : [const Color(0xFF0F6E56), const Color(0xFF085041)],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.payments_outlined,
              size: 150,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "PAY PER USE",
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFEF9F27),
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.isOffline)
                      const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 16),
                  ],
                ),
                const Spacer(),
                Text(
                  "Ready to Pay",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Scan QR to pay instantly from your linked card",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          Icons.credit_card_rounded,
          "Methods",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
          ),
        ),
        _buildActionButton(
          context,
          Icons.qr_code_scanner_rounded,
          "Scan",
          onTap: () {
            // Trigger global scan action
          },
        ),
        _buildActionButton(
          context,
          Icons.history_rounded,
          "History",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: theme.primaryColor.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, color: theme.primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.homeRecentTransactions,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text("No recent transactions"),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length > 5 ? 5 : transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => TransactionItem(transaction: transactions[index]),
    );
  }
}
