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
import 'package:google_fonts/google_fonts.dart';
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
          backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF7F7F5),
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
                          Center(child: _buildLiveFXBanner(context)),
                          const SizedBox(height: 16),
                          _buildHeroCard(context),
                          const SizedBox(height: 28),
                          
                          // Quick Actions Label
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              "QUICK ACTIONS",
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white54 : const Color(0xFF666664),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildQuickActionsDock(context),
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

  // --- Live FX Banner with Pulsing Dot ---
  Widget _buildLiveFXBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5E3),
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
          Text(
            "Live FX: 1 USD ≈ 36.45 THB",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
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
            color: const Color(0xFF0F6E56),
          ),
          const SizedBox(width: 4),
          Text(
            "Locked",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F6E56),
            ),
          ),
        ],
      ),
    );
  }

  // --- Hyper-Realistic Virtual Card ---
  Widget _buildHeroCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0C1D18),
                  const Color(0xFF060B09),
                ]
              : [
                  const Color(0xFF0F6E56),
                  const Color(0xFF063A2D),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF2BBF9E).withValues(alpha: 0.15) : const Color(0xFF0F6E56).withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F6E56).withValues(alpha: isDark ? 0.3 : 0.15),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glass gloss effect overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Subtle brand design circle in background
          Positioned(
            right: -60,
            bottom: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEF9F27).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Card Top: Brand & Network Type
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            PhosphorIconsFill.wallet,
                            color: Color(0xFFEF9F27),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "PAYCIF VIRTUAL",
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      PhosphorIconsFill.wifiHigh,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ),

                // Card Middle: Chip & Spending Amount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const _CardChip(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TRIP SPENDING",
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: isDark ? Colors.white60 : Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "12,450",
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "THB",
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFEF9F27),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "≈ \$341.50 USD",
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Card Bottom: Card Number & Type Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "•••• •••• •••• 4321",
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        letterSpacing: 2.0,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF9F27).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFEF9F27).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "ACTIVE",
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: const Color(0xFFEF9F27),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Quick Actions Dock ---
  Widget _buildQuickActionsDock(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickActionButton(
          label: "Send",
          icon: PhosphorIconsRegular.paperPlaneRight,
          onTap: () {
            HapticFeedback.lightImpact();
            // Action Placeholder / Integration
          },
        ),
        
        // Scan QR Centerpiece (Elevated Design)
        _QuickActionButton(
          label: "Scan QR",
          icon: PhosphorIconsRegular.qrCode,
          isPrimary: true,
          onTap: () {
            HapticFeedback.mediumImpact();
            final dashboardController = context.read<DashboardController>();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ScanPage()),
            ).then((_) {
              if (mounted) dashboardController.refresh();
            });
          },
        ),

        _QuickActionButton(
          label: "Top Up",
          icon: PhosphorIconsRegular.plusCircle,
          onTap: () {
            HapticFeedback.lightImpact();
          },
        ),

        _QuickActionButton(
          label: "Rates",
          icon: PhosphorIconsRegular.chartLineUp,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryScreen()),
            );
          },
        ),
      ],
    );
  }

  // --- Transaction Container Card ---
  Widget _buildTransactionContainer(List<Transaction> transactions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (transactions.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141A18) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE5E5E3),
          ),
        ),
        child: const Center(
          child: Text(
            "No recent transactions",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final itemCount = transactions.length > 5 ? 5 : transactions.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A18) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE5E5E3),
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
          color: isDark ? Colors.white12 : const Color(0xFFF1F1EF),
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
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: IconButton(
          icon: Icon(
            PhosphorIconsRegular.bell,
            size: 22.0,
            color: AppTheme.textPrimaryColor(context),
          ),
          onPressed: () {},
        ),
      ),
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ),
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryScreen()),
            ),
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
                    color: const Color(0xFFEF9F27),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  PhosphorIconsBold.caretRight,
                  color: Color(0xFFEF9F27),
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

// --- Metallic Chip Widget ---
class _CardChip extends StatelessWidget {
  const _CardChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE5B560),
            Color(0xFFFBE4AD),
            Color(0xFFD49E43),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white24,
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          // Chip internal patterns
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Container(width: 0.5, color: Colors.black12),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Container(width: 0.5, color: Colors.black12),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 10,
            child: Container(height: 0.5, color: Colors.black12),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Container(height: 0.5, color: Colors.black12),
          ),
          Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12, width: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          )
        ],
      ),
    );
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
                color: const Color(0xFF0F6E56).withValues(alpha: 0.4 * (1.0 - _pulseController.value)),
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F6E56),
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- Custom Animated Quick Action Button with Press Feedback ---
class _QuickActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
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
    
    final Color buttonBg = widget.isPrimary
        ? const Color(0xFFEF9F27)
        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white);

    final Color iconColor = widget.isPrimary
        ? const Color(0xFF412402)
        : (isDark ? Colors.white : const Color(0xFF111111));

    final Color labelColor = isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF111111);

    final Border? border = widget.isPrimary
        ? null
        : Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5E3),
            width: 1,
          );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Semantics(
          button: true,
          label: widget.label,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: widget.isPrimary ? 64 : 56,
                height: widget.isPrimary ? 64 : 56,
                decoration: BoxDecoration(
                  color: buttonBg,
                  shape: BoxShape.circle,
                  border: border,
                  boxShadow: [
                    BoxShadow(
                      color: widget.isPrimary
                          ? const Color(0xFFEF9F27).withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                      blurRadius: widget.isPrimary ? 16 : 8,
                      offset: Offset(0, widget.isPrimary ? 6 : 3),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: iconColor,
                  size: widget.isPrimary ? 28 : 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: widget.isPrimary ? FontWeight.bold : FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
