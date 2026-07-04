import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/features/dashboard/presentation/dashboard_controller.dart';
import 'package:frontend/features/transactions/domain/transaction.dart';
import 'package:frontend/core/widgets/transaction_item.dart';
import 'package:frontend/core/utils/error_translator.dart';
import 'package:frontend/core/models/exchange_rate_model.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/theme/app_theme.dart';

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
          backgroundColor: isDark ? theme.scaffoldBackgroundColor : AppTheme.backgroundGrey,
          appBar: _buildAppBar(context),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: isReady
                ? RefreshIndicator(
                    onRefresh: () async => context.read<DashboardController>().refresh(),
                    color: theme.primaryColor,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: _LiveFxBanner()),
                          const SizedBox(height: 24),
                          
                          // Quick Actions Label
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              l10n.homeQuickActions,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildQuickActionsDock(context, l10n),
                          const SizedBox(height: 32),
                          
                          // Recent Transactions
                          _buildRecentTransactionsHeader(context, l10n),
                          const SizedBox(height: 12),
                          _buildTransactionContainer(state.transactions),
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

  Widget _buildQuickActionsDock(BuildContext context, AppLocalizations l10n) {
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
  Widget _buildTransactionContainer(List<Transaction> transactions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.clock,
              size: 18,
              color: AppTheme.textSecondaryColor(context),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.homeNoRecentTransactions,
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    final itemCount = transactions.length > 5 ? 5 : transactions.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkTheme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.borderGrey,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (context, index) => Divider(
          color: isDark ? Colors.white12 : AppTheme.borderGrey,
          height: 1,
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          return TransactionItem(transaction: transactions[index]);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        AppLocalizations.of(context)!.appTitle,
        style: theme.appBarTheme.titleTextStyle?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: AppTheme.textPrimaryColor(context),
          letterSpacing: -0.6,
        ) ?? theme.textTheme.headlineSmall?.copyWith(
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
            icon: Icon(
              PhosphorIconsRegular.gear,
              size: 22.0,
              color: AppTheme.textPrimaryColor(context),
            ),
            onPressed: () => context.push('/profile'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsHeader(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.homeRecentTransactions,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
                    color: AppTheme.accentGoldDark,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  PhosphorIconsBold.caretRight,
                  color: AppTheme.accentGoldDark,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// --- Live FX Banner with Pulsing Dot ---
class _LiveFxBanner extends StatefulWidget {
  const _LiveFxBanner();

  @override
  State<_LiveFxBanner> createState() => _LiveFxBannerState();
}

class _LiveFxBannerState extends State<_LiveFxBanner> {
  double? _rate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  Future<void> _loadRate() async {
    try {
      final json = await ApiService().fetchExchangeRate('USD');
      final rate = ExchangeRate.fromJson(json).providerRate;
      if (!mounted) return;
      setState(() {
        _rate = (rate != null && rate > 0) ? rate : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.borderGrey,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulseDot(),
          const SizedBox(width: 8),
          _buildRateText(context),
          const SizedBox(width: 8),
          Container(
            height: 12,
            width: 1,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(width: 8),
          Icon(
            PhosphorIconsRegular.lockSimple,
            size: 13,
            color: AppTheme.primaryTealDark,
          ),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.homeFxLocked,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTealDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateText(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: AppTheme.textSecondaryColor(context),
    );

    if (_loading) {
      return Container(
        width: 120,
        height: 12,
        decoration: BoxDecoration(
          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
          .fadeIn(duration: 600.ms)
          .fadeOut(duration: 600.ms);
    }

    final l10n = AppLocalizations.of(context)!;

    if (_rate == null) {
      return Text(l10n.homeFxUnavailable, style: style);
    }

    return Text(l10n.homeFxRate(_rate!.toStringAsFixed(2)), style: style);
  }
}

// --- Breathing Pulse Dot Widget ---
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryTeal.withValues(alpha: 0.4 * (1.0 - _pulseController.value)),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryTeal,
              ),
            ),
          ],
        );
      },
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

class _QuickActionCardState extends State<_QuickActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color cardBg = isDark ? AppTheme.darkTheme.cardColor : Colors.white;
    final Color iconBg = isDark ? Colors.white.withValues(alpha: 0.06) : AppTheme.primaryTealLight;
    final Color iconColor = isDark ? AppTheme.primaryColor(context) : AppTheme.primaryTealDark;
    final Color labelColor = isDark ? Colors.white.withValues(alpha: 0.87) : AppTheme.textPrimaryColor(context);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Semantics(
          button: true,
          label: widget.label,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.borderGrey,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
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
                  child: Icon(widget.icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                    maxLines: 1,
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
