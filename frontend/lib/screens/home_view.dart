import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';

import '../widgets/transaction_item.dart';
import 'top_up_view.dart';
import 'transaction_detail_screen.dart';
import 'history_screen.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<DashboardController, DashboardState>(
      listenWhen: (previous, current) =>
          previous.wallet?.id != current.wallet?.id && current.wallet != null,
      listener: (context, state) {
        // Transactions are now auto-subscribed in controller
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(context),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            // final padding = screenWidth * 0.05; // Unused

            return BlocBuilder<DashboardController, DashboardState>(
              builder: (context, state) {
                if (state.status == 'error') {
                  return Center(
                    child: Text("${l10n.commonError}: ${state.errorMessage}"),
                  );
                }

                // SYNCHRONIZED DISPLAY: Show Skeleton until *everything* is ready
                final isReady = state.status == 'success';

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: isReady
                      ? RefreshIndicator(
                          key: const ValueKey('content'),
                          onRefresh: () async {
                            await context.read<DashboardController>().refresh();
                          },
                          color: const Color(0xFF1A1F71),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(screenWidth * 0.05),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLuxuryBalanceCard(
                                  context,
                                  state,
                                  screenWidth,
                                ),
                                SizedBox(height: screenWidth * 0.08),
                                // Actions
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildActionButton(
                                      Icons.add,
                                      l10n.homeTopUp,
                                      screenWidth,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const TopUpView(),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionButton(
                                      Icons.arrow_upward,
                                      l10n.homeInfo,
                                      screenWidth,
                                    ),
                                    _buildActionButton(
                                      Icons.more_horiz,
                                      l10n.homeMore,
                                      screenWidth,
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenWidth * 0.06),
                                // Recent Transactions Header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      l10n.homeRecentTransactions,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge?.color,
                                          ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const HistoryScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        l10n.homeViewAll,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: const Color(0xFFF59E0B),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildTransactionList(state.transactions),
                              ],
                            ),
                          ),
                        )
                      : _buildSkeletonDashboard(context, screenWidth),
                );
              },
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.notifications_none_rounded,
          color: Theme.of(context).iconTheme.color,
        ),
        onPressed: () {},
      ),
      title: Text(
        AppLocalizations.of(context)!.appTitle,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () {},
        ),
      ],
    );
  }

  // Currency Selector removed

  Widget _buildLuxuryBalanceCard(
    BuildContext context,
    DashboardState state,
    double screenWidth,
  ) {
    final currency = state.wallet?.currency ?? 'THB';
    final isLoading = state.status == 'loading' || state.status == 'initial';

    return Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // 1. Background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E293B), // Slate 800
                        Color(0xFF0F172A), // Slate 900
                        Color(0xFF000000), // Black
                      ],
                    ),
                  ),
                ),
                // 2. Glow
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // 3. Content
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Branding
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: const Color(0xFFF59E0B),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.homePaycifPremier,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: const Color(0xFFF59E0B),
                                      letterSpacing: 2.0,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.wifi,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 24,
                          ),
                        ],
                      ),
                      const Spacer(),
                      // EMV + Balance
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Chip Simulation (Simplified for brevity in replace)
                          Container(
                            width: 45,
                            height: 35,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFB8860B),
                                  Color(0xFFFFD700),
                                ],
                                stops: [0.1, 0.5, 0.9],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            // ... internal chip details omitted for cleaner code, add back if strict ...
                            // Adding back simple chip details
                            child: Stack(
                              children: [
                                Center(
                                  child: Container(
                                    width: 45,
                                    height: 1,
                                    color: Colors.black.withValues(alpha: 0.2),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: 1,
                                    height: 35,
                                    color: Colors.black.withValues(alpha: 0.2),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: 18,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.homeTotalBalance,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        letterSpacing: 0.5,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Text(
                                        isLoading
                                            ? '...'
                                            : state.formattedBalance,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                              fontFamily: 'Courier',
                                            ),
                                      ),
                                      if (state.isBalanceVisible &&
                                          !isLoading) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          currency,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: const Color(0xFFF59E0B),
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Dual currency display removed
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Bottom
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => context
                                .read<DashboardController>()
                                .toggleBalanceVisibility(),
                            child: Row(
                              children: [
                                Icon(
                                  state.isBalanceVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.homeShow,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context)!.homeWorldMember,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  letterSpacing: 1.5,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 30.seconds,
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.1),
          angle: 0.8,
        );
  }

  // Fair Rate Badge removed

  Widget _buildActionButton(
    IconData icon,
    String label,
    double screenWidth, {
    VoidCallback? onTap,
  }) {
    // ... (Use previous logic or simplified)
    final isSmall = screenWidth < 380;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: isSmall ? 50 : 60,
            height: isSmall ? 50 : 60,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : const Color(0xFF1A1F71),
              size: isSmall ? 24 : 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF374151),
              fontSize: isSmall ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long,
                size: 32,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.homeNoTransactions,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.homeNoTransactionsDesc,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: transactions.length > 3 ? 3 : transactions.length,
      separatorBuilder: (_, index) => Divider(
        height: 1,
        color: Colors.grey.withValues(alpha: 0.1),
        indent: 72,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return TransactionItem(
          transaction: tx,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TransactionDetailScreen(transaction: tx),
              ),
            );
          },
        );
      },
    );
  }

  // Premium Skeleton Loader
  Widget _buildSkeletonDashboard(BuildContext context, double screenWidth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skeletonColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final shimmerBase = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.withValues(alpha: 0.1);

    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.05),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card Skeleton
          Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(24),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1.5.seconds, color: shimmerBase),

          SizedBox(height: screenWidth * 0.08),

          // Actions Skeleton
          Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (index) => Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1.5.seconds, color: shimmerBase),

          SizedBox(height: screenWidth * 0.06),

          // Transactions Skeleton
          Container(
                width: 150,
                height: 24,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1.5.seconds, color: shimmerBase),

          const SizedBox(height: 20),

          Column(
                children: List.generate(
                  3,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: skeletonColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 120,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: skeletonColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 80,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: skeletonColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1.5.seconds, color: shimmerBase),
        ],
      ),
    );
  }
}
