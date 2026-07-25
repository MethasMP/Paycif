import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:frontend/features/transactions/domain/transaction.dart';
import 'package:frontend/core/widgets/transaction_item.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_icon.dart';

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

    return BlocBuilder<DashboardController, DashboardState>(
      builder: (context, state) {
        // We no longer block the entire screen with an error. 
        // Background auto-retry handles recovery. If it ultimately fails, we just render the dashboard (which will show an empty state or cached data)
        // so the user can still pull-to-refresh or navigate elsewhere.
        
        final showDashboard = state.status == 'success' || state.status == 'error' || (state.status == 'loading' && state.transactions.isNotEmpty);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: _buildAppBar(context, theme, l10n),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: showDashboard
                ? RefreshIndicator(
                    onRefresh: () async => context.read<DashboardController>().refresh(),
                    color: theme.primaryColor,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 120),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.status == 'error')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                "Offline mode. Showing cached data.",
                                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor(context)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            
                          const SizedBox(height: 12),
                          
                          // Quick Actions Label
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              l10n.homeQuickActions,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildQuickActionsDock(context, l10n, theme),
                          const SizedBox(height: 40),
                          
                          // Recent Transactions
                          _buildRecentTransactionsHeader(context, theme, l10n),
                          const SizedBox(height: 16),
                          _buildTransactionContainer(context, state.transactions, theme, l10n),
                          const SizedBox(height: 32),
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

  Widget _buildQuickActionsDock(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            label: l10n.homeActionCards,
            icon: PhosphorIconsRegular.creditCard,
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/payment_settings');
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            label: l10n.homeActionRates,
            icon: PhosphorIconsRegular.chartLineUp,
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/history');
            },
          ),
        ),
      ],
    );
  }

  // --- Transaction Container Card ---
  Widget _buildTransactionContainer(BuildContext context, List<Transaction> transactions, ThemeData theme, AppLocalizations l10n) {
    final isDark = theme.brightness == Brightness.dark;

    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkTheme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white12 : AppTheme.borderGrey,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              AppIcon(
                PhosphorIconsRegular.receipt,
                size: AppIconSize.lg,
                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homeNoRecentTransactions,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final itemCount = transactions.length > 5 ? 5 : transactions.length;
    final displayList = transactions.take(itemCount).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkTheme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : AppTheme.borderGrey,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Fix: Replaced `shrinkWrap` ListView with Column mapping for performance
      child: Column(
        children: displayList.asMap().entries.map((entry) {
          final int index = entry.key;
          final Transaction tx = entry.value;
          final bool isLast = index == displayList.length - 1;
          
          return Column(
            children: [
              TransactionItem(transaction: tx),
              if (!isLast)
                Divider(
                  color: isDark ? Colors.white12 : AppTheme.borderGrey,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        l10n.appTitle,
        style: theme.appBarTheme.titleTextStyle?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: AppTheme.textPrimaryColor(context),
          letterSpacing: -0.6,
        ) ?? theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: AppTheme.textPrimaryColor(context),
          letterSpacing: -0.6,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            icon: Semantics(
              label: "Settings",
              child: AppIcon(
                PhosphorIconsRegular.gear,
                size: AppIconSize.md,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            onPressed: () => context.push('/profile'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsHeader(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.homeRecentTransactions,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/history'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              children: [
                Text(
                  l10n.homeViewAll,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                AppIcon(
                  PhosphorIconsBold.caretRight,
                  color: AppTheme.textPrimaryColor(context),
                  size: AppIconSize.xs,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Custom Animated Quick Action Card with Press Feedback ---
class _QuickActionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color cardBg = isDark ? AppTheme.darkTheme.cardColor : Colors.white;
    final Color iconBg = isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.primaryTealLight;
    final Color iconColor = isDark ? AppTheme.primaryColor(context) : AppTheme.primaryTealDark;
    final Color labelColor = isDark ? Colors.white.withValues(alpha: 0.87) : AppTheme.textPrimaryColor(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Semantics(
        button: true,
        label: widget.label,
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutQuad,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutQuad,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : AppTheme.borderGrey,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: _isPressed ? 4 : 8,
                  offset: Offset(0, _isPressed ? 1 : 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(widget.icon, color: iconColor, size: AppIconSize.sm),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
