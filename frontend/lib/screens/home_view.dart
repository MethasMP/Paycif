import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

import '../controllers/dashboard_controller.dart';
import '../models/transaction.dart';

import '../widgets/transaction_item.dart';
import 'top_up_view.dart';
import 'transaction_detail_screen.dart';
import 'history_screen.dart';
import '../utils/error_translator.dart';
import 'profile_page.dart';
import 'package:flutter/services.dart';

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
    return BlocBuilder<DashboardController, DashboardState>(
      builder: (context, state) {
        final bool isVerified = state.kycTier == 'verified';

        return BlocListener<DashboardController, DashboardState>(
          listenWhen: (previous, current) =>
              previous.wallet?.id != current.wallet?.id &&
              current.wallet != null,
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

                if (state.status == 'error') {
                  return Center(
                    child: Text(
                      "${l10n.commonError}: ${ErrorTranslator.translate(l10n, state.errorMessage ?? '')}",
                    ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLuxuryBalanceCard(
                                  context,
                                  state,
                                  screenWidth,
                                  isVerified,
                                ),
                                const SizedBox(height: 28),
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
                                const SizedBox(height: 24),
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
            ),
          ),
        );
      },
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
          onPressed: () {
            // Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
            // For now, let's just show the profile page as a dedicated screen if accessed from here
            // Or better, if it's already in the main screen, we can handle tab switching.
            // But a direct push is cleaner for a "Settings" action from Home.
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
        ),
      ],
    );
  }

  // Currency Selector removed

  Widget _buildLuxuryBalanceCard(
    BuildContext context,
    DashboardState state,
    double screenWidth,
    bool isVerified,
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
                          state.isOffline
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.amber.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.cloud_off_rounded,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'OFFLINE',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.0,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                              : Icon(
                                  Icons.wifi,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 24,
                                ),
                        ],
                      ),
                      const Spacer(),
                      // Balance display (chip removed for premium minimalism)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.homeTotalBalance,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: isLoading
                                        ? 0
                                        : (state.wallet?.balance ?? 0) / 100.0,
                                  ),
                                  duration: const Duration(milliseconds: 1500),
                                  curve: Curves.easeOutQuart,
                                  builder: (context, value, child) {
                                    final formatter = NumberFormat.currency(
                                      symbol: '',
                                      decimalDigits: 2,
                                      locale: 'en_US',
                                    );
                                    return Text(
                                      isLoading ? '...' : formatter.format(value),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1.0,
                                          ),
                                    );
                                  },
                                ),
                                if (state.isBalanceVisible && !isLoading) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    currency,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: const Color(0xFFF59E0B),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
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
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context
                                  .read<DashboardController>()
                                  .toggleBalanceVisibility();
                            },
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
        )
        .animate(target: isVerified ? 1 : 0)
        .custom(
          duration: 2.seconds,
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            if (value == 0) return child;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(
                    0xFFF59E0B,
                  ).withValues(alpha: value * 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFF59E0B,
                    ).withValues(alpha: value * 0.2),
                    blurRadius: 20 * value,
                    spreadRadius: 2 * value,
                  ),
                ],
              ),
              child: child,
            );
          },
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

    final buttonSize = isSmall ? 56.0 : 64.0;
    final iconSize = isSmall ? 24.0 : 28.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        onHighlightChanged: (highlighted) {
          if (highlighted) HapticFeedback.selectionClick();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: isDark ? Colors.white : const Color(0xFF1A1F71),
                  size: iconSize,
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
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
